from uuid import uuid4

from alembic import command
from alembic.config import Config
from sqlalchemy import inspect, text

from app.database import engine


def test_fresh_schema_round_trip_and_metadata_match():
    config = Config('alembic.ini')
    command.downgrade(config, 'base')
    assert inspect(engine).get_table_names() == ['alembic_version']
    command.upgrade(config, 'head')
    command.check(config)


def test_upgrade_preserves_legacy_case_without_claiming_evidence_uploaded():
    config = Config('alembic.ini')
    command.downgrade(config, '0001')
    report_id, evidence_id = uuid4(), uuid4()
    with engine.begin() as conn:
        conn.execute(text("""INSERT INTO reports
            (id, report_mode, subject_staff_ref, status, idempotency_key)
            VALUES (:id, 'ANONYMOUS', 'STAFF-DEMO', 'SUBMITTED', 'legacy-fictional-key')"""), {'id': report_id})
        conn.execute(text("""INSERT INTO evidence
            (id, report_id, object_key, original_name, content_type, byte_size, sha256)
            VALUES (:id, :report_id, 'fictional-key', 'fictional.pdf', 'application/pdf', 1, :hash)"""),
            {'id': evidence_id, 'report_id': report_id, 'hash': 'a' * 64})
    command.upgrade(config, 'head')
    with engine.connect() as conn:
        report = conn.execute(text('SELECT status, submitted_at FROM reports WHERE id = :id'), {'id': report_id}).one()
        evidence = conn.execute(text('SELECT verification_status, uploaded_at FROM evidence WHERE id = :id'), {'id': evidence_id}).one()
        assert report.status == 'SUBMITTED' and report.submitted_at is not None
        assert evidence.verification_status == 'reserved' and evidence.uploaded_at is None
    command.check(config)


def test_downgrade_refuses_account_scoped_key_collisions(accounts):
    import pytest
    from sqlalchemy.exc import ProgrammingError
    from app.database import SessionLocal
    from app.models import CaseStatus, Report, ReportMode
    with SessionLocal() as db:
        for name in ['student', 'other']:
            db.add(Report(reporter_id=accounts[name]['id'], report_mode=ReportMode.CONFIDENTIAL,
                          subject_staff_ref='DEMO', status=CaseStatus.DRAFT,
                          idempotency_key='shared-fictional-operation'))
        db.commit()
    config = Config('alembic.ini')
    with pytest.raises(ProgrammingError, match='Cannot downgrade'):
        command.downgrade(config, '0001')
    # Alembic/PostgreSQL transaction rollback must retain the complete new schema.
    command.check(config)
    with SessionLocal() as db:
        assert db.query(Report).count() == 2
