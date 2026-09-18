from datetime import UTC, datetime, timedelta

from sqlalchemy.orm import Session

from app.models import CaseStatus, PatternAlert, Report

WINDOW_DAYS = 90
MINIMUM_INDEPENDENT_REPORTS = 3


def evaluate_staff_reference(db: Session, staff_ref: str) -> PatternAlert | None:
    """Create a review task, never a misconduct conclusion.

    One report per known reporter is counted. Anonymous reports are each independent
    for this prototype; production policy must define anti-abuse controls separately.
    """
    window_end = datetime.now(UTC)
    window_start = window_end - timedelta(days=WINDOW_DAYS)
    reports = (
        db.query(Report)
        .filter(
            Report.subject_staff_ref == staff_ref,
            Report.status.in_([CaseStatus.SUBMITTED, CaseStatus.RECEIVED, CaseStatus.UNDER_REVIEW]),
            Report.created_at >= window_start,
        )
        .all()
    )
    known_reporters = {record.reporter_id for record in reports if record.reporter_id is not None}
    anonymous_count = sum(record.reporter_id is None for record in reports)
    count = len(known_reporters) + anonymous_count
    if count < MINIMUM_INDEPENDENT_REPORTS:
        return None

    existing = (
        db.query(PatternAlert)
        .filter(PatternAlert.staff_ref == staff_ref, PatternAlert.window_start >= window_start)
        .one_or_none()
    )
    if existing:
        existing.report_count = count
        existing.window_end = window_end
        return existing
    alert = PatternAlert(staff_ref=staff_ref, report_count=count, window_start=window_start, window_end=window_end)
    db.add(alert)
    return alert
