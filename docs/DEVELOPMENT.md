# HERVOICE — local development and code guide

Consolidated 10 November 2026. This is the developer reference for laptop
startup, Android Studio, debugging, code responsibilities and regression checks.
Independent hosting belongs in [Deployment](DEPLOYMENT.md), not this workflow.

Pinned toolchain: Flutter 3.47.7 / Dart 3.13.5 (`flutter_app/.flutter-version`);
dependencies are locked in `pubspec.lock`. Python 3.12 is the container/CI baseline.
Use the existing virtual environment and local state rather than replacing them.

## Contents

- [Local startup](#1-start-the-local-prototype)
- [Android Studio connection](#2-connect-android-studio)
- [Separate local dependencies](#3-optional-separate-local-database-and-storage)
- [Automated checks](#automated-checks)
- [Flutter responsibilities](#flutter-responsibilities)
- [Submission lifecycle](#submission-lifecycle)
- [Existing database adoption](#existing-databases)

The prototype runner replaces both database URLs, JWT and evidence settings with its own `backend/.prototype/` setup. Start Uvicorn directly when intentionally using separately configured dependencies.

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

## Automated checks

```bash
cd backend
.venv/bin/python -m pytest -q
cd ../flutter_app
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --dart-define=HERVOICE_DEMO=true
flutter build apk --debug --no-pub --dart-define=HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1
```

The ordinary Flutter suite skips the real-server test unless configured. With the local fictional-data API running, execute it explicitly (replace the password with your seeded test password):

```bash
flutter test --no-pub test/live_api_test.dart \
  --dart-define=HERVOICE_TEST_API=http://127.0.0.1:8000/api/v1 \
  --dart-define=HERVOICE_TEST_PASSWORD=your-fictional-test-password
```

That test creates a fictional report with a file, verifies officer retrieval of the same bytes, changes status, checks dated history, reads notifications and verifies recovery after reauthentication. It is not a physical-device UI test.

Android build environment on this machine: `JAVA_HOME=/home/emmaa/Apps/android-studio/jbr`, `ANDROID_HOME=/home/emmaa/Android/Sdk`. An Android SDK is installed; the TECNO CK6 was connected and updated in the latest UI pass; this does not complete the manual acceptance matrix. Verify keyboard/Back behaviour, app backgrounding, process death, large text, TalkBack and actual device connectivity before accepting the Android journey.

## Neon-linked database settings

The private Neon connection file is `backend/.env.local`. The API reads
`.env` followed by `.env.local`; process environment overrides both.
`DATABASE_URL` is pooled app traffic, while `DATABASE_URL_UNPOOLED` is the
direct Alembic connection. Standard Postgres URLs are converted to the installed
SQLAlchemy psycopg 3 driver without putting credentials in source.

Run `neon deploy` from `backend/` to apply the reviewed `neon.ts` policy and
refresh private settings. It is not the FastAPI deployment or an Alembic upgrade.
Do not print connection-string commands or private dotenv contents into shared logs.

Tests and the local prototype runner explicitly override both database URLs;
the runner continues using `.prototype/`, even with Neon linked. To intentionally
use Neon, configure the remaining backend settings, test/review the migration plan,
and start Uvicorn directly using the selected environment. See
[Deployment](DEPLOYMENT.md#neon-connection-setup-in-this-checkout).
No local accounts or reports are automatically transferred.

## Backend and admin test notes

From `backend/`, run `.venv/bin/python -m pytest -q` and
`node --test tests/admin/*.test.cjs`. Install `requirements-dev.txt` first.
Backend tests start an isolated temporary PostgreSQL cluster and apply migrations;
they do not use the personal `.env` database. The test environment must permit
local processes and sockets. Neither mocked admin tests nor widget renders
certify provider delivery, real-browser focus or TalkBack.

## Optional fictional design preview

Connected mode is the default. Use `HERVOICE_DEMO=true` only for disconnected
fictional UI exploration: no API calls, no real sign-in, and session-only drafts.
From `flutter_app/`:

```bash
flutter run --dart-define=HERVOICE_DEMO=true -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

The browser target is a design aid; the student deployment target is Android.
Fonts Lora and Manrope are bundled under the licences in `flutter_app/assets/fonts/`.

## Flutter responsibilities

- `report_models.dart`: drafts, attachment metadata, case display models, update models and date formatting. No data fixtures or network calls.
- `report_store.dart`: the screen-facing contract and ordinary in-memory editing. It starts empty. Production screens import this contract.
- `demo_store.dart`: fictional records and simulated submission only. Explicit preview selection constructs this store; it re-exports the contract for compatibility with existing preview tests.
- `connected_store.dart`: authenticated screen coordination, account generation/version guards, draft recovery, and the explicit submission lifecycle. It remains the coordinator; it is not an independent service locator or a replacement state framework.
- `draft_save_queue.dart`: serial, scope-aware encrypted metadata writes. A busy writer keeps the active write unchanged and coalesces consecutive queued snapshots for the same scope. A different scope is never merged. Waiters finish only when their snapshot or a newer one in that scope is saved; failure is propagated and subsequent writes can recover.
- `draft_vault.dart` and `encrypted_draft_vault.dart`: storage interface and Android AES-GCM implementation. File bytes are separate from metadata, keys come from platform secure storage and temporary writes are atomically renamed.
- `submission_intent.dart`: the deep-copied request body and stable server ID. This is a recovery record, not an automatic background job.
- `report_mapper.dart`: API detail to presentation conversion, without I/O.
- `api_client.dart`: HTTP/auth headers, error translation and paged list loading. It does not choose which account may see a case.
- `push_service.dart`: Android permission/provider interaction. The coordinator registers/revokes tokens against authenticated API access.

This is a bounded refactor, not a claim that every responsibility is fully extracted. Authentication and notification coordination remain in ConnectedStore because their generation guards protect pending account operations. Further extraction should have a concrete testable benefit rather than just moving methods between files.

## Draft lifecycle and write efficiency

A field edit produces a metadata snapshot bound to API URL plus account ID. Existing snapshots are never rebound to whichever account is active later. The queue writes one snapshot at a time; edits waiting behind a busy write replace the last queued same-scope snapshot. There is no timer delay. Explicit Save, sign-out UI and every submission checkpoint still await storage. Metadata snapshots are still encoded per edit; device CPU and latency need physical profiling before claiming broad performance gains.

Deterministic test: 200 edits plus an explicit final flush while the first write is blocked produce two writes, revisions 0 and 200, rather than 201 writes. The flush remains unresolved until the final revision is persisted. This is a controlled workload proving reduced redundant I/O, not a benchmark of Android storage speed or power use. Account-boundary and write-failure tests establish that coalescing does not combine accounts or falsely complete a failed save.

## Submission lifecycle

1. Validate sign-in, selected draft and required fields.
2. Freeze payload and a random operation key. Save this intent before any API side effect.
3. Create a private server draft. If the response is lost, retry the same payload and key. Persist the returned server ID before proceeding.
4. Read each encrypted attachment and upload with stable file ID, expected checksum and metadata. Server verifies owner, state, byte limit, type signature and storage read-back under the existing safeguards. A retry does not overwrite different evidence.
5. Explicitly submit the server draft. Then retrieve the confirmed case, save local completion and remove encrypted local copies where possible.
6. On failure, keep the frozen operation and offer explicit retry. No automatic submission occurs merely because a network returns.

Account generations prevent late asynchronous results from populating a later account's screen. Invalid tokens clear authentication while retaining recoverable drafts for the same account. A new login waits for outstanding writes before loading another account. API URL/account-ID changes select a different storage scope: agree and test a migration/recovery process before switching hosted endpoints. Device uninstall or lost key can make local drafts unrecoverable.

## Case loading and limits

`/cases/mine`, `/officer/cases` and `/officer/pattern-alerts` accept limit 1 to 100 and non-negative offset; default is 100. Ordering adds a unique ID tie-breaker. All queries preserve their previous role/owner and draft exclusions. Flutter follows pages to retain the current screen experience. The officer website now uses bounded page envelopes and separate summary counts; see the API reference. Flutter overlaps at most four case-detail requests per batch instead of waiting for each one serially.

Limitations: the client still holds all loaded records; details are still one request per case; notification list/read-all remain unpaged. Offset pages are an eventually consistent view, not a frozen snapshot. A concurrent status change can move an item between pages; refresh again rather than interpreting a queue export as complete analytical evidence. Cursor pagination and lazy detail loading remain future capacity work if real volumes justify them.

## Backend access and transaction boundaries

Student endpoints check account ownership. Officer endpoints currently allow officer/admin roles broadly; assignment-scoped access is awaiting approved requirements. Identity release is admin-only and follows successful audit commit. Status changes lock the report, validate expected/current status and allowed transition, then create notification/outbox work in the transaction. Administrative status meanings and actions have not been changed.

Evidence upload buffers a bounded file and reads storage back while the report lock is held. This protects existing verification/idempotency but can increase lock time under slow storage. Runtime concurrency is capped in the container, storage calls have bounded timeouts, database connect/statement timeouts are explicit and S3 clients are reused. Aggregate memory, object-store throughput and high-concurrency acceptance still require measurement; streaming/quarantine is not silently introduced here.

Push delivery holds a row lock through the provider call; multiple API processes would each start a lifespan worker when enabled. Provider acceptance and DB commit cannot be one atomic transaction. Current retry logic therefore does not establish exactly-once phone delivery. Keep a single API process for the supplied starting deployment and review worker separation before scaling.

## Verification and operation

Backend tests run against an isolated temporary PostgreSQL cluster, never the personal prototype. Flutter tests cover encrypted restore, tampering, account switching, submission retries and the save queue. New loading tests verify bounded overlap and page traversal. Node tests exercise modal cancellation and confirmation against a stubbed browser surface, without modifying cases. They do not replace a real browser/accessibility acceptance pass.

Run backend checks from `backend`: `.venv/bin/python -m pytest -q`; run admin checks with `node --test tests/admin/*.test.cjs`. Run Flutter checks from `flutter_app`: `flutter analyze` and `flutter test`. The optional live API test requires a separate fictional-data API and credentials; do not point it at real records. CI builds the image in addition to tests. Container execution and hosted integrations require their own acceptance; see [Deployment](DEPLOYMENT.md).


## Session and stale-result protection

A failed sign-in from a previous account generation cannot clear the token of a newer session. Generation checks also stop old refresh and submission operations before issuing subsequent requests using a newer account's credentials. The admin HTTP helper rejects responses from an earlier session both after fetch and after asynchronous body parsing. These are client lifecycle protections; API ownership and role checks remain authoritative.

Paged loading rejects an identical repeated full page, preventing an older or misconfigured server that ignores offset from causing an endless loop. Offset pagination still does not provide a frozen snapshot during concurrent changes. Readiness now verifies the installed Alembic revision against the bundled migration heads as well as checking dependency access; merely accepting a PostgreSQL connection is insufficient.

## Existing databases

Migration `0003` adds device registration and the durable Android push queue; configure it using [push configuration](DEPLOYMENT.md#android-push-configuration). Migration `0001` captures the original prototype schema; `0002` introduces account-scoped retry keys, request fingerprints, submission timestamps, and unverified evidence state. Migration `0004` adds email challenges, auth throttles and token versions. On an empty database, run `alembic upgrade head`.

If the old `create_dev_database.py` has already created tables, back up the database and compare it with revision `0001` before running `alembic stamp 0001`, then `alembic upgrade head`. Stamping is only appropriate for that exact baseline; it must not be used to conceal unknown schema differences. Do not run database adoption as part of an ordinary app restart.

Legacy submitted cases keep their creation timestamp as the best available submission time. Legacy evidence is marked reserved and its metadata timestamp cleared because no upload was ever verified. Downloads remain blocked until a future revalidation flow exists. Downgrading `0002` refuses if different accounts share an idempotency key, because the original schema cannot represent that state; its legacy evidence timestamp reconstruction must not be treated as upload proof.



Detailed endpoints: [API reference](reference/API_CONTRACT.md); generated schema: [OpenAPI](openapi.json).
