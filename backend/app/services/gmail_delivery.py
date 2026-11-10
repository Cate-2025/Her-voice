"""Send-only Gmail API delivery over HTTPS; no SMTP or mailbox reading."""
import base64
import threading

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
import requests

from app.config import settings

SCOPES = ['https://www.googleapis.com/auth/gmail.send']
_credentials = None
_lock = threading.Lock()


def send_message(message):
    global _credentials
    if not all((settings.gmail_sender, settings.gmail_client_id,
                settings.gmail_client_secret, settings.gmail_refresh_token)):
        raise RuntimeError('Gmail delivery is not configured')
    try:
        with _lock:
            if _credentials is None:
                _credentials = Credentials(None, refresh_token=settings.gmail_refresh_token,
                    token_uri='https://oauth2.googleapis.com/token',
                    client_id=settings.gmail_client_id, client_secret=settings.gmail_client_secret,
                    scopes=SCOPES)
            if not _credentials.valid:
                transport = Request()

                def bounded_request(*args, **kwargs):
                    kwargs['timeout'] = 5
                    return transport(*args, **kwargs)

                _credentials.refresh(bounded_request)
            token = _credentials.token
        encoded = base64.urlsafe_b64encode(message.as_bytes()).decode('ascii')
        response = requests.post('https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
            headers={'Authorization': 'Bearer '+token}, json={'raw': encoded}, timeout=10)
        try:
            response.raise_for_status()
        finally:
            response.close()
    except Exception:
        # Provider errors can contain tokens, recipients or message contents.
        raise RuntimeError('Gmail delivery is unavailable; operator reauthorization may be required') from None
