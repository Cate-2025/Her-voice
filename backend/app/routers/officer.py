from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AuditLog, CaseStatus, Notification, PatternAlert, Report, Role, TimelineEvent, User
from app.schemas import CaseStatusUpdate, OfficerCaseDetail, OfficerReportResponse, PatternAlertResponse
from app.security import require_roles
from app.services.patterns import evaluate_staff_reference

router = APIRouter(prefix="/api/v1/officer", tags=["officer dashboard"])


def audit(db: Session, actor: User, action: str, report_id: UUID | None = None, **details) -> None:
    db.add(AuditLog(actor_id=actor.id, action=action, report_id=report_id, details=details))


def get_report_or_404(db: Session, report_id: UUID) -> Report:
    report = db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Case not found")
    return report


@router.get("/cases", response_model=list[OfficerReportResponse])
def case_queue(
    status_filter: CaseStatus | None = None,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> list[Report]:
    query = db.query(Report)
    if status_filter:
        query = query.filter(Report.status == status_filter)
    cases = query.order_by(Report.updated_at.desc()).all()
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
    return {**OfficerReportResponse.model_validate(report).model_dump(), "timeline": events}


@router.patch("/cases/{report_id}/status", response_model=OfficerReportResponse)
def change_case_status(
    report_id: UUID,
    payload: CaseStatusUpdate,
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)),
    db: Session = Depends(get_db),
) -> Report:
    report = get_report_or_404(db, report_id)
    old_status = report.status
    report.status = payload.status
    if report.reporter_id:
        db.add(Notification(user_id=report.reporter_id))
    audit(db, officer, "case_status_changed", report_id, from_status=old_status.value, to_status=payload.status.value)
    evaluate_staff_reference(db, report.subject_staff_ref)
    db.commit()
    db.refresh(report)
    return report


@router.get("/pattern-alerts", response_model=list[PatternAlertResponse])
def pattern_alerts(
    officer: User = Depends(require_roles(Role.OFFICER, Role.ADMIN)), db: Session = Depends(get_db)
) -> list[PatternAlert]:
    alerts = db.query(PatternAlert).order_by(PatternAlert.created_at.desc()).all()
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
