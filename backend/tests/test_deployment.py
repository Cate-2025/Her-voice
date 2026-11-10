from pathlib import Path
from unittest.mock import patch
import pytest
from pydantic import ValidationError
from app.config import Settings
from app.main import app


def hosted(**overrides):
    values = dict(app_env='staging', database_url='postgresql+psycopg://app:real-password@db/service',
        jwt_secret='a-generated-secret-with-more-than-32-characters',
        evidence_storage='s3', object_storage_endpoint='https://storage.internal',
        object_storage_access_key='real-access-key', object_storage_secret_key='real-storage-secret',
        email_delivery='smtp', smtp_host='mail.internal', smtp_from='support@institution.org',
        cors_origins=['https://service.institution.org'])
    values.update(overrides)
    return Settings(_env_file=None, **values)


def test_hosted_configuration_accepts_complete_settings():
    assert hosted().app_env == 'staging'


@pytest.mark.parametrize('invalid', [
    {'jwt_secret': 'replace-with-a-long-random-secret-before-running'},
    {'evidence_storage': 'local'}, {'email_delivery': 'file'},
    {'app_env': 'production', 'email_delivery': 'disabled'}, {'cors_origins': ['http://localhost']},
    {'object_storage_endpoint': 'http://storage.internal'},
    {'object_storage_endpoint': 'https:/missing-host'},
    {'object_storage_endpoint': 'https://user:password@storage.internal'},
    {'cors_origins': ['https://service.institution.org/admin']},
    {'cors_origins': ['https:/missing-host']},
    {'database_url': 'postgresql+psycopg://app:replace-password@db/service'},
])
def test_hosted_configuration_fails_closed(invalid):
    with pytest.raises(ValidationError):
        hosted(**invalid)


def test_staging_can_defer_mail_without_enabling_file_delivery():
    assert hosted(email_delivery='disabled').email_delivery == 'disabled'
    with pytest.raises(ValidationError):
        hosted(email_delivery='file')


def test_readiness_distinguishes_dependencies_from_liveness(client, monkeypatch, tmp_path):
    from app.config import settings
    monkeypatch.setattr(settings, 'evidence_storage', 'local')
    monkeypatch.setattr(settings, 'local_evidence_path', str(tmp_path))
    assert client.get('/health').json() == {'status': 'ok'}
    assert client.get('/ready').json() == {'status': 'ready'}
    assert list(tmp_path.iterdir()) == []
    with patch('app.main.engine.connect', side_effect=RuntimeError('private connection string')):
        response = client.get('/ready')
    assert response.status_code == 503
    assert response.json() == {'status': 'unavailable'}
    assert 'private' not in response.text
    assert response.headers['cache-control'] == 'no-store'
    assert client.get('/health').status_code == 200


def test_storage_readiness_failure_is_neutral(client, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, 'evidence_storage', 's3')
    with patch('app.main.storage_client') as storage:
        storage.return_value.head_bucket.side_effect = RuntimeError('secret-storage-details')
        assert client.get('/ready').status_code == 503


def test_bootstrap_is_initial_only_and_never_promotes_existing_users(accounts):
    from scripts.bootstrap_admin import bootstrap
    from app.database import SessionLocal
    from app.models import User, Role
    with SessionLocal() as db:
        with pytest.raises(ValueError):
            bootstrap(db, 'student@example.test', 'fictional-password')
        db.rollback()
        assert db.get(User, accounts['student']['id']).role == Role.STUDENT
        bootstrap(db, 'initial-admin@institution.org', 'fictional-password')
        with pytest.raises(ValueError):
            bootstrap(db, 'second-admin@institution.org', 'fictional-password')
        db.rollback()
        assert db.query(User).filter(User.role == Role.ADMIN).count() == 1



def test_readiness_rejects_outdated_schema(client, monkeypatch, tmp_path):
    from sqlalchemy import text
    from app.database import engine
    from app.config import settings
    monkeypatch.setattr(settings, 'evidence_storage', 'local')
    monkeypatch.setattr(settings, 'local_evidence_path', str(tmp_path))
    with engine.begin() as connection:
        original = connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one()
        connection.execute(text("UPDATE alembic_version SET version_num='outdated-fixture'"))
    try:
        assert client.get('/health').status_code == 200
        response = client.get('/ready')
        assert response.status_code == 503
        assert response.json() == {'status':'unavailable'}
    finally:
        with engine.begin() as connection:
            connection.execute(text('UPDATE alembic_version SET version_num=:version'), {'version':original})
    assert client.get('/ready').status_code == 200
