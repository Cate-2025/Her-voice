"""Local, browser-approved send-only Gmail authorization. No messages are sent."""
import argparse
import json
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client-secrets', type=Path, required=True)
    parser.add_argument('--sender', required=True)
    parser.add_argument('--replace', action='store_true', help='Replace a previous authorization after browser consent')
    args = parser.parse_args()
    from pydantic import EmailStr, TypeAdapter
    from google_auth_oauthlib.flow import InstalledAppFlow
    try:
        sender = str(TypeAdapter(EmailStr).validate_python(args.sender))
        client = json.loads(args.client_secrets.read_text())
        if 'installed' not in client:
            raise ValueError('A Desktop app OAuth client is required')
        folder = Path(__file__).resolve().parents[1] / '.secrets'
        folder.mkdir(mode=0o700, exist_ok=True)
        destination = folder / 'gmail-sender.json'
        if destination.exists() and not args.replace:
            raise SystemExit('Authorization already exists. Use --replace only to renew it.')
        flow = InstalledAppFlow.from_client_config(client,
            scopes=['https://www.googleapis.com/auth/gmail.send'], autogenerate_code_verifier=True)
        credentials = flow.run_local_server(host='127.0.0.1', port=0, open_browser=True,
            prompt='consent', access_type='offline', timeout_seconds=300,
            success_message='HERVOICE Gmail sending authorized. You can close this tab.')
        if not credentials.refresh_token:
            raise ValueError('Offline sending authorization was not granted')
        values = {'GMAIL_SENDER': sender, 'GMAIL_CLIENT_ID': credentials.client_id,
                  'GMAIL_CLIENT_SECRET': credentials.client_secret,
                  'GMAIL_REFRESH_TOKEN': credentials.refresh_token}
        temporary = folder / '.gmail-sender.pending'
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(fd, 'w') as file:
                json.dump(values, file)
            os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
        print('Gmail send-only authorization saved privately in backend/.secrets/gmail-sender.json.')
        print('No token or client secret was printed. No email was sent.')
    except KeyboardInterrupt:
        raise SystemExit('Authorization cancelled; no configuration was deployed.') from None
    except Exception:
        raise SystemExit('Gmail authorization failed. Check the Desktop OAuth file, enabled Gmail API and consent/test-user settings. Private details withheld.') from None


if __name__ == '__main__':
    main()
