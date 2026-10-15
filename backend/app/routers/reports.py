import hashlib
import json
from datetime import UTC, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import CaseStatus, Evidence, Report, ReportMode, Role, TimelineEvent, User
from app.schemas import ReportCreate, ReportResponse, StudentReportDetail
from app.security import get_current_user
from app.services.patterns import evaluate_staff_reference

router = APIRouter(prefix="/api/v1", tags=["reports"])


def student_account(user: User = Depends(get_current_user)) -> User:
    if user.role != Role.STUDENT:
        raise HTTPException(status_code=403, detail="Student access required")
    return user


def owned_report(db: Session, report_id: UUID, user: User, *, lock: bool = False) -> Report:
    query = db.query(Report).filter(Report.id == report_id, Report.reporter_id == user.id)
    if lock:
        query = query.with_for_update()
    report = query.one_or_none()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    return report


def request_fingerprint(payload: ReportCreate) -> str:
    data = payload.model_dump(mode="json", exclude={"idempotency_key"})
    # Equivalent timezone representations must yield the same logical payload.
    for item, event in zip(data["timeline"], payload.timeline):
        item["occurred_at"] = event.occurred_at.astimezone(UTC).isoformat()
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(canonical.encode()).hexdigest()


def existing_draft(db: Session, user: User, key: str, fingerprint: str) -> Report | None:
    report = db.query(Report).filter(Report.reporter_id == user.id, Report.idempotency_key == key).one_or_none()
    if report and report.payload_sha256 != fingerprint:
        raise HTTPException(status_code=409, detail="Submission key already used with different content")
    return report


@router.post("/reports/drafts", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def create_draft(payload: ReportCreate, user: User = Depends(student_account), db: Session = Depends(get_db)) -> Report:
    if payload.report_mode == ReportMode.ANONYMOUS:
        raise HTTPException(status_code=422, detail="Anonymous reporting is not available in this flow")
    fingerprint = request_fingerprint(payload)
    existing = existing_draft(db, user, payload.idempotency_key, fingerprint)
    if existing:
        return existing
    report = Report(
        reporter_id=user.id, report_mode=payload.report_mode,
        subject_staff_ref=payload.subject_staff_ref, course_ref=payload.course_ref,
        idempotency_key=payload.idempotency_key, payload_sha256=fingerprint, status=CaseStatus.DRAFT,
    )
    try:
        db.add(report)
        db.flush()
        for item in payload.timeline:
            db.add(TimelineEvent(report_id=report.id, **item.model_dump()))
        db.commit()
    except IntegrityError:
        db.rollback()
        # A concurrent retry may have committed the same logical operation.
        existing = existing_draft(db, user, payload.idempotency_key, fingerprint)
        if existing:
            return existing
        raise
    db.refresh(report)
    return report


@router.get("/reports/{report_id}", response_model=StudentReportDetail)
def report_detail(report_id: UUID, user: User = Depends(student_account), db: Session = Depends(get_db)) -> dict:
    report = owned_report(db, report_id, user)
    return {
        **ReportResponse.model_validate(report).model_dump(),
        "timeline": db.query(TimelineEvent).filter(TimelineEvent.report_id == report.id).order_by(TimelineEvent.occurred_at, TimelineEvent.id).all(),
        "evidence": db.query(Evidence).filter(Evidence.report_id == report.id).order_by(Evidence.id).all(),
    }


@router.post("/reports/{report_id}/submit", response_model=ReportResponse)
def submit_draft(report_id: UUID, user: User = Depends(student_account), db: Session = Depends(get_db)) -> Report:
    report = owned_report(db, report_id, user, lock=True)
    if report.status != CaseStatus.DRAFT:
        if report.submitted_at is not None:
            return report  # Retry after finalisation or subsequent officer processing.
        raise HTTPException(status_code=409, detail="Report is not an eligible server draft")
    if not db.query(TimelineEvent).filter(TimelineEvent.report_id == report.id).first():
        raise HTTPException(status_code=422, detail="An incident event is required")
    if db.query(Evidence).filter(Evidence.report_id == report.id, Evidence.verification_status != "verified").first():
        raise HTTPException(status_code=409, detail="All retained evidence must be verified before submission")
    report.status = CaseStatus.SUBMITTED
    report.submitted_at = datetime.now(UTC)
    db.flush()  # Pattern queries must see the final state with autoflush disabled.
    evaluate_staff_reference(db, report.subject_staff_ref)
    db.commit()
    db.refresh(report)
    return report


@router.get("/cases/mine", response_model=list[ReportResponse])
def my_cases(user: User = Depends(student_account), db: Session = Depends(get_db)) -> list[Report]:
    return db.query(Report).filter(Report.reporter_id == user.id, Report.status != CaseStatus.DRAFT).order_by(Report.updated_at.desc(), Report.id).all()


@router.post("/reports", deprecated=True, status_code=410)
def retired_submission(user: User = Depends(student_account)):
    raise HTTPException(status_code=410, detail="Use /reports/drafts followed by /reports/{id}/submit")


@router.post("/anonymous-reports", deprecated=True, status_code=503)
def anonymous_unavailable():
    raise HTTPException(status_code=503, detail="Anonymous reporting is unavailable pending its separate access and recovery flow")
