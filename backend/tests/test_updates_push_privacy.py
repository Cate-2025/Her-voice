from datetime import UTC, datetime
from app.database import SessionLocal
from app.models import AuditLog, Notification, PushDelivery, PushDevice, Role, User
from app.security import create_access_token
from app.services.push import InvalidDevice, deliver_one

TOKEN = 'fictional-device-token-00000001'


def submitted(client, accounts, payload):
    headers = accounts['student']['headers']
    report = client.post('/api/v1/reports/drafts', headers=headers, json=payload).json()
    client.post(f"/api/v1/reports/{report['id']}/submit", headers=headers)
    return report['id']


def update(client, accounts, report_id, status='received', expected='submitted'):
    return client.patch(f'/api/v1/officer/cases/{report_id}/status', headers=accounts['officer']['headers'], json={'status': status, 'expected_status': expected})


def test_read_all_scoped_idempotent(client, accounts):
    with SessionLocal() as db:
        for name in ('student', 'student', 'other'):
            db.add(Notification(user_id=accounts[name]['id']))
        db.commit()
    path = '/api/v1/notifications/read-all'
    assert client.post(path).status_code == 401
    notices = client.post(path, headers=accounts['student']['headers']).json()
    assert len(notices) == 2 and all(n['read_at'] for n in notices)
    assert client.post(path, headers=accounts['student']['headers']).json() == notices
    assert client.get('/api/v1/notifications', headers=accounts['other']['headers']).json()[0]['read_at'] is None


def test_identity_requires_admin_reason_audit(client, accounts, payload):
    report_id = submitted(client, accounts, payload)
    path = f'/api/v1/officer/cases/{report_id}/reporter-identity'
    for name in ('officer', 'student', 'other'):
        assert client.post(path, headers=accounts[name]['headers'], json={'reason': 'Authorised case follow-up'}).status_code == 403
    with SessionLocal() as db:
        admin = User(email='admin@example.test', role=Role.ADMIN, password_hash='unused')
        db.add(admin)
        db.flush()
        headers = {'Authorization': 'Bearer ' + create_access_token(admin)}
        db.commit()
    assert client.post(path, headers=headers, json={'reason': '  '}).status_code == 422
    result = client.post(path, headers=headers, json={'reason': 'Authorised case follow-up'})
    assert result.json() == {'email': 'student@example.test'}
    assert result.headers['cache-control'] == 'no-store'
    detail = client.get(f'/api/v1/officer/cases/{report_id}', headers=headers).json()
    assert 'reporter_id' not in detail and 'email' not in detail
    with SessionLocal() as db:
        assert db.query(AuditLog).filter_by(action='reporter_identity_viewed').one().details == {'reason': 'Authorised case follow-up'}


def test_outbox_noop_stale_status(client, accounts, payload):
    path = '/api/v1/notifications/devices/register'
    assert client.post(path, json={'token': TOKEN}, headers=accounts['officer']['headers']).status_code == 403
    assert client.post(path, json={'token': TOKEN}, headers=accounts['student']['headers']).status_code == 200
    report_id = submitted(client, accounts, payload)
    assert update(client, accounts, report_id).status_code == 200
    assert update(client, accounts, report_id).status_code == 200
    assert update(client, accounts, report_id, 'under_review', 'submitted').status_code == 409
    with SessionLocal() as db:
        assert db.query(Notification).count() == 1
        assert db.query(PushDelivery).count() == 1
    sent = []
    assert deliver_one(lambda token, notice: sent.append((token, notice)))
    assert len(sent) == 1 and sent[0][0] == TOKEN
    assert not deliver_one(lambda *args: None)


def test_reassigned_token_cannot_deliver_previous_account(client, accounts, payload):
    path = '/api/v1/notifications/devices/register'
    client.post(path, json={'token': TOKEN}, headers=accounts['student']['headers'])
    update(client, accounts, submitted(client, accounts, payload))
    client.post(path, json={'token': TOKEN}, headers=accounts['other']['headers'])
    client.post('/api/v1/notifications/devices/revoke', json={'token': TOKEN}, headers=accounts['student']['headers'])
    with SessionLocal() as db:
        device = db.query(PushDevice).one()
        assert device.user_id == accounts['other']['id'] and device.active
    sent = []
    assert deliver_one(lambda *args: sent.append(args))
    assert not sent


def test_retries_invalid_device(client, accounts, payload):
    client.post('/api/v1/notifications/devices/register', json={'token': TOKEN}, headers=accounts['student']['headers'])
    update(client, accounts, submitted(client, accounts, payload))
    def unavailable(*args):
        raise RuntimeError('provider unavailable')
    assert deliver_one(unavailable)
    with SessionLocal() as db:
        row = db.query(PushDelivery).one()
        assert row.attempts == 1 and row.state == 'pending'
        row.next_attempt_at = datetime.now(UTC)
        db.commit()
    def invalid(*args):
        raise InvalidDevice()
    assert deliver_one(invalid)
    with SessionLocal() as db:
        assert db.query(PushDelivery).one().state == 'skipped'
        assert not db.query(PushDevice).one().active


def test_read_notices_skipped(client, accounts, payload):
    client.post('/api/v1/notifications/devices/register', json={'token': TOKEN}, headers=accounts['student']['headers'])
    update(client, accounts, submitted(client, accounts, payload))
    client.post('/api/v1/notifications/read-all', headers=accounts['student']['headers'])
    sent = []
    assert deliver_one(lambda *args: sent.append(args))
    assert not sent


def test_provider_payload_is_neutral(monkeypatch):
    from uuid import uuid4
    from firebase_admin import messaging
    from app.services.push import FirebaseSender
    messages = []
    monkeypatch.setattr(messaging, 'send', lambda message, **kwargs: messages.append(message))
    sender = FirebaseSender.__new__(FirebaseSender)
    sender.app = None
    notice_id = uuid4()
    sender(TOKEN, notice_id)
    message = messages[0]
    assert message.token == TOKEN
    assert message.notification.title == 'HERVOICE'
    assert message.notification.body == 'You have a new update. Open HERVOICE to view it.'
    assert message.data == {'screen': 'updates'}
    assert message.android.notification.visibility == 'private'
    assert message.android.notification.tag == str(notice_id)


def test_retry_limit_preserves_in_app_update(client, accounts, payload):
    client.post('/api/v1/notifications/devices/register', json={'token': TOKEN}, headers=accounts['student']['headers'])
    update(client, accounts, submitted(client, accounts, payload))
    def unavailable(*args):
        raise RuntimeError('provider unavailable')
    for _ in range(5):
        with SessionLocal() as db:
            db.query(PushDelivery).one().next_attempt_at = datetime.now(UTC)
            db.commit()
        assert deliver_one(unavailable)
    with SessionLocal() as db:
        delivery = db.query(PushDelivery).one()
        assert delivery.state == 'failed' and delivery.attempts == 5
        assert db.query(Notification).one().read_at is None
    assert not deliver_one(unavailable)
