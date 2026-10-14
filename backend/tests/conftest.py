"""Integration tests use a temporary PostgreSQL cluster, never a configured database."""
import os
from pathlib import Path
import tempfile

import pixeltable_pgserver
import pytest

# Settings are imported at module load throughout the existing app.
_pg = pixeltable_pgserver.get_server(Path(tempfile.mkdtemp(prefix='hervoice-tests-')))
os.environ.update(
    DATABASE_URL=_pg.get_uri(driver='psycopg'),
    JWT_SECRET='fictional-integration-test-secret-32chars',
    OBJECT_STORAGE_ENDPOINT='http://localhost:9000',
    OBJECT_STORAGE_ACCESS_KEY='fictional', OBJECT_STORAGE_SECRET_KEY='fictional',
)
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import text
from app.database import Base, engine, SessionLocal
from app.main import app
from app.models import Role, User
from app.security import create_access_token, password_hash


@pytest.fixture(scope='session', autouse=True)
def database():
    command.upgrade(Config('alembic.ini'), 'head')
    yield
    engine.dispose()
    _pg.cleanup()


@pytest.fixture(autouse=True)
def clean_data(database):
    with engine.begin() as connection:
        tables = ', '.join('"' + table.name + '"' for table in Base.metadata.sorted_tables)
        connection.execute(text(f'TRUNCATE {tables} CASCADE'))


@pytest.fixture
def client():
    with TestClient(app) as client:
        yield client


@pytest.fixture
def accounts():
    with SessionLocal() as db:
        result = {}
        for name, role in [('student', Role.STUDENT), ('other', Role.STUDENT), ('officer', Role.OFFICER)]:
            user = User(email=f'{name}@example.test', role=role, password_hash=password_hash.hash('fictional-password'))
            db.add(user)
            db.flush()
            result[name] = {'id': user.id, 'headers': {'Authorization': f'Bearer {create_access_token(user)}'}}
        db.commit()
        return result


@pytest.fixture
def payload():
    return {'report_mode': 'confidential', 'subject_staff_ref': 'STAFF-DEMO-01',
            'idempotency_key': 'fictional-operation-0001', 'timeline': [
                {'occurred_at': '2026-09-18T10:30:00+03:00', 'narrative': 'Fictional event only.'}]}
