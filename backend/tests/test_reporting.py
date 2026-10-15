from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from uuid import UUID, uuid4

from app.database import SessionLocal
from app.models import AuditLog, Evidence, Notification, Report, TimelineEvent


def create(client, accounts, payload, account='student'):
    return client.post('/api/v1/reports/drafts', json=payload, headers=accounts[account]['headers'])


def test_private_draft_then_retry_safe_submission(client, accounts, payload):
    student, officer = accounts['student']['headers'], accounts['officer']['headers']
    result = create(client, accounts, payload)
    assert result.status_code == 201
    report_id = result.json()['id']
    assert result.json()['status'] == 'draft' and result.json()['submitted_at'] is None
    assert client.get('/api/v1/cases/mine', headers=student).json() == []
    assert client.get('/api/v1/officer/cases', headers=officer).json() == []
    assert client.get(f'/api/v1/officer/cases/{report_id}', headers=officer).status_code == 404
    assert client.patch(f'/api/v1/officer/cases/{report_id}/status', json={'status': 'received'}, headers=officer).status_code == 404
    detail = client.get(f'/api/v1/reports/{report_id}', headers=student).json()
    assert len(detail['timeline']) == 1 and detail['evidence'] == []
    first = client.post(f'/api/v1/reports/{report_id}/submit', headers=student)
    second = client.post(f'/api/v1/reports/{report_id}/submit', headers=student)
    assert first.status_code == second.status_code == 200 and first.json() == second.json()
    assert first.json()['status'] == 'submitted' and first.json()['submitted_at'] is not None
    assert client.get('/api/v1/cases/mine', headers=student).json()[0]['id'] == report_id
    assert client.get('/api/v1/officer/cases', headers=officer).json()[0]['id'] == report_id
    assert create(client, accounts, payload).json()['id'] == report_id


def test_content_conflict_and_account_scoped_keys(client, accounts, payload):
    first = create(client, accounts, payload).json()
    changed = deepcopy(payload)
    changed['timeline'][0]['narrative'] = 'Different fictional event.'
    assert create(client, accounts, changed).status_code == 409
    other = create(client, accounts, payload, 'other')
    assert other.status_code == 201 and other.json()['id'] != first['id']
    equivalent = deepcopy(payload)
    equivalent['timeline'][0]['occurred_at'] = '2026-09-18T07:30:00Z'
    assert create(client, accounts, equivalent).json()['id'] == first['id']


def test_concurrent_creation_and_submission(client, accounts, payload):
    with ThreadPoolExecutor(max_workers=4) as pool:
        responses = list(pool.map(lambda _: create(client, accounts, payload), range(4)))
    assert all(r.status_code == 201 for r in responses)
    assert len({r.json()['id'] for r in responses}) == 1
    report_id = responses[0].json()['id']
    with ThreadPoolExecutor(max_workers=4) as pool:
        submitted = list(pool.map(lambda _: client.post(f'/api/v1/reports/{report_id}/submit', headers=accounts['student']['headers']), range(4)))
    assert all(r.status_code == 200 for r in submitted)
    assert len({r.json()['submitted_at'] for r in submitted}) == 1
    with SessionLocal() as db:
        assert db.query(Report).count() == db.query(TimelineEvent).count() == 1


def test_owner_and_role_boundaries(client, accounts, payload):
    report_id = create(client, accounts, payload).json()['id']
    for path in [f'/api/v1/reports/{report_id}', f'/api/v1/reports/{report_id}/submit']:
        request = client.post if path.endswith('/submit') else client.get
        assert request(path, headers=accounts['other']['headers']).status_code == 404
        assert request(path, headers=accounts['officer']['headers']).status_code == 403
    assert client.post('/api/v1/reports/drafts', json=payload).status_code == 401
    assert create(client, accounts, payload, 'officer').status_code == 403
    assert client.get('/api/v1/officer/cases', headers=accounts['student']['headers']).status_code == 403


def test_validation_and_retired_routes(client, accounts, payload):
    for field, value in [('occurred_at', '2026-09-18T10:30:00'), ('narrative', '   ')]:
        bad = deepcopy(payload)
        bad['timeline'][0][field] = value
        assert create(client, accounts, bad).status_code == 422
    bad = deepcopy(payload)
    bad['report_mode'] = 'anonymous'
    assert create(client, accounts, bad).status_code == 422
    assert client.post('/api/v1/reports', json=payload, headers=accounts['student']['headers']).status_code == 410
    assert client.post('/api/v1/anonymous-reports', json=payload).status_code == 503


def test_unverified_evidence_blocks_submit_and_draft_download(client, accounts, payload):
    report_id = UUID(create(client, accounts, payload).json()['id'])
    evidence_id = uuid4()
    with SessionLocal() as db:
        db.add(Evidence(id=evidence_id, report_id=report_id, object_key=f'fictional/{evidence_id}', original_name='fictional.pdf', content_type='application/pdf', byte_size=1, sha256='a' * 64))
        db.commit()
    assert client.post(f'/api/v1/reports/{report_id}/submit', headers=accounts['student']['headers']).status_code == 409
    assert client.get(f'/api/v1/evidence/{evidence_id}/download-url', headers=accounts['officer']['headers']).status_code == 404
    detail = client.get(f'/api/v1/reports/{report_id}', headers=accounts['student']['headers']).json()
    assert detail['status'] == 'draft' and detail['evidence'][0]['verification_status'] == 'reserved'
    with SessionLocal() as db:
        assert db.get(Evidence, evidence_id).uploaded_at is None
        assert db.get(Report, report_id).submitted_at is None


def test_status_rules_and_notifications(client, accounts, payload):
    report_id = create(client, accounts, payload).json()['id']
    student, officer = accounts['student']['headers'], accounts['officer']['headers']
    client.post(f'/api/v1/reports/{report_id}/submit', headers=student)
    path = f'/api/v1/officer/cases/{report_id}/status'
    for target in ['closed', 'draft']:
        assert client.patch(path, json={'status': target}, headers=officer).status_code == 409
    for _ in range(2):
        assert client.patch(path, json={'status': 'received'}, headers=officer).status_code == 200
    assert client.post(f'/api/v1/reports/{report_id}/submit', headers=student).json()['status'] == 'received'
    with SessionLocal() as db:
        assert db.query(Notification).count() == 1
        assert db.query(AuditLog).filter(AuditLog.action == 'case_status_changed').count() == 1
    assert client.patch(path, json={'status': 'submitted'}, headers=officer).status_code == 409


def test_session_identity_and_login(client, accounts):
    response = client.get('/api/v1/auth/me', headers=accounts['student']['headers'])
    assert response.status_code == 200 and response.json()['role'] == 'student'
    assert 'password_hash' not in response.json()
    assert client.get('/api/v1/auth/me').status_code == 401
    assert client.post('/api/v1/auth/login', json={'email': 'student@example.test', 'password': 'fictional-password'}).status_code == 200
    assert client.post('/api/v1/auth/login', json={'email': 'student@example.test', 'password': 'wrong-password'}).status_code == 401
