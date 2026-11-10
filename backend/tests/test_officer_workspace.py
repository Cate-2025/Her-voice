from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import update

from app.database import SessionLocal
from app.models import CaseStatus, PatternAlert, Report, ReportMode


def add_report(db, reporter, *, subject='Fictional staff', status=CaseStatus.SUBMITTED, submitted=None):
    report = Report(reporter_id=reporter, report_mode=ReportMode.CONFIDENTIAL,
                    subject_staff_ref=subject, status=status, submitted_at=submitted)
    db.add(report)
    return report


def test_workspace_pages_and_summary_are_bounded_and_exclude_drafts(client, accounts):
    with SessionLocal() as db:
        for _ in range(52):
            add_report(db, accounts['student']['id'])
        add_report(db, accounts['student']['id'], status=CaseStatus.UNDER_REVIEW)
        add_report(db, accounts['student']['id'], status=CaseStatus.DRAFT)
        db.commit()
    headers = accounts['officer']['headers']
    first = client.get('/api/v1/officer/case-page?limit=25', headers=headers).json()
    second = client.get('/api/v1/officer/case-page?limit=25&offset=25', headers=headers).json()
    assert first['total'] == second['total'] == 53
    assert len(first['items']) == len(second['items']) == 25
    assert not {x['id'] for x in first['items']} & {x['id'] for x in second['items']}
    assert all('reporter_id' not in x and 'email' not in x for x in first['items'])
    assert client.get('/api/v1/officer/case-summary', headers=headers).json() == {
        'total': 53, 'submitted': 52, 'under_review': 1, 'alerts': 0}
    assert client.get('/api/v1/officer/case-page?status_filter=draft', headers=headers).json() == {'items': [], 'total': 0}


def test_related_filter_is_exact_and_respects_submission_window(client, accounts):
    stamp = datetime(2026, 11, 10, tzinfo=UTC)
    with SessionLocal() as db:
        wanted = add_report(db, accounts['student']['id'], subject='STAFF & ONE', submitted=stamp)
        add_report(db, accounts['other']['id'], subject='STAFF & ONE', submitted=stamp - timedelta(days=100))
        add_report(db, accounts['other']['id'], subject='STAFF & ONE extra', submitted=stamp)
        add_report(db, accounts['other']['id'], subject='STAFF & ONE', status=CaseStatus.DRAFT, submitted=stamp)
        db.flush()
        wanted_id = str(wanted.id)
        db.commit()
    result = client.get('/api/v1/officer/case-page', params={
        'staff_ref': 'STAFF & ONE', 'window_start': (stamp - timedelta(days=1)).isoformat(),
        'window_end': (stamp + timedelta(days=1)).isoformat()}, headers=accounts['officer']['headers']).json()
    assert result['total'] == 1 and result['items'][0]['id'] == wanted_id


def test_status_edit_does_not_move_case_between_pages(client, accounts):
    with SessionLocal() as db:
        for n in range(3):
            add_report(db, accounts['student']['id'], submitted=datetime(2026, 11, n+1, tzinfo=UTC))
        db.commit()
    headers = accounts['officer']['headers']
    first = client.get('/api/v1/officer/case-page?limit=1', headers=headers).json()['items'][0]['id']
    with SessionLocal() as db:
        db.execute(update(Report).values(status=CaseStatus.RECEIVED))
        db.commit()
    assert client.get('/api/v1/officer/case-page?limit=1', headers=headers).json()['items'][0]['id'] == first


def test_alert_page_only_loads_open_alerts_and_reports_total(client, accounts):
    stamp = datetime.now(UTC)
    with SessionLocal() as db:
        for n in range(28):
            db.add(PatternAlert(staff_ref=f'Fictional {n}', report_count=3,
                               window_start=stamp-timedelta(days=90), window_end=stamp,
                               reviewed_at=stamp if n == 0 else None))
        db.commit()
    headers = accounts['officer']['headers']
    result = client.get('/api/v1/officer/alert-page?limit=25', headers=headers).json()
    assert result['total'] == 27 and len(result['items']) == 25
    assert all(x['reviewed_at'] is None for x in result['items'])
    assert client.get('/api/v1/officer/case-summary', headers=headers).json()['alerts'] == 27


@pytest.mark.parametrize('path', ['case-page', 'case-summary', 'alert-page'])
def test_student_cannot_access_workspace_endpoints(client, accounts, path):
    assert client.get(f'/api/v1/officer/{path}', headers=accounts['student']['headers']).status_code == 403


@pytest.mark.parametrize('query', ['limit=101', 'offset=-1', 'window_start=2026-11-10T00:00:00',
                                   'window_start=2026-11-11T00:00:00Z&window_end=2026-11-10T00:00:00Z'])
def test_workspace_rejects_invalid_page_or_window(client, accounts, query):
    assert client.get(f'/api/v1/officer/case-page?{query}', headers=accounts['officer']['headers']).status_code == 422
