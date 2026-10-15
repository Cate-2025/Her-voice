"""Run from backend: python -m scripts.run_prototype. Fictional data only.

Set HERVOICE_DEMO_PASSWORD on first use, or enter it at the prompt.
The database persists in backend/.prototype; existing passwords are unchanged.
"""
import getpass
import os
from pathlib import Path
import secrets
import pixeltable_pgserver


def main():
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    data = root / '.prototype'
    data.mkdir(exist_ok=True)
    secret_file = data / 'jwt-secret'
    if not secret_file.exists():
        fd = os.open(secret_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as file:
            file.write(secrets.token_urlsafe(48))
    pg = pixeltable_pgserver.get_server(data / 'postgres')
    os.environ.update(
        APP_ENV='development', DATABASE_URL=pg.get_uri(driver='psycopg'),
        JWT_SECRET=secret_file.read_text(), OBJECT_STORAGE_ENDPOINT='http://127.0.0.1:9000',
        OBJECT_STORAGE_ACCESS_KEY='unused-prototype', OBJECT_STORAGE_SECRET_KEY='unused-prototype',
    )
    from alembic import command
    from alembic.config import Config
    from app.database import SessionLocal
    from scripts.seed_demo_users import seed_users
    import uvicorn
    command.upgrade(Config('alembic.ini'), 'head')
    password = os.environ.get('HERVOICE_DEMO_PASSWORD') or getpass.getpass('Demo password (12+ characters; existing passwords unchanged): ')
    with SessionLocal() as db:
        created = seed_users(db, password)
    print(f'{created} demo accounts created. Student: student@example.test; officer: officer@example.test')
    print('API: http://127.0.0.1:8000/docs | Officer dashboard: http://127.0.0.1:8000/admin/')
    print('Fictional data only. Attachment uploads are not part of this milestone.')
    uvicorn.run('app.main:app', host='127.0.0.1', port=8000)


if __name__ == '__main__':
    main()
