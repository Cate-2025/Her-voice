"""Privately provision two test roles; never replace users or create admins."""
import getpass
import hashlib
import json
import sys
from datetime import UTC, datetime
from urllib.request import Request, urlopen
from uuid import uuid4

API = 'https://her-voice-e2mu.onrender.com/api/v1'


def provision(db, student_email, student_password, officer_email, officer_password):
    from pydantic import EmailStr, TypeAdapter
    from app.models import Role, User
    from app.security import password_hash
    from sqlalchemy import select, func
    student_email = str(TypeAdapter(EmailStr).validate_python(student_email)).lower()
    officer_email = str(TypeAdapter(EmailStr).validate_python(officer_email)).lower()
    if student_email == officer_email or student_password == officer_password:
        raise ValueError('Use separate addresses and passwords for the two test roles.')
    if any(not 12 <= len(p) <= 128 for p in (student_password, officer_password)):
        raise ValueError('Passwords must be 12 to 128 characters.')
    db.execute(select(func.pg_advisory_xact_lock(1200926635)))
    if db.query(User).filter(User.email.in_([student_email, officer_email])).first():
        raise ValueError('An address already exists. No account was replaced or promoted.')
    if not db.query(User).filter(User.role == Role.ADMIN, User.is_active.is_(True)).first():
        raise ValueError('An active administrator must exist first.')
    for email, password, role in ((student_email, student_password, Role.STUDENT),
                                  (officer_email, officer_password, Role.OFFICER)):
        db.add(User(email=email, role=role, password_hash=password_hash.hash(password)))
    db.commit()


def verify_journey(call, student_email, student_password, officer_email, officer_password):
    """Use only supplied test accounts and a clearly fictional report."""
    def login(email, password):
        return call('POST', '/auth/login', {'email': email, 'password': password})['access_token']
    student, officer = login(student_email, student_password), login(officer_email, officer_password)
    assert call('GET', '/auth/me', token=student)['role'] == 'student'
    assert call('GET', '/auth/me', token=officer)['role'] == 'officer'
    payload = {'report_mode': 'confidential', 'subject_staff_ref': 'HOSTED-TEST-'+str(uuid4()),
        'idempotency_key': str(uuid4()), 'timeline': [{'occurred_at': datetime.now(UTC).isoformat(),
        'narrative': 'Fictional deployment acceptance test. No real person or allegation.'}]}
    report = call('POST', '/reports/drafts', payload, token=student)
    rid, fid = report['id'], str(uuid4())
    data = b'%PDF-1.7\nFictional deployment fixture, not personal evidence.\n%%EOF'
    call('PUT', f'/evidence/reports/{rid}/files/{fid}', data, token=student,
         headers={'Content-Type': 'application/pdf', 'X-Evidence-Name': 'fictional-hosted-check.pdf',
                  'X-Evidence-SHA256': hashlib.sha256(data).hexdigest()})
    call('POST', f'/reports/{rid}/submit', token=student)
    detail = call('GET', f'/officer/cases/{rid}', token=officer)
    assert 'reporter_id' not in detail and 'email' not in detail
    assert call('GET', f'/evidence/{fid}/file', token=officer, raw=True) == data
    call('PATCH', f'/officer/cases/{rid}/status',
         {'status': 'received', 'expected_status': 'submitted'}, token=officer)
    assert call('GET', f'/reports/{rid}', token=student)['status'] == 'received'
    notices = call('GET', '/notifications', token=student)
    assert notices
    call('POST', '/notifications/read-all', token=student)
    assert all(n['read_at'] for n in call('GET', '/notifications', token=student))
    return rid


def api_call(method, path, payload=None, *, token=None, headers=None, raw=False):
    h = dict(headers or {})
    if token:
        h['Authorization'] = 'Bearer ' + token
    if payload is not None and not isinstance(payload, bytes):
        payload = json.dumps(payload).encode()
        h['Content-Type'] = 'application/json'
    with urlopen(Request(API+path, data=payload, headers=h, method=method), timeout=30) as response:
        body = response.read()
        return body if raw else json.loads(body)


def main():
    if not sys.stdin.isatty():
        raise SystemExit('Run this command in your own terminal; private password entry requires a TTY.')
    from scripts.create_initial_admin import prepare_database_environment
    prepare_database_environment()
    from app.database import SessionLocal
    print('Creates one student and one officer in Neon; existing accounts remain unchanged.')
    print('Then verifies the hosted API using one clearly fictional report and file.')
    print('Passwords are hidden, never logged, and not saved to a credentials file.')
    student_email = input('Student test email: ').strip()
    student_password = getpass.getpass('Student password (12–128 characters): ')
    if student_password != getpass.getpass('Confirm student password: '):
        raise SystemExit('Passwords do not match. No accounts were created.')
    officer_email = input('Officer test email: ').strip()
    officer_password = getpass.getpass('Officer password (12–128 characters): ')
    if officer_password != getpass.getpass('Confirm officer password: '):
        raise SystemExit('Passwords do not match. No accounts were created.')
    try:
        with SessionLocal() as db:
            provision(db, student_email, student_password, officer_email, officer_password)
    except ValueError:
        raise SystemExit('Provisioning refused: check unique new addresses, passwords and administrator access. Existing accounts were unchanged.') from None
    except Exception:
        raise SystemExit('Account creation could not be confirmed. Ask for an account check before retrying; private error details are withheld.') from None
    print('Both test accounts created. Waking the hosted API if necessary…')
    try:
        with urlopen('https://her-voice-e2mu.onrender.com/ready', timeout=120) as response:
            assert response.status == 200
        rid = verify_journey(api_call, student_email, student_password, officer_email, officer_password)
    except Exception:
        raise SystemExit('Accounts created, but hosted verification did not finish. Keep your credentials and report this outcome; do not rerun provisioning.') from None
    print('Hosted sign-in, evidence integrity, officer privacy, status and updates verified.')
    print('Fictional test report retained for manual review:', rid)


if __name__ == '__main__':
    main()
