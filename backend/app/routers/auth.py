from fastapi import APIRouter, Depends, HTTPException, Request, status
from datetime import UTC, datetime, timedelta
import hmac
import secrets
from sqlalchemy import text
from app.config import settings
from app.models import EmailChallenge, PushDevice, Role
from app.schemas import EmailCodeRequest, EmailCodeComplete
from app.security import password_hash
from app.services.email_access import digest, send_code, throttle
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import LoginRequest, TokenResponse, UserSummary
from app.security import authenticate_user, create_access_token, get_current_user

router = APIRouter(prefix="/api/v1/auth", tags=["authentication"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)) -> TokenResponse:
    throttle(db, request, 'login', limit=30)
    user = authenticate_user(db, payload.email.strip(), payload.password)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    return TokenResponse(access_token=create_access_token(user))


@router.get("/me", response_model=UserSummary)
def current_account(user: User = Depends(get_current_user)) -> User:
    return user


@router.post('/email-code')
def request_email_code(payload: EmailCodeRequest, request: Request, db: Session = Depends(get_db)):
    if settings.email_delivery == 'disabled':
        raise HTTPException(status_code=503, detail='Email delivery is not configured')
    throttle(db, request, 'email-code', limit=10)
    now = datetime.now(UTC)
    # Serialize requests for the same email even before a challenge row exists.
    db.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': int(digest(payload.email)[:15],16)})
    challenge = db.get(EmailChallenge, (payload.email, payload.purpose))
    if challenge and challenge.sent_at > now - timedelta(seconds=60):
        raise HTTPException(status_code=429, detail='Wait a minute before requesting another code')
    user = db.query(User).filter_by(email=payload.email).one_or_none()
    eligible = (not user) if payload.purpose == 'register' else bool(user and user.is_active)
    code = f'{secrets.randbelow(100_000_000):08d}'
    challenge = challenge or EmailChallenge(email=payload.email, purpose=payload.purpose)
    challenge.code_hash = digest(f'{payload.email}:{payload.purpose}:{code}')
    challenge.sent_at = now
    challenge.expires_at = now + timedelta(minutes=15)
    challenge.attempts = 0
    db.add(challenge)
    if eligible:
        try: send_code(payload.email, code, payload.purpose)
        except Exception:
            db.rollback()
            raise HTTPException(status_code=503, detail='Email could not be sent. Try again later.')
    db.commit()
    return {'message':'If this address is eligible, a code has been sent. Codes expire in 15 minutes.'}


@router.post('/email-code/complete')
def complete_email_code(payload: EmailCodeComplete, request: Request, db: Session = Depends(get_db)):
    throttle(db, request, 'email-verify', limit=30)
    db.execute(text('SELECT pg_advisory_xact_lock(:key)'), {'key': int(digest(payload.email)[:15],16)})
    challenge = db.get(EmailChallenge, (payload.email, payload.purpose))
    if not challenge or challenge.expires_at <= datetime.now(UTC) or challenge.attempts >= 5:
        raise HTTPException(status_code=400, detail='Invalid or expired code. Request another code.')
    if not hmac.compare_digest(challenge.code_hash, digest(f'{payload.email}:{payload.purpose}:{payload.code}')):
        challenge.attempts += 1
        db.commit()
        raise HTTPException(status_code=400, detail='Invalid or expired code. Request another code.')
    user = db.query(User).filter_by(email=payload.email).with_for_update().one_or_none()
    if payload.purpose == 'register':
        if user: raise HTTPException(status_code=400, detail='Unable to complete registration. Try signing in.')
        user = User(email=payload.email, password_hash=password_hash.hash(payload.password), role=Role.STUDENT, is_active=True)
        db.add(user)
    else:
        if not user or not user.is_active: raise HTTPException(status_code=400, detail='Unable to complete reset')
        user.password_hash = password_hash.hash(payload.password)
        user.token_version += 1
        db.query(PushDevice).filter_by(user_id=user.id).update({PushDevice.active:False})
    db.delete(challenge)
    db.commit()
    return {'message':'Email verified. You can now sign in.'}
