from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.pagination import Page
from app.database import get_db
from app.models import AuditLog, CaseStatus, Evidence, Notification, PatternAlert, Report, Role, TimelineEvent, User
from app.schemas import IdentityAccessRequest, ReporterIdentityResponse, OfficerCasePage, OfficerQueueSummary, OfficerAlertPage, CaseStatusUpdate, OfficerCaseDetail, OfficerReportResponse, PatternAlertResponse
from app.security import require_roles
from app.services.patterns import evaluate_staff_reference
from app.services.push import queue_push

router = APIRouter(prefix="/api/v1/officer", tags=["officer dashboard"])


def audit(db: Session, actor: User, action: str, report_id: UUID | None = None, **details) -> None:
    db.add(AuditLog(actor_id=actor.id, action=action, report_id=report_id, details=details))


def get_report_or_404(db: Session, report_id: UUID) -> Report:
    report = db.get(Report, report_id)
    if not report or report.status == CaseStatus.DRAFT:
        raise HTTPException(status_code=404, detail="Case not found")
    return report


@router.get("/case-page", response_model=OfficerCasePage)
def case_page(
    status_filter: CaseStatus | None = None,
    staff_ref: str | None = Query(None, max_length=128),
    window_start: datetime | None = None,
    window_end: datetime | None = None,
    page: Page = Depends(),
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
):
    for value in (window_start, window_end):
        if value is not None and value.utcoffset() is None:
            raise HTTPException(422, "Window dates must include a timezone")
    if window_start and window_end and window_start > window_end:
        raise HTTPException(422, "Window start must precede its end")
    submitted = func.coalesce(Report.submitted_at, Report.created_at)
    query = db.query(Report).filter(Report.status != CaseStatus.DRAFT)
    if status_filter:
        query = query.filter(Report.status == status_filter)
    if staff_ref is not None:
        query = query.filter(Report.subject_staff_ref == staff_ref)
    if window_start:
        query = query.filter(submitted >= window_start)
    if window_end:
        query = query.filter(submitted <= window_end)
    total = query.count()
    # Submission time is immutable: routine status edits do not reorder pages.
    items = page.apply(query.order_by(submitted.desc(), Report.id)).all()
    audit(db, officer, "case_queue_viewed", count=len(items))
    db.commit()
    return {"items": items, "total": total}


@router.get("/case-summary", response_model=OfficerQueueSummary)
def case_summary(
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
):
    counts = dict(db.query(Report.status, func.count(Report.id))
                  .filter(Report.status != CaseStatus.DRAFT).group_by(Report.status).all())
    result = {"total": sum(counts.values()), "submitted": counts.get(CaseStatus.SUBMITTED, 0),
              "under_review": counts.get(CaseStatus.UNDER_REVIEW, 0),
              "alerts": db.query(PatternAlert).filter(PatternAlert.reviewed_at.is_(None)).count()}
    audit(db, officer, "case_summary_viewed")
    db.commit()
    return result


@router.get("/alert-page", response_model=OfficerAlertPage)
def alert_page(
    page: Page = Depends(),
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
):
    query = db.query(PatternAlert).filter(PatternAlert.reviewed_at.is_(None))
    total = query.count()
    items = page.apply(query.order_by(PatternAlert.created_at.desc(), PatternAlert.id)).all()
    audit(db, officer, "pattern_alerts_viewed", count=len(items))
    db.commit()
    return {"items": items, "total": total}


