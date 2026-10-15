# Run and verify the consolidated prototype

The supported implementation is `flutter_app/` with `backend/` (FastAPI). Use fictional incident details. The first connected milestone supports authenticated reporting without attachments, current case status, officer review and in-app notifications. Drafts and authentication are memory-only; submitted reports persist in PostgreSQL.

## 1. Start the local API

From the repository root:

```bash
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m scripts.run_prototype
```

The runner prompts for a fictional demo password of at least 12 characters, creates a local PostgreSQL cluster in ignored `backend/.prototype/`, applies Alembic migrations and creates missing accounts. It never resets existing passwords. `HERVOICE_DEMO_PASSWORD` can supply the password instead of the prompt. Reuse the original password on later runs.

Accounts: `student@example.test`, `officer@example.test`, `admin@example.test`.

API docs: <http://127.0.0.1:8000/docs>. Officer dashboard: <http://127.0.0.1:8000/admin/>. The runner binds only to loopback. Evidence storage is not started because connected uploads are disabled. For the Docker/PostgreSQL/MinIO setup, see [backend setup](../backend/README.md).

On this workspace the existing Python environment is `/home/emmaa/Work/Her-voice/backend/.venv/bin/python`. It can run the script and tests from the backend directory. Do not point test commands at a real institutional database: the test suite provisions an isolated temporary PostgreSQL cluster.

## 2. Run Flutter

Flutter SDK on this workspace: `/home/emmaa/Work/.toolchains/flutter/bin/flutter`. Substitute this absolute executable for `flutter` below if it is not on PATH.

```bash
cd flutter_app
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

Visit <http://127.0.0.1:8765>. The browser client defaults to `http://127.0.0.1:8000/api/v1`. CORS permits only `http://127.0.0.1:8765` and `http://localhost:8765` by default. Additional development origins can be supplied as a JSON array in `CORS_ORIGINS`.

Android emulator:

```bash
flutter run -d <emulator-id>
```

The Android client defaults to `http://10.0.2.2:8000/api/v1`. Debug builds permit local HTTP; release use requires HTTPS.

USB-connected Android device, using port reversal without exposing the server to the LAN:

```bash
adb reverse tcp:8000 tcp:8000
flutter run -d <device-id> --dart-define=HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

For a different server use `--dart-define=HERVOICE_API_BASE_URL=https://your-server.example/api/v1`. No API keys or account passwords are compiled into the app.

The earlier fictional, disconnected design preview remains available explicitly:

```bash
flutter run --dart-define=HERVOICE_DEMO=true
```

## 3. Walk through the first prototype

1. Sign in to Flutter with `student@example.test` and the password you seeded.
2. Choose Document an incident. Enter fictional narrative, subject and a date/time.
3. Continue past the attachment-unavailable explanation. Review the access explanation, acknowledge submission and choose Submit report.
4. Verify the server confirmation and case in My records. A failed request keeps the original submission for retry within the same session; it does not create a replacement request automatically.
5. Open the officer dashboard in a browser and sign in with `officer@example.test`. Select the same case and change Submitted to Received, then Under review if desired.
6. In Flutter select Refresh. Check the case status and Updates, then mark the notification read.
7. Sign out and sign back in. Submitted cases reload from PostgreSQL. Unsubmitted local drafts are intentionally cleared on sign-out or process restart.

Do not describe this as anonymous reporting, an evidence vault or offline synchronisation. The original requirements and remaining work are mapped in [consolidation review](CONSOLIDATION_REVIEW.md).

## 4. Repeat the automated checks

```bash
cd backend
.venv/bin/python -m pytest -q
cd ../flutter_app
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
flutter build apk --debug --no-pub
```

The ordinary Flutter suite skips the real-server test unless configured. With the local fictional-data API running, execute it explicitly (replace the password with your seeded test password):

```bash
flutter test --no-pub test/live_api_test.dart \
  --dart-define=HERVOICE_TEST_API=http://127.0.0.1:8000/api/v1 \
  --dart-define=HERVOICE_TEST_PASSWORD=your-fictional-test-password
```

That test creates a fictional report, changes its status through the officer API, reads a notification and verifies case recovery after reauthentication. It is not a physical-device UI test.

Android build environment on this machine: `JAVA_HOME=/home/emmaa/Apps/android-studio/jbr`, `ANDROID_HOME=/home/emmaa/Android/Sdk`. An Android SDK is installed; no device was attached during this review. Verify keyboard/Back behaviour, app backgrounding, process death, large text, TalkBack and actual device connectivity before accepting the Android journey.
