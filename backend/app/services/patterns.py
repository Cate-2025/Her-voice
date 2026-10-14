from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import CaseStatus, PatternAlert, Report

WINDOW_DAYS = 90
MINIMUM_INDEPENDENT_REPORTS = 3


def evaluate_staff_reference(db: Session, staff_ref: str) -> PatternAlert | None:
    """Create an internal review task; count distinct authenticated reporters only."""
    # Serialise evaluations for a reference, including concurrent submissions.
    # Hash collisions merely serialise unrelated references; they do not merge data.
    db.execute(select(func.pg_advisory_xact_lock(func.hashtext(staff_ref))))
    window_end = datetime.now(UTC)
    window_start = window_end - timedelta(days=WINDOW_DAYS)
    count = (
        db.query(func.count(func.distinct(Report.reporter_id)))
        .filter(
            Report.subject_staff_ref == staff_ref,
            Report.reporter_id.is_not(None),
            Report.status != CaseStatus.DRAFT,
            func.coalesce(Report.submitted_at, Report.created_at) >= window_start,
        )
        .scalar()
    )
    existing = (
        db.query(PatternAlert)
        .filter(PatternAlert.staff_ref == staff_ref, PatternAlert.reviewed_at.is_(None))
        .order_by(PatternAlert.created_at, PatternAlert.id)
        .first()
    )
    if existing:
        existing.report_count = count
        existing.window_start = window_start
        existing.window_end = window_end
        return existing
    if count < MINIMUM_INDEPENDENT_REPORTS:
        return None
    alert = PatternAlert(staff_ref=staff_ref, report_count=count, window_start=window_start, window_end=window_end)
    db.add(alert)
    return alert
