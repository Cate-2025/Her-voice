"""No domain restriction: email ownership is not university eligibility."""
from datetime import UTC, datetime, timedelta
from email.message import EmailMessage
import hashlib
import hmac
import os
from pathlib import Path
import secrets
import smtplib
import ssl

from fastapi import HTTPException
from sqlalchemy.dialects.postgresql import insert
from app.config import settings
from app.models import AuthThrottle


def digest(value):
    return hmac.new(settings.jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def throttle(db, request, action, limit=20):
    now = datetime.now(UTC)
    key = digest(f'{action}:{request.client.host if request.client else "unknown"}')
    # A fixed key per source prevents unbounded rows from rotating time buckets.
    from sqlalchemy import case
    expired = AuthThrottle.window_start < now - timedelta(minutes=10)
    statement = insert(AuthThrottle).values(key=key, window_start=now, count=1)
    count = db.execute(statement.on_conflict_do_update(index_elements=['key'], set_={
        'window_start': case((expired, now), else_=AuthThrottle.window_start),
        'count': case((expired, 1), else_=AuthThrottle.count + 1),
    }).returning(AuthThrottle.count)).scalar_one()
    db.commit()
    if count > limit:
        raise HTTPException(status_code=429, detail='Too many attempts. Try again later.')


def send_code(email, code, purpose):
    message = EmailMessage()
    message['Subject'] = 'HERVOICE email verification' if purpose == 'register' else 'HERVOICE password reset'
    message['From'] = (settings.gmail_sender if settings.email_delivery == 'gmail_api'
                       else settings.smtp_from or 'prototype@example.test')
    message['To'] = email
    message.set_content(f'Your HERVOICE code is {code}. It expires in 15 minutes.\n\nIf you did not request this, ignore this email. Do not share this code.\n')
    if settings.email_delivery == 'file' and settings.app_env == 'development':
        folder = Path(settings.email_preview_path)
        folder.mkdir(parents=True, exist_ok=True, mode=0o700)
        path = folder / f'{secrets.token_hex(16)}.eml'
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as file: file.write(message.as_string())
        return
    if settings.email_delivery == 'gmail_api':
        from app.services.gmail_delivery import send_message
        send_message(message)
        return
    if settings.email_delivery != 'smtp' or not settings.smtp_host or not settings.smtp_from:
        raise RuntimeError('Email delivery not configured')
    context = ssl.create_default_context()
    if settings.smtp_security == 'ssl':
        connection = smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15, context=context)
    else:
        connection = smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15)
    with connection as server:
        if settings.smtp_security == 'starttls': server.starttls(context=context)
        if settings.smtp_user: server.login(settings.smtp_user, settings.smtp_password)
        server.send_message(message)
