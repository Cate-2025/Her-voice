from datetime import UTC, datetime

from app.database import SessionLocal
from app.models import CaseStatus, PatternAlert, Report, ReportMode, Role, User
from app.security import password_hash
from app.services.patterns import evaluate_staff_reference


def test_alert_counts_reporters_not_reports_and_reuses_active_task():
    with SessionLocal() as db:
        users = [User(email=f'fictional-{i}@example.test', role=Role.STUDENT, password_hash=password_hash.hash('fictional-password')) for i in range(3)]
        db.add_all(users)
        db.flush()
        for user in users[:2]:
            db.add(Report(reporter_id=user.id, report_mode=ReportMode.CONFIDENTIAL, subject_staff_ref='DEMO', status=CaseStatus.SUBMITTED, submitted_at=datetime.now(UTC)))
        # Multiple reports by the same person and anonymous reports don't count as new reporters.
        for reporter_id in [users[0].id, None, None, None]:
            db.add(Report(reporter_id=reporter_id, report_mode=ReportMode.ANONYMOUS if reporter_id is None else ReportMode.CONFIDENTIAL, subject_staff_ref='DEMO', status=CaseStatus.SUBMITTED, submitted_at=datetime.now(UTC)))
        db.add(Report(reporter_id=users[2].id, report_mode=ReportMode.CONFIDENTIAL, subject_staff_ref='DEMO', status=CaseStatus.DRAFT))
        db.flush()
        assert evaluate_staff_reference(db, 'DEMO') is None
        db.add(Report(reporter_id=users[2].id, report_mode=ReportMode.CONFIDENTIAL, subject_staff_ref='DEMO', status=CaseStatus.CLOSED, submitted_at=datetime.now(UTC)))
        db.flush()
        alert = evaluate_staff_reference(db, 'DEMO')
        assert alert.report_count == 3
        db.commit()
        alert_id = alert.id
        assert evaluate_staff_reference(db, 'DEMO').id == alert_id
        db.commit()
        assert db.query(PatternAlert).count() == 1
