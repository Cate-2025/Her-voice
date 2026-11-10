> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Local testing reference

Updated 6 November 2026. For independent hosting, start with [Deployment](DEPLOYMENT.md). This file is only for laptop testing; you do not need to complete its optional service rehearsal before using a managed host. Use fictional data.

The prototype runner replaces database, JWT and evidence settings with its own `backend/.prototype/` setup. Start Uvicorn directly when intentionally using separately configured dependencies.

## 1. Start the local prototype

Use an existing environment rather than replacing it. On this workspace:

```bash
cd /home/emmaa/Work/Her-voice/backend
.venv/bin/python -m pip install -r requirements-dev.txt
EMAIL_DELIVERY=file .venv/bin/python -m scripts.run_prototype
```

On a fresh checkout without `.venv`, create it first with `python3 -m venv .venv`. Python 3.12 is the container/CI baseline. The installed local environment has also been used for application tests.

Enter the existing fictional demo password when prompted. The runner creates missing demo users but **does not reset existing passwords**. It applies migrations to its own persistent database. Do not run a second API on port 8000 if one is already running; stop the old process from its owning terminal before switching startup paths.

Open:

- API liveness: `http://127.0.0.1:8000/health`
- Dependency/schema readiness: `http://127.0.0.1:8000/ready`
- Officer/admin portal: `http://127.0.0.1:8000/admin/`
- Development API documentation: `http://127.0.0.1:8000/docs`

The demo accounts are `student@example.test`, `officer@example.test`, and `admin@example.test`. For Create account/Forgot password in file-mail mode, read the newest `.eml` in `backend/.prototype/mail/` locally. These messages are not delivered to an inbox. Keep the directory private.

The process runs in the foreground and is not an independently hosted service. Closing it or sleeping the laptop stops availability. Stop with Ctrl+C; retain `.prototype/` if you want its records on the next run.

## 2. Connect Android Studio

For the physical phone using wireless debugging, connect/pair through Android Studio first. Then:

```bash
/home/emmaa/Android/Sdk/platform-tools/adb devices -l
# If several devices are listed, add -s DEVICE_SERIAL to each reverse command.
/home/emmaa/Android/Sdk/platform-tools/adb reverse tcp:8000 tcp:8000
/home/emmaa/Android/Sdk/platform-tools/adb reverse --list
```

Keep the Android Studio Flutter run argument:

```text
--dart-define=HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Restart the app after changing build arguments. Reapply port reversal after wireless reconnection. The phone's `127.0.0.1` reaches the computer only because of this reverse mapping. A stock Android emulator uses `http://10.0.2.2:8000/api/v1` instead. Debug builds allow local HTTP; release builds require HTTPS.

The existing desktop APK predates the latest corrections. Build a fresh debug APK for this local address from `flutter_app/`:

```bash
/home/emmaa/Work/.toolchains/flutter/bin/flutter build apk --debug \
  --dart-define=HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Output: `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`. Keep the same installation/signing identity when testing draft recovery. Uninstalling, changing account or changing API URL is not an equivalent recovery test; drafts are scoped to account and API URL.

## 3. Optional: separate local database and storage

This path uses a **separate, empty local database**, not the prototype database. It tests the storage protocol but not production TLS or real mail delivery. Docker access must already work for the operator; permission denied on its socket is a host access issue, not an application error.

The repository's older `backend/docker-compose.yml` publishes dependency ports on all interfaces and uses illustrative credentials. For this rehearsal, create `backend/.prototype/services.yaml` with the loopback-only example below. Do not merge it with the old Compose file.

```yaml
name: hervoice-local-services
services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: hervoice
      POSTGRES_USER: hervoice
      POSTGRES_PASSWORD: ${LOCAL_DB_PASSWORD:?Set LOCAL_DB_PASSWORD}
    ports: ["127.0.0.1:55432:5432"]
    volumes: [pg_data:/var/lib/postgresql/data]
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${OBJECT_STORAGE_ACCESS_KEY:?Set storage key}
      MINIO_ROOT_PASSWORD: ${OBJECT_STORAGE_SECRET_KEY:?Set storage secret}
    ports: ["127.0.0.1:59000:9000", "127.0.0.1:59001:9001"]
    volumes: [object_data:/data]
