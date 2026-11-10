"""Synthetic configuration checks; integration tests always use temporary Postgres."""
import os

from sqlalchemy import create_engine, text

from app.config import Settings, settings
from app.database import engine


def configured(**values):
    return Settings(
        _env_file=None,
        jwt_secret='fictional-configuration-test-secret',
        object_storage_endpoint='http://localhost:9000',
        object_storage_access_key='fictional',
        object_storage_secret_key='fictional',
        **values,
    )


def test_neon_dotenv_precedence_driver_and_direct_migration_url(tmp_path, monkeypatch):
    for name in ('DATABASE_URL', 'DATABASE_URL_UNPOOLED'):
        monkeypatch.delenv(name, raising=False)
    base = tmp_path / '.env'
    local = tmp_path / '.env.local'
    base.write_text('DATABASE_URL=postgresql://fixture:fake@old.invalid/base\n')
    local.write_text(
        'DATABASE_URL=postgresql://fixture:fake@new-pooler.invalid/app?sslmode=require&channel_binding=require\n'
        'DATABASE_URL_UNPOOLED=postgresql://fixture:fake@new.invalid/app?sslmode=require\n'
    )
    values = configured(database_url='postgresql://fixture:fake@unused.invalid/base').model_dump()
    values.pop('database_url')
    values.pop('database_url_unpooled')
    result = Settings(_env_file=(base, local), **values)
    assert result.database_url == (
        'postgresql+psycopg://fixture:fake@new-pooler.invalid/app?sslmode=require&channel_binding=require'
    )
    assert result.migration_database_url == 'postgresql+psycopg://fixture:fake@new.invalid/app?sslmode=require'


def test_process_environment_wins_over_local_files(tmp_path, monkeypatch):
    local = tmp_path / '.env.local'
    local.write_text('DATABASE_URL=postgresql://fixture:fake@file.invalid/app\n'
                     'DATABASE_URL_UNPOOLED=postgresql://fixture:fake@file.invalid/app\n')
    monkeypatch.setenv('DATABASE_URL', 'postgres://fixture:fake@runtime.invalid/app')
    monkeypatch.setenv('DATABASE_URL_UNPOOLED', 'postgres://fixture:fake@migration.invalid/app')
    result = Settings(_env_file=local, jwt_secret='fictional', object_storage_endpoint='http://localhost',
                      object_storage_access_key='fictional', object_storage_secret_key='fictional')
    assert result.database_url == 'postgresql+psycopg://fixture:fake@runtime.invalid/app'
    assert result.migration_database_url == 'postgresql+psycopg://fixture:fake@migration.invalid/app'


def test_non_neon_database_can_use_one_url():
    result = configured(database_url='postgresql+psycopg://fixture:fake@local.invalid/app',
                        database_url_unpooled=None)
    assert result.migration_database_url == result.database_url


def test_statement_timeout_is_applied_to_every_transaction_and_is_local():
    with engine.connect() as connection:
        actual = connection.execute(text("SELECT current_setting('statement_timeout')::interval")).scalar_one()
        assert actual.total_seconds() * 1000 == settings.database_statement_timeout_ms
        connection.commit()
        again = connection.execute(text("SELECT current_setting('statement_timeout')::interval")).scalar_one()
        assert again == actual
        connection.rollback()
    independent = create_engine(settings.database_url)
    try:
        with independent.connect() as connection:
            assert connection.execute(text('SHOW statement_timeout')).scalar_one() == '0'
    finally:
        independent.dispose()


def test_test_migrations_are_pinned_to_the_isolated_database():
    assert settings.migration_database_url == settings.database_url
    assert '.neon.tech' not in settings.migration_database_url


def test_local_runner_overrides_a_hosted_migration_url(tmp_path, monkeypatch):
    from pathlib import Path
    from types import SimpleNamespace
    from unittest.mock import Mock
    from alembic import command
    from scripts import run_prototype, seed_demo_users
    import uvicorn

    local_url = settings.database_url
    root = tmp_path / 'backend'
    root.mkdir()
    monkeypatch.chdir(Path.cwd())  # Restore cwd after the runner changes it.
    for name in ('APP_ENV', 'EVIDENCE_STORAGE', 'LOCAL_EVIDENCE_PATH', 'DATABASE_URL',
                 'DATABASE_URL_UNPOOLED', 'JWT_SECRET', 'OBJECT_STORAGE_ENDPOINT',
                 'OBJECT_STORAGE_ACCESS_KEY', 'OBJECT_STORAGE_SECRET_KEY'):
        monkeypatch.setenv(name, os.environ.get(name, ''))
    monkeypatch.setattr(run_prototype, '__file__', str(root / 'scripts/run_prototype.py'))
    monkeypatch.setattr(run_prototype.pixeltable_pgserver, 'get_server',
                        lambda path: SimpleNamespace(get_uri=lambda **kwargs: local_url))
    monkeypatch.setenv('DATABASE_URL_UNPOOLED', 'postgresql://fixture:fake@production.invalid/app')
    monkeypatch.setenv('HERVOICE_DEMO_PASSWORD', 'fictional-fixture-password')
    checked = []

    def isolated_upgrade(config, revision):
        result = Settings(_env_file=None)
        assert result.database_url == local_url
        assert result.migration_database_url == local_url
        checked.append(revision)

    monkeypatch.setattr(command, 'upgrade', isolated_upgrade)
    monkeypatch.setattr(seed_demo_users, 'seed_users', lambda db, password: 0)
    monkeypatch.setattr(uvicorn, 'run', Mock())
    run_prototype.main()
    assert checked == ['head']