@router.get("/cases", response_model=list[OfficerReportResponse])
def case_queue(
    status_filter: CaseStatus | None = None,
    page: Page = Depends(),
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> list[Report]:
    query = db.query(Report).filter(Report.status != CaseStatus.DRAFT)
    if status_filter:
        query = query.filter(Report.status == status_filter)
    cases = page.apply(query.order_by(Report.updated_at.desc(), Report.id)).all()
    audit(db, officer, "case_queue_viewed", count=len(cases))
    db.commit()
    return cases


@router.get("/cases/{report_id}", response_model=OfficerCaseDetail)
def case_detail(
    report_id: UUID,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> dict:
    report = get_report_or_404(db, report_id)
    events = db.query(TimelineEvent).filter(TimelineEvent.report_id == report_id).order_by(TimelineEvent.occurred_at).all()
    audit(db, officer, "case_viewed", report_id)
    db.commit()
    return {**OfficerReportResponse.model_validate(report).model_dump(), "timeline": events, "evidence": db.query(Evidence).filter_by(report_id=report_id).all()}


@router.post("/cases/{report_id}/reporter-identity", response_model=ReporterIdentityResponse)
def reporter_identity(
    report_id: UUID,
    payload: IdentityAccessRequest,
    response: Response,
    admin: User = Depends(require_roles(Role.ADMIN)),
    db: Session = Depends(get_db),
) -> ReporterIdentityResponse:
    report = get_report_or_404(db, report_id)
    reporter = db.get(User, report.reporter_id) if report.reporter_id else None
    if reporter is None:
        raise HTTPException(status_code=404, detail="No account identity available")
    audit(db, admin, "reporter_identity_viewed", report_id, reason=payload.reason)
    db.commit()  # Never release identity unless the audit was persisted.
    response.headers["Cache-Control"] = "no-store"
    return ReporterIdentityResponse(email=reporter.email)


@router.patch("/cases/{report_id}/status", response_model=OfficerReportResponse)
def change_case_status(
    report_id: UUID,
    payload: CaseStatusUpdate,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> Report:
    report = db.query(Report).filter(Report.id == report_id, Report.status != CaseStatus.DRAFT).with_for_update().one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="Case not found")
    old_status = report.status
    if payload.status == old_status:
        return report
    if payload.expected_status is not None and payload.expected_status != old_status:
        raise HTTPException(status_code=409, detail="This case changed since you opened it. Review the current status and try again.")
    transitions = {
        CaseStatus.SUBMITTED: {CaseStatus.RECEIVED},
        CaseStatus.RECEIVED: {CaseStatus.UNDER_REVIEW},
        CaseStatus.UNDER_REVIEW: {CaseStatus.ACTION_REQUIRED, CaseStatus.CLOSED},
        CaseStatus.ACTION_REQUIRED: {CaseStatus.UNDER_REVIEW},
        CaseStatus.CLOSED: set(),
    }
    if payload.status not in transitions.get(old_status, set()):
        raise HTTPException(status_code=409, detail="Invalid case status transition")
    report.status = payload.status
    if report.reporter_id:
        notification = Notification(user_id=report.reporter_id)
        db.add(notification)
        db.flush()
        queue_push(db, notification)
    audit(db, officer, "case_status_changed", report_id, from_status=old_status.value, to_status=payload.status.value)
    evaluate_staff_reference(db, report.subject_staff_ref)
    db.commit()
    db.refresh(report)
    return report


@router.get("/pattern-alerts", response_model=list[PatternAlertResponse])
def pattern_alerts(
    page: Page = Depends(),
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)), db: Session = Depends(get_db)
) -> list[PatternAlert]:
    alerts = page.apply(db.query(PatternAlert).order_by(PatternAlert.created_at.desc(), PatternAlert.id)).all()
    audit(db, officer, "pattern_alerts_viewed", count=len(alerts))
    db.commit()
    return alerts


@router.post("/pattern-alerts/{alert_id}/review", response_model=PatternAlertResponse)
def mark_alert_reviewed(
    alert_id: UUID,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> PatternAlert:
    alert = db.get(PatternAlert, alert_id)
    if not alert:
        raise HTTPException(status_code=404, detail="Pattern alert not found")
    alert.reviewed_at = datetime.now(UTC)
    alert.reviewed_by_id = officer.id
    audit(db, officer, "pattern_alert_reviewed", details={"staff_ref": alert.staff_ref})
    db.commit()
    db.refresh(alert)
    return alert