volumes:
  pg_data:
  object_data:
```

The MinIO image follows the existing repository's development dependency choice. This sample has not been pulled/run here; confirm availability and pin the successfully tested image digest for repeatable rehearsals. Its root credentials are for this isolated fictional-data fixture only. Hosted storage uses a restricted service identity instead.

From `backend/`, create `.prototype/` if absent. If `.env` already exists, preserve it and edit deliberately; do not overwrite it with an example. Otherwise copy `.env.example` to `.env`, then `chmod 600 .env`. Configure these values locally:

```dotenv
APP_ENV=development
LOCAL_DB_PASSWORD=GENERATED_HEX_PASSWORD
DATABASE_URL=postgresql+psycopg://hervoice:GENERATED_HEX_PASSWORD@127.0.0.1:55432/hervoice
JWT_SECRET=GENERATED_RANDOM_SECRET
EVIDENCE_STORAGE=s3
OBJECT_STORAGE_ENDPOINT=http://127.0.0.1:59000
OBJECT_STORAGE_ACCESS_KEY=LOCAL_STORAGE_LOGIN
OBJECT_STORAGE_SECRET_KEY=GENERATED_STORAGE_SECRET
OBJECT_STORAGE_BUCKET=hervoice-evidence
MAX_EVIDENCE_BYTES=10485760
EMAIL_DELIVERY=file
EMAIL_PREVIEW_PATH=.prototype/service-mail
PUSH_ENABLED=false
CORS_ORIGINS=["http://127.0.0.1:8765","http://localhost:8765"]
```

Replace all uppercase sample values. Generate separate random values with a password manager or `python3 -c 'import secrets; print(secrets.token_hex(32))'` in a private terminal. Use the same database password in both settings. Hex avoids URL-escaping problems. Quote values containing special characters appropriately in dotenv files. Process environment variables override `.env`; remove stale exported settings before switching environments. Do not `source .env` as shell code.

```bash
cd /home/emmaa/Work/Her-voice/backend
docker compose --env-file .env -f .prototype/services.yaml config -q
docker compose --env-file .env -f .prototype/services.yaml up -d
docker compose --env-file .env -f .prototype/services.yaml exec postgres pg_isready -U hervoice -d hervoice
```

Wait for PostgreSQL to accept connections. Changing `POSTGRES_PASSWORD` later does not reset the password in an already initialised database volume.

Open `http://127.0.0.1:59001`, log in with the local storage credentials, create the private bucket `hervoice-evidence`, and leave anonymous/public access disabled. The application does not create the bucket. Then:

```bash
.venv/bin/python -m alembic upgrade head
# Fictional accounts only, in this separate development database:
.venv/bin/python -m scripts.seed_demo_users
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Use section 1's URLs and section 2's phone connection. `/ready` should now verify the separate database and bucket. Submit a fictional report with a supported harmless file; retrieve it through the authorised portal and compare the downloaded bytes/hash to the original. HeadBucket readiness alone does not prove object writes work.

Stop Uvicorn with Ctrl+C. Stop dependencies with `docker compose --env-file .env -f .prototype/services.yaml stop`. Named volumes retain data. Do not use `down -v` as a routine restart command: it deletes these volumes.

To test real external services from the laptop instead, replace the database/storage settings with provider endpoints and credentials, use certificate-verified database TLS, and configure SMTP using the deployment guide. Continue starting Uvicorn directly. A provider database CA path must refer to the laptop file for host-run Python, not a container path. Do not copy the local fixture's root-storage privileges to a hosted service.

## 4. Optional: automated checks

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

That test creates a fictional report with a file, verifies officer retrieval of the same bytes, changes status, checks dated history, reads notifications and verifies recovery after reauthentication. It is not a physical-device UI test.

Android build environment on this machine: `JAVA_HOME=/home/emmaa/Apps/android-studio/jbr`, `ANDROID_HOME=/home/emmaa/Android/Sdk`. An Android SDK is installed; no device was attached during this review. Verify keyboard/Back behaviour, app backgrounding, process death, large text, TalkBack and actual device connectivity before accepting the Android journey.
