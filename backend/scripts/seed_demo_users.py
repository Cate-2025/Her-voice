"""Create fictional accounts only; existing users/passwords are never overwritten."""
import getpass
import os

from sqlalchemy.orm import Session
from app.config import settings
from app.database import SessionLocal
from app.models import Role, User
from app.security import password_hash


def seed_users(db: Session, password: str) -> int:
    if settings.app_env != 'development':
        raise RuntimeError('Demo accounts may only be created in development')
    if len(password) < 12:
        raise ValueError('Use a demo password of at least 12 characters')
    created = 0
    for role in Role:
        email = f'{role.value}@example.test'
        if db.query(User).filter(User.email == email).first():
            continue
        db.add(User(email=email, role=role, password_hash=password_hash.hash(password)))
        created += 1
    db.commit()
    return created


if __name__ == '__main__':
    password = os.environ.get('HERVOICE_DEMO_PASSWORD') or getpass.getpass('Fictional demo password (12+ characters): ')
    with SessionLocal() as db:
        print(f'Created {seed_users(db, password)} fictional accounts; existing accounts unchanged.')
    print('Accounts: student@example.test, officer@example.test, admin@example.test')
