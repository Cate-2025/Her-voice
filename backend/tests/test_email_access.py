import re
from datetime import UTC, datetime, timedelta
from pathlib import Path
import pytest
from app.config import settings
from app.database import SessionLocal
from app.models import EmailChallenge, Role, User


@pytest.fixture
def mailbox(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, 'email_delivery', 'file')
    monkeypatch.setattr(settings, 'email_preview_path', str(tmp_path))
    monkeypatch.setattr(settings, 'app_env', 'development')
    return tmp_path


def code(mailbox):
    file = max(mailbox.glob('*.eml'), key=lambda path:path.stat().st_mtime_ns)
    return re.search(r'code is (\d{8})',file.read_text()).group(1)


def test_verified_registration_any_domain_no_role_escalation(client, mailbox):
    email='new-person@independent.example'
    assert client.post('/api/v1/auth/email-code',json={'email':email,'purpose':'register'}).status_code == 200
    with SessionLocal() as db:
        assert db.query(User).count() == 0
        assert db.query(EmailChallenge).one().code_hash != code(mailbox)
    payload={'email':email,'purpose':'register','code':code(mailbox),'password':'fictional-password-new','role':'admin'}
    assert client.post('/api/v1/auth/email-code/complete',json=payload).status_code == 200
    assert client.post('/api/v1/auth/email-code/complete',json=payload).status_code == 400
    result=client.post('/api/v1/auth/login',json={'email':email,'password':payload['password']})
    assert result.status_code == 200
    with SessionLocal() as db:
        assert db.query(User).one().role == Role.STUDENT


def test_wrong_expired_and_throttled_codes(client, mailbox):
    request={'email':'new-person@independent.example','purpose':'register'}
    assert client.post('/api/v1/auth/email-code',json=request).status_code == 200
    assert client.post('/api/v1/auth/email-code',json=request).status_code == 429
    valid=code(mailbox)
    bad='00000000' if valid != '00000000' else '11111111'
    for _ in range(5):
        assert client.post('/api/v1/auth/email-code/complete',json={**request,'code':bad,'password':'fictional-password'}).status_code == 400
    assert client.post('/api/v1/auth/email-code/complete',json={**request,'code':valid,'password':'fictional-password'}).status_code == 400
    with SessionLocal() as db:
        challenge=db.query(EmailChallenge).one()
        challenge.attempts=0
        challenge.expires_at=datetime.now(UTC)-timedelta(seconds=1)
        db.commit()
    assert client.post('/api/v1/auth/email-code/complete',json={**request,'code':valid,'password':'fictional-password'}).status_code == 400


def test_password_reset_revokes_existing_sessions(client, accounts, mailbox):
    request={'email':'student@example.test','purpose':'reset'}
    assert client.post('/api/v1/auth/email-code',json=request).status_code == 200
    assert client.post('/api/v1/auth/email-code/complete',json={**request,'code':code(mailbox),'password':'new-fictional-password'}).status_code == 200
    assert client.get('/api/v1/auth/me',headers=accounts['student']['headers']).status_code == 401
    assert client.post('/api/v1/auth/login',json={'email':request['email'],'password':'fictional-password'}).status_code == 401
    assert client.post('/api/v1/auth/login',json={'email':request['email'],'password':'new-fictional-password'}).status_code == 200


def test_email_disabled_fails_closed(client, monkeypatch):
    monkeypatch.setattr(settings,'email_delivery','disabled')
    assert client.post('/api/v1/auth/email-code',json={'email':'person@example.org','purpose':'register'}).status_code == 503
