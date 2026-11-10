import pytest
from app.database import SessionLocal
from app.models import Report, ReportMode, CaseStatus


def test_bounded_case_pages_keep_ownership_and_drafts_private(client, accounts):
    with SessionLocal() as db:
        db.add_all([Report(reporter_id=accounts['student']['id'], report_mode=ReportMode.CONFIDENTIAL,
            subject_staff_ref='Fictional subject', status=CaseStatus.SUBMITTED) for _ in range(105)])
        db.add(Report(reporter_id=accounts['other']['id'], report_mode=ReportMode.CONFIDENTIAL,
            subject_staff_ref='Other account', status=CaseStatus.SUBMITTED))
        db.add(Report(reporter_id=accounts['student']['id'], report_mode=ReportMode.CONFIDENTIAL,
            subject_staff_ref='Private draft', status=CaseStatus.DRAFT))
        db.commit()
    headers = accounts['student']['headers']
    first = client.get('/api/v1/cases/mine', headers=headers).json()
    last = client.get('/api/v1/cases/mine?offset=100', headers=headers).json()
    assert len(first) == 100 and len(last) == 5
    assert len({item['id'] for item in first + last}) == 105
    assert all(item['subject_staff_ref'] == 'Fictional subject' for item in first + last)
    officer = accounts['officer']['headers']
    page = client.get('/api/v1/officer/cases?limit=2&offset=1', headers=officer).json()
    assert len(page) == 2
    assert all(item['status'] != 'draft' for item in page)


@pytest.mark.parametrize('path', ['/cases/mine', '/officer/cases', '/officer/pattern-alerts'])
@pytest.mark.parametrize('query', ['limit=101', 'limit=0', 'offset=-1'])
def test_invalid_pages_are_rejected(client, accounts, path, query):
    role = 'student' if path == '/cases/mine' else 'officer'
    assert client.get(f'/api/v1{path}?{query}', headers=accounts[role]['headers']).status_code == 422
