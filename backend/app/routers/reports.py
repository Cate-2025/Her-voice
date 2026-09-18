import secrets
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import CaseStatus, Report, ReportMode, Role, TimelineEvent, User
from app.schemas import ReportCreate, ReportResponse
from app.security import get_current_user
from app.services.patterns import evaluate_staff_reference

router = APIRouter(prefix="/api/v1", tags=["reports"])


def create_report(db: Session, payload: ReportCreate, reporter_id, anonymous: bool = False) -> Report:
    existing = db.query(Report).filter(Report.idempotency_key == payload.idempotency_key).one_or_none()
    if existing:
        if existing.reporter_id == reporter_id:
            return existing
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Submission key already used")

    report = Report(
        reporter_id=reporter_id,
        report_mode=ReportMode.ANONYMOUS if anonymous else payload.report_mode,
        case_code=secrets.token_urlsafe(9).upper() if anonymous else None,
        subject_staff_ref=payload.subject_staff_ref.strip(),
        course_ref=payload.course_ref,
        idempotency_key=payload.idempotency_key,
        status=CaseStatus.SUBMITTED,
    )
    db.add(report)
    db.flush()
    for item in payload.timeline:
        db.add(TimelineEvent(report_id=report.id, occurred_at=item.occurred_at, location_hint=item.location_hint, narrative=item.narrative))
    evaluate_staff_reference(db, report.subject_staff_ref)
    db.commit()
    db.refresh(report)
    return report


@router.post("/reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def submit_report(payload: ReportCreate, user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> Report:
    if user.role != Role.STUDENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only students can submit reports")
    if payload.report_mode == ReportMode.ANONYMOUS:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Use the anonymous submission endpoint")
    return create_report(db, payload, user.id)


@router.post("/anonymous-reports", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
def submit_anonymous_report(payload: ReportCreate, db: Session = Depends(get_db)) -> Report:
    """Deliberately has no authentication dependency and stores no reporter identity."""
    return create_report(db, payload, None, anonymous=True)


@router.get("/cases/mine", response_model=list[ReportResponse])
def my_cases(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> list[Report]:
    if user.role != Role.STUDENT:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Student access required")
    return db.query(Report).filter(Report.reporter_id == user.id).order_by(Report.updated_at.desc()).all()
