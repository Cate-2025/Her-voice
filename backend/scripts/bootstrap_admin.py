"""Interactive initial administrator bootstrap; never overwrites existing users."""
import getpass
from pydantic import TypeAdapter, EmailStr
from sqlalchemy import select, func
from app.database import SessionLocal
from app.models import Role, User
from app.security import password_hash


def bootstrap(db, email: str, password: str):
    email = str(TypeAdapter(EmailStr).validate_python(email)).lower()
    if not 12 <= len(password) <= 128:
        raise ValueError('Use a password of 12 to 128 characters')
    # Serialize concurrent bootstrap attempts, without opening general role changes.
    db.execute(select(func.pg_advisory_xact_lock(1200926634)))
    if db.query(User).filter(User.role == Role.ADMIN).first():
        raise ValueError('An administrator already exists; use the approved access process')
    if db.query(User).filter(User.email == email).first():
        raise ValueError('This account already exists; no account was changed')
    db.add(User(email=email, password_hash=password_hash.hash(password), role=Role.ADMIN))
    db.commit()


if __name__ == '__main__':
    email = input('Initial administrator email: ').strip()
    password = getpass.getpass('Password (12 to 128 characters): ')
    if password != getpass.getpass('Confirm password: '):
        raise SystemExit('Passwords do not match; no account was changed')
    try:
        with SessionLocal() as db:
            bootstrap(db, email, password)
    except ValueError as error:
        # Email validation errors can include input; keep CLI output neutral.
        raise SystemExit('Bootstrap refused. Check the address, password length and existing administrators.') from None
    print('Initial administrator created. No existing accounts were modified.')
