import pytest
from app.database import SessionLocal
from app.models import User
from app.security import password_hash
from scripts.seed_demo_users import seed_users


def test_demo_seed_is_repeatable_and_does_not_reset_passwords():
    with SessionLocal() as db:
        assert seed_users(db, 'fictional-password') == 3
        assert seed_users(db, 'different-password') == 0
        assert db.query(User).count() == 3
        assert password_hash.verify('fictional-password', db.query(User).first().password_hash)
        with pytest.raises(ValueError):
            seed_users(db, 'short')
