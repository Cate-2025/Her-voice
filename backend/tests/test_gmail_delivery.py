import base64
from email import message_from_bytes
from unittest.mock import Mock, patch

import pytest
from app.config import settings
from app.services import gmail_delivery
from app.services.email_access import send_code
from test_deployment import hosted


@pytest.fixture
def gmail(monkeypatch):
    for name, value in {'email_delivery': 'gmail_api', 'gmail_sender': 'sender@institution.example',
                        'gmail_client_id': 'fixture-client', 'gmail_client_secret': 'fixture-secret',
                        'gmail_refresh_token': 'fixture-refresh'}.items():
        monkeypatch.setattr(settings, name, value)
    monkeypatch.setattr(gmail_delivery, '_credentials', None)


def test_hosted_gmail_requires_all_secrets():
    values = dict(email_delivery='gmail_api', gmail_sender='sender@institution.example',
                  gmail_client_id='fixture-client', gmail_client_secret='fixture-secret',
                  gmail_refresh_token='fixture-refresh')
    assert hosted(**values).email_delivery == 'gmail_api'
    from pydantic import ValidationError
    for field in ('gmail_sender', 'gmail_client_id', 'gmail_client_secret', 'gmail_refresh_token'):
        with pytest.raises(ValidationError):
            hosted(**{**values, field: ''})


def test_gmail_sends_expected_code_via_https_without_smtp(gmail):
    credentials = Mock(valid=True, token='fixture-token')
    with patch.object(gmail_delivery, 'Credentials', return_value=credentials) as factory, \
            patch.object(gmail_delivery.requests, 'post') as post, \
            patch('app.services.email_access.smtplib.SMTP') as smtp:
        send_code('recipient@institution.example', '12345678', 'register')
        assert factory.call_args.kwargs['scopes'] == ['https://www.googleapis.com/auth/gmail.send']
        assert post.call_args.args[0] == 'https://gmail.googleapis.com/gmail/v1/users/me/messages/send'
        assert post.call_args.kwargs['timeout'] == 10
        message = message_from_bytes(base64.urlsafe_b64decode(post.call_args.kwargs['json']['raw']))
        assert message['From'] == 'sender@institution.example'
        assert message['To'] == 'recipient@institution.example'
        assert '12345678' in message.get_payload()
        smtp.assert_not_called()
        post.return_value.close.assert_called_once()


def test_expired_access_token_is_refreshed_once_and_reused(gmail):
    credentials = Mock(valid=False, token='fixture-token')
    def refresh(request):
        request('https://oauth2.googleapis.com/token', method='POST')
        credentials.valid = True
    credentials.refresh.side_effect = refresh
    with patch.object(gmail_delivery, 'Credentials', return_value=credentials), \
            patch.object(gmail_delivery, 'Request') as transport, \
            patch.object(gmail_delivery.requests, 'post'):
        send_code('recipient@institution.example', '12345678', 'reset')
        send_code('recipient@institution.example', '87654321', 'reset')
        credentials.refresh.assert_called_once()
        assert transport.return_value.call_args.kwargs['timeout'] == 5


def test_provider_errors_never_expose_tokens_or_codes(gmail):
    with patch.object(gmail_delivery, 'Credentials', return_value=Mock(valid=True, token='fixture-token')), \
            patch.object(gmail_delivery.requests, 'post', side_effect=RuntimeError('fixture-refresh 12345678')):
        with pytest.raises(RuntimeError) as error:
            send_code('recipient@institution.example', '12345678', 'register')
        assert 'fixture-refresh' not in str(error.value) and '12345678' not in str(error.value)
