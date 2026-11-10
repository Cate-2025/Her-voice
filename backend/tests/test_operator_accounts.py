import pytest
from app.database import SessionLocal
from app.models import Role, User
from scripts.bootstrap_admin import bootstrap
from scripts.provision_test_accounts import provision, verify_journey


def test_closed_test_provisioning_preserves_admin_and_hashes_passwords():
    with SessionLocal() as db:
        bootstrap(db, 'owner@institution.example', 'private-admin-password')
        admin = db.query(User).filter(User.role == Role.ADMIN).one()
        original_hash = admin.password_hash
        provision(db, 'student@institution.example', 'private-student-password',
                  'officer@institution.example', 'private-officer-password')
        assert db.query(User).count() == 3
        assert db.query(User).filter(User.role == Role.ADMIN).one().password_hash == original_hash
        student = db.query(User).filter(User.role == Role.STUDENT).one()
        assert student.password_hash != 'private-student-password'
        with pytest.raises(ValueError):
            provision(db, 'owner@institution.example', 'another-student-password',
                      'new-officer@institution.example', 'another-officer-password')
        db.rollback()
        assert db.query(User).count() == 3


def test_provision_requires_admin_and_distinct_private_credentials():
    with SessionLocal() as db:
        with pytest.raises(ValueError):
            provision(db, 'student@institution.example', 'private-student-password',
                      'officer@institution.example', 'private-officer-password')
        db.rollback()
        assert db.query(User).count() == 0
        with pytest.raises(ValueError):
            provision(db, 'same@institution.example', 'same-password-long',
                      'same@institution.example', 'same-password-long')
        assert db.query(User).count() == 0


def test_private_operator_journey_exercises_reporting_and_evidence(client, accounts, monkeypatch, tmp_path):
    from app.config import settings
    monkeypatch.setattr(settings, 'evidence_storage', 'local')
    monkeypatch.setattr(settings, 'local_evidence_path', str(tmp_path))

    def call(method, path, payload=None, *, token=None, headers=None, raw=False):
        h = dict(headers or {})
        if token:
            h['Authorization'] = 'Bearer '+token
        args = {'content': payload} if isinstance(payload, bytes) else {'json': payload}
        response = client.request(method, '/api/v1'+path, headers=h, **args)
        assert response.is_success, (method, path, response.status_code)
        return response.content if raw else response.json()

    rid = verify_journey(call, 'student@example.test', 'fictional-password',
                         'officer@example.test', 'fictional-password')
    assert rid
