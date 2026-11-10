"""Database-only launcher for the existing private administrator prompts."""
import os
from pathlib import Path
import runpy
import secrets
import sys

from dotenv import dotenv_values


def prepare_database_environment():
    root = Path(__file__).resolve().parents[1]
    values = {**dotenv_values(root / '.env'), **dotenv_values(root / '.env.local')}
    url = (os.environ.get('DATABASE_URL_UNPOOLED') or os.environ.get('DATABASE_URL')
           or values.get('DATABASE_URL_UNPOOLED') or values.get('DATABASE_URL'))
    if not url:
        raise SystemExit('No database connection configured. No account was changed.')
    # Shared imports require these unrelated settings. They exist only in this
    # process: no server starts and no hosting secrets/configuration are saved.
    os.environ.update(DATABASE_URL=url, DATABASE_URL_UNPOOLED=url,
        APP_ENV='development', JWT_SECRET=secrets.token_urlsafe(48),
        OBJECT_STORAGE_ENDPOINT='http://127.0.0.1:9000',
        OBJECT_STORAGE_ACCESS_KEY='unused-admin-bootstrap',
        OBJECT_STORAGE_SECRET_KEY='unused-admin-bootstrap', PUSH_ENABLED='false')
    os.chdir(root)
    return root


def main():
    prepare_database_environment()
    try:
        from sqlalchemy import create_engine, text
        from app.config import settings
        from alembic.config import Config
        from alembic.script import ScriptDirectory
        engine = create_engine(settings.migration_database_url,
                               connect_args={'connect_timeout': 10})
        try:
            with engine.connect().execution_options(postgresql_readonly=True) as conn:
                installed = set(conn.execute(text('SELECT version_num FROM alembic_version')).scalars())
                expected = set(ScriptDirectory.from_config(Config('alembic.ini')).get_heads())
                if installed != expected:
                    raise SystemExit('Database migrations are not current. No account was changed.')
                count = conn.execute(text("SELECT count(*) FROM users WHERE role::text='ADMIN'")).scalar_one()
                if count:
                    raise SystemExit('An administrator already exists. No account was changed.')
        finally:
            engine.dispose()
        if '--check' in sys.argv:
            print('Database reachable, schema current, no existing administrator. Ready for private prompts.')
            return
        print('Creating the first administrator in the configured database.')
        print('Password entry is hidden. No API server will be started.')
        runpy.run_module('scripts.bootstrap_admin', run_name='__main__')
    except KeyboardInterrupt:
        raise SystemExit('Cancelled.') from None
    except Exception:
        raise SystemExit('Admin setup failed. Check database connectivity; credentials are withheld.') from None


if __name__ == '__main__':
    main()
