# Deploy HERVOICE — start here

Consolidated 10 November 2026. **This is the single deployment walkthrough.** Follow steps 0–7 in order; use the appendices for integration details and operation. Each step says what you need, what to do and what working looks like. The current repository contains deployment groundwork; cloud deployment has not been established or certified by these documentation passes.

Use fictional records for the demo. You do not need to read the progress reports or historical plans to follow this guide.

## Contents

- [Deployment sequence](#at-a-glance): choose hosting, provision services, deploy API, verify, build Android.
- [Email delivery details](#email-delivery-details)
- [Android push configuration](#android-push-configuration)
- [Android signing](#android-signing)
- [Operations and recovery](#operations-and-recovery)

For laptop/Android Studio work, use [Development](DEVELOPMENT.md).
Record launch evidence in [Release checklist](RELEASE_CHECKLIST.md).

## At a glance

| Deploy/configure | What it provides | What you should expect afterwards |
| --- | --- | --- |
| PostgreSQL | Accounts, report records, statuses, notifications, audit history | An initially empty database; tables appear after migrations. No website yet. |
| Private object bucket | Uploaded evidence bytes | A private storage endpoint for the API. Students never need a bucket login. |
| Email provider | Registration/reset codes | Real inbox delivery after sender and API configuration. |
| API application | Reporting, permissions and the admin website | One HTTPS host: `/api/v1` for the app and `/admin/` for staff. |
| Firebase, optional initially | Android system notifications | New generic notices after project setup, app rebuild and device opt-in. |
| Android APK | Student interface | Installed app connects to that HTTPS API without Android Studio or adb. |

**The Dockerfile packages the API and admin website. It does not create the database, bucket, mail account or APK.** A successful API build is only one step.

## Current deployment status — Render and Neon

The backend is published on GitHub branch `deploy/render-free-20261110`.
Local `main` and its uncommitted app work were not switched or reset.
The release was checked with 76 isolated backend regression tests.

Render workspace: Omusheshe's workspace. API-based creation of a Frankfurt
Free Docker web service returned HTTP 402 requiring payment information;
no Render service was created by that request. The owner declined adding payment
information and is checking the Dashboard Free flow. Do not retry API creation or
choose a paid plan without new instructions.

Dashboard settings: repo `Cate-2025/Her-voice`, branch above, runtime Docker,
Dockerfile `backend/Dockerfile`, build context `backend`, root directory blank,
command `python -m scripts.run_render`, Frankfurt, Free. Once created, privately
supply both Neon database URLs, a stable generated JWT secret, storage credentials,
actual HTTPS CORS origin, `APP_ENV=staging`, `EMAIL_DELIVERY=disabled`, and
`PUSH_ENABLED=false`. Never copy these secret values into Git or chat.

Staging now permits deliberately disabled mail while continuing to reject local
file delivery; production still requires configured mail. Registration/reset
cannot deliver codes until mail is configured. No mail provider was configured.
The Render startup binds `PORT` without migrations or demo seeding and does not
trust arbitrary forwarded headers. Until reviewed proxy trust is configured,
source-address throttles can group requests behind the platform proxy.

Neon private bucket `hervoice-evidence` was provisioned in the existing Frankfurt
project. HeadBucket and synthetic write/read/delete succeeded. S3 uses SigV4,
path-style addressing and the Neon region. AWS-standard variables in private
`backend/.env.local` are accepted by the backend, without rewriting secrets into
source. Readiness still checks database/schema and bucket access; a built container
alone is not acceptance. Render filesystem storage is not used for evidence.

## 0. Choose one route

| Route | What to use | Status in this repository |
| --- | --- | --- |
| Laptop only | Prototype runner and adb reverse | Use [local development](DEVELOPMENT.md). This still depends on the laptop. Stop reading the hosted steps if that is all you need today. |
| Managed host | Container web service + PostgreSQL + bucket + mail | Follow the numbered stages below, using the platform's settings. Host-specific port/proxy/startup integration must be prepared; the VM commands are not managed-host instructions. |
| Your own VM | Linux/Docker host + supplied Compose/Caddy + database + bucket + mail | Concrete commands are included below. Database/storage/mail are provisioned separately. |

The previously discussed free managed stack was Render/Neon/R2; an alternative was Oracle's free VM route. Prices, availability and current quotas must be checked when signing up. No provider has been selected/configured by this guide.

**Free-host checkpoint:** check sleep/wake delays, outbound mail restrictions and database compute quotas before choosing. Current app requests time out after 20 seconds; push polls the database every five seconds when enabled; the supplied VM health check queries readiness every 30 seconds. Those behaviours require review for sleeping/free services. The backend currently supports SMTP mail, not an HTTPS email-provider API. A provider that requires an email API needs an implementation change first.

**Expected result:** you have one chosen route and know whether its limitations require code/configuration changes. Do not buy several hosts or deploy both routes.

## 1. Create the database

**You need:** PostgreSQL host/port, database name, user/password, provider TLS instructions and CA certificate if required.

**Do:** create a separate demo database, obtain its connection details, and restrict access to the intended API operator/network where the service allows it. For remote connections use certificate-verified TLS (`sslmode=verify-full`). The API needs permission to run its migrations in the application schema.

**Save for step 4:** the SQLAlchemy URL starts `postgresql+psycopg://`. URL-encode special characters in the username/password. A provider CA path must point to a file readable inside the API and migration runtime, not just on your laptop.

**Expected result:** database service is available and connection details are ready. It is normal for it to have no application tables yet. Existing local users, passwords and reports do not automatically move to this database.

### Neon connection setup in this checkout

Linked on 10 November 2026 to the requested Neon project and `production`
branch, for Postgres only. Run Neon tooling from `backend/`. The CLI link is
private `backend/.neon`; its declarative policy is `backend/neon.ts`.
The npm dependencies there support Neon configuration, not the Python API runtime.

`neon deploy` refreshed `backend/.env.local` with pooled `DATABASE_URL`
and direct `DATABASE_URL_UNPOOLED`. Both were verified using read-only
connections. The policy plan/apply reported no branch service changes.
The initial connection check found an outdated/uninitialised application schema.
The subsequent migration pass tested all existing Alembic migrations on an isolated
24-hour branch, then applied them transactionally to production. Both branches
were verified against the bundled migration heads and application table metadata.
No users were seeded and no existing records were transferred. The integration
regression run passed 75 backend tests on isolated temporary PostgreSQL, including
environment precedence, timeout isolation and local-runner migration protection.

The backend reads `.env`, then `.env.local`, with process environment taking
precedence over both. Ordinary Postgres URLs select the installed psycopg 3 driver
in code; passwords and TLS query parameters are preserved. App traffic uses the
pooled URL; Alembic uses the direct URL when supplied. Timeouts are transaction-local
so they work through transaction pooling. Database credentials never belong in
Flutter, Android Studio build arguments or browser JavaScript.

The production schema is now prepared. Before starting the hosted service,
provide the remaining JWT, storage and email settings and bootstrap the initial
administrator. Future migrations must still be tested on an isolated branch first. The prototype runner and
automated tests explicitly pin **both** URLs to their own local databases. They do
not switch to Neon just because the private file exists.

To create the initial Neon administrator now, before storage/mail hosting is
configured, run these commands in your own terminal:

```bash
cd /home/emmaa/Work/Her-voice/backend
.venv/bin/python -m scripts.create_initial_admin
```

This database-only launcher checks schema/current administrator presence, then
uses the existing private email/password prompts. Passwords are hashed by the
existing bootstrap logic. It supplies unrelated import-time settings only in its
own short-lived process; no API server starts and no hosting secrets are saved.
Use `--check` to perform only the read-only preflight. Do not share passwords in chat.

Keep `.env.local` out of Git and container images (mode 600 locally). For hosted
operation, privately configure both URL variables in the host's secret settings or
protected deployment dotenv; the local file is not copied by the Dockerfile.

## 2. Create private evidence storage

**You need:** an S3-compatible HTTPS endpoint, private bucket, service access key/secret and any required signing region.

**Do:** create the bucket and keep public access disabled. Give the API permission to write/read its `reports/*` objects and perform bucket readiness checks. On AWS S3, HeadBucket requires the appropriate bucket `ListBucket` permission; other providers have their own access controls. Configure provider encryption/versioning and backup arrangements.

**Expected result:** a private bucket and API credentials exist. It is normal that no evidence appears before an actual report upload. The API does not create the bucket. Files must survive replacement/restart of the API container.

## 3. Configure email

**You need:** SMTP host/port, TLS mode, sender and credentials (or an approved restricted relay).

**Do:** verify the sender with the provider, including required DNS records. Confirm the API host permits that outbound connection. Use `starttls` or `ssl` as the provider specifies; never work around a port restriction by disabling TLS.

**Expected result:** the provider account/sender is ready. Real verification/reset delivery is tested after API deployment in step 5. Production requires configured mail. Staging may explicitly use `EMAIL_DELIVERY=disabled` while demonstrating existing accounts; registration/reset cannot deliver codes in that state. Local file mail is development-only.

**Details:** [email details](#email-delivery-details) explains code expiry, reset behaviour and mail limitations.

## 4. Deploy the API and included admin website

### 4a. Supply configuration

Source files: `backend/Dockerfile` and `backend/app/`. Set these in the managed host's secret/environment settings, or in protected `backend/deploy/.env` on the VM:

| Setting | Value / purpose |
| --- | --- |
| `APP_ENV` | `staging` for this demo deployment |
| `DATABASE_URL` | Pooled PostgreSQL URL from step 1, with verified TLS |
| `DATABASE_URL_UNPOOLED` | Direct connection for migrations when using a pooled URL; optional for non-pooled setups |
| `JWT_SECRET` | Privately generated random secret, at least 32 characters; keep stable across ordinary restarts |
| `CORS_ORIGINS` | JSON array containing the actual HTTPS browser origin, without a trailing slash, e.g. `["https://YOUR_HOST"]` |
| `EVIDENCE_STORAGE` | `s3` |
| `OBJECT_STORAGE_ENDPOINT` | HTTPS S3 API endpoint from step 2 |
| `OBJECT_STORAGE_ACCESS_KEY`, `OBJECT_STORAGE_SECRET_KEY` | Private service credentials |
| `OBJECT_STORAGE_BUCKET` | Existing bucket name |
| `AWS_DEFAULT_REGION` | Provider signing region if required; supply in process/container environment |
| `MAX_EVIDENCE_BYTES` | `10485760` (10 MiB per file) |
| `EMAIL_DELIVERY` | `smtp` |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURITY` | Mail endpoint; typically `587`/`starttls` or `465`/`ssl`, subject to provider/host support |
| `SMTP_FROM`, `SMTP_USER`, `SMTP_PASSWORD` | Verified sender and service credentials |
| `PUSH_ENABLED` | `false` until step 6 |

Templates: `backend/.env.example` for host-run Python; `backend/deploy/.env.example` for VM Compose. Templates are not usable credentials. Hosted validation rejects placeholders, local evidence, file mail and HTTP storage/browser origins. Production also rejects disabled mail; staging can deliberately defer it. Keep `APP_ENV=staging` and fix the failing setting rather than bypassing validation.

Keep secrets outside Git/image contents. Quote dotenv values safely; do not execute a dotenv file with `source`. Process environment settings take precedence over the Python `.env`. Rotating the JWT secret invalidates existing sign-ins and outstanding email codes.

### 4b. Managed host route

Use this checklist in the chosen host's deployment settings; exact commands depend on the provider and need verification there:

1. Use `backend/` as the Docker build context, with its `Dockerfile`.
2. Set the environment above; supply database CA/optional credentials through supported secret files or service identity.
3. Configure the listening port and trusted proxy address for that host. The supplied Docker command listens on 8000 and trusts only VM proxy `172.29.88.2`; that trust setting is not automatically correct on a managed host. Do not copy it blindly or expose unrestricted forwarded-header trust.
4. Build the image, then run `python -m alembic upgrade head` once against the demo database, using the same release/configuration. Use the provider's supported release/one-off mechanism or a separately configured operator process if the plan has no shell/job facility.
5. Run `python -m scripts.bootstrap_admin` through an interactive, configured operator process. It prompts privately for the first administrator and refuses existing administrators/conflicting users. It is not a password-reset/staff-management command.
6. Start one API process. Use the platform HTTPS endpoint; Caddy/VM Compose is not needed on that platform. Configure liveness and dependency checks deliberately for its lifecycle and any free database quota.

**Expected result:** image builds, migrations finish successfully, the initial administrator is created, and the API serves a public HTTPS address. Do not interpret the host's “deploy succeeded” label as evidence that email/files work; continue to step 5.

### 4c. VM route — concrete commands

Assumptions: reviewed checkout at `/srv/hervoice`, working Docker/Compose, real DNS hostname pointing at the VM, inbound TCP 80/443 allowed, and outbound access to your providers. Docker must start after host reboot. Keep database/storage administration private.

From `backend/deploy/`, copy `.env.example` to `.env` **only on first setup**, protect it with `chmod 600 .env`, and enter the step 4a settings. Also set `HERVOICE_HOST` to the real hostname (no scheme/path) and `HERVOICE_IMAGE` to a unique reviewed release tag. The supplied Compose launches API/Caddy, not PostgreSQL or a bucket.

If the database requires a supplied CA bundle, obtain it from the provider and place it at `/srv/hervoice-secrets/postgres-ca.pem`. Ensure the source file exists and is readable by runtime UID 10001. Add this host-specific `compose.override.yaml`:

```yaml
services:
  api:
    volumes:
      - /srv/hervoice-secrets/postgres-ca.pem:/run/certs/postgres-ca.pem:ro
  migrate:
    volumes:
      - /srv/hervoice-secrets/postgres-ca.pem:/run/certs/postgres-ca.pem:ro
```

Use a database URL such as the following with real credentials/host, URL-encoded as necessary:

```text
postgresql+psycopg://USER:PASSWORD@DB_HOST:5432/DB_NAME?sslmode=verify-full&sslrootcert=/run/certs/postgres-ca.pem
```

If your provider uses the runtime's system CA store, follow its verified-TLS instructions instead. In that case omit the CA override and its `-f compose.override.yaml` argument consistently below. Never disable certificate validation just to make a connection succeed.

Run **one command at a time; stop if it fails**:

```bash
cd /srv/hervoice/backend/deploy
# Check 1: valid configuration; quiet success, without printing secrets.
docker compose --env-file .env -f compose.yaml -f compose.override.yaml config --no-env-resolution -q
# Check 2: API image builds; this does not start a working deployment.
docker compose --env-file .env -f compose.yaml -f compose.override.yaml build api
# Check 3: schema upgrade completes successfully.
docker compose --env-file .env -f compose.yaml -f compose.override.yaml run --rm migrate
# Check 4: private prompts create the first administrator.
docker compose --env-file .env -f compose.yaml -f compose.override.yaml run --rm -it --no-deps api python -m scripts.bootstrap_admin
# Check 5: API becomes healthy, then Caddy starts.
docker compose --env-file .env -f compose.yaml -f compose.override.yaml up -d api proxy
docker compose --env-file .env -f compose.yaml -f compose.override.yaml ps
```

The migration service is explicitly invoked; ordinary startup does not rerun migrations. Never use the prototype runner/demo seeder for hosted startup. Do not stamp a database revision to bypass a failed migration; existing non-empty databases need review and backups first.

Caddy manages HTTPS using the hostname/DNS and persistent certificate volumes. The VM network reserves `172.29.88.2` for Caddy; if its subnet conflicts with the host, change Compose and Uvicorn trusted proxy configuration together. Port 8000 is internal; only 80/443 are published by this deployment.

**Expected result:** API shows healthy and proxy is running. The host remains available after your SSH session closes. Changing `.env` requires container recreation with `up -d`; `restart` alone does not reload environment values. A Docker health failure alone does not trigger restart policy; persistent failures need an operator/monitor.

## 5. Prove the API works before building the phone app

Substitute the actual hostname:

```bash
curl --fail --max-time 20 https://YOUR_HOST/health
curl --fail --max-time 20 https://YOUR_HOST/ready
```

| Check | Expected | What it does not prove |
| --- | --- | --- |
| `/health` | HTTP 200, `{"status":"ok"}` | Database, storage, mail or push |
| `/ready` | HTTP 200, `{"status":"ready"}` | Mail, phone delivery or successful object write/read |
| `/admin/` | Login page, then initial administrator can sign in | Local prototype accounts are not automatically present |
| Registration and reset | Real test inbox receives a code and the intended flow succeeds | SMTP acceptance alone is not inbox receipt |
| Fictional report/evidence | Submission succeeds; authorised download matches original bytes; status change appears for its student | Real-data approval, malware scanning or full recovery readiness |

`/ready` checks database connectivity, installed migration revision and bucket access. `503` means a dependency/schema check failed; inspect private logs. `/docs` and OpenAPI are intentionally unavailable in staging/production. Do not open bucket access publicly to fix readiness.

If no student client is yet available for functional checks, build the staging APK in step 7, perform the checks above with it, and return here before marking API acceptance complete.

**Stop point:** a public URL alone is not a completed demo. API, account access and evidence transfers must work together.

## 6. Optional: enable Android push

Follow [Android push configuration](#android-push-configuration) if testing phone notifications now. The project needs Android package `com.hervoice.hervoice`, its `google-services.json` in `flutter_app/android/app/`, and a separate server sending identity from that same Firebase project.

On a VM, protect the server credential outside the repository, make it readable by runtime UID 10001, add `FIREBASE_CREDENTIALS_PATH` to deployment `.env`, then use all applicable overrides:

```bash
docker compose --env-file .env -f compose.yaml -f compose.override.yaml -f compose.push.yaml config --no-env-resolution -q
docker compose --env-file .env -f compose.yaml -f compose.override.yaml -f compose.push.yaml up -d api proxy
```

Omit only the CA override if it was not used in step 4. Keep the same file list for subsequent operations. On a managed host use its credential mechanism and process environment; `GOOGLE_APPLICATION_CREDENTIALS` must reach Firebase's SDK, not just the Python settings file.

**Expected result:** API starts with push enabled; after rebuilding the app and enabling notifications on the phone, a new case-status change produces a generic background notification. There is one worker inside the API, no separate worker command. Provider acceptance is not proof the phone displayed it; test on the phone. Without Firebase, keep push disabled and use in-app Updates.

## 7. Build and distribute the Android app

**You need:** confirmed API HTTPS address and a test phone. The latest desktop APK predates recent fixes.

From `flutter_app/`, first build a staging debug APK:

```bash
flutter build apk --debug --dart-define=HERVOICE_API_BASE_URL=https://YOUR_HOST/api/v1
```

Output: `flutter_app/build/app/outputs/flutter-apk/app-debug.apk`. On this workspace Flutter is `/home/emmaa/Work/.toolchains/flutter/bin/flutter`; JDK is `/home/emmaa/Apps/android-studio/jbr` and Android SDK is `/home/emmaa/Android/Sdk`.

Install on a fictional-data test installation. **Expected result:** sign-in and the report/admin-update journey work over mobile data with adb disconnected and the development laptop off. No reverse-port command is used for this hosted address.

For the distributable signed release, follow [Android signing](#android-signing), then build with the same HTTPS define. Release builds require HTTPS and owner-supplied signing; the project refuses debug-signing fallback. A Play Store listing is not required for a directly shared APK.

Keep signing identity, API URL, version/build and APK checksum recorded. Changing URL/account changes draft scope; changing signing identity can prevent an in-place update. Preserve existing unsent drafts and do not uninstall to bypass an upgrade conflict.

## If a step fails

| Symptom | Start here |
| --- | --- |
| Image built, but API will not start | Validate environment; check credentials/URLs, port and startup logs. |
| `/health` works, `/ready` fails | Database/TLS, migration revision, bucket existence/access. |
| Website loads, sign-in fails | Correct hosted database/account? Local seeding preserves passwords and does not create cloud users. |
| File upload/download fails | Private bucket permissions, endpoint/signing region, file type/10 MiB limit; compare bytes after success. |
| No registration mail | SMTP egress restrictions, sender verification, credentials, provider sandbox/spam folder. |
| Phone cannot connect | Confirm compiled HTTPS address and API reachability; for laptop testing only, see local adb instructions. |
| First request times out after inactivity | Free-host wake-up delay; use the chosen host's tested startup approach. |
| Docker socket permission denied | Authorised host/operator access is needed; changing application files cannot fix OS permissions. |
| HTTPS fails on VM | API readiness, DNS/AAAA reachability, ports 80/443 and Caddy logs. |

For VM logs, use your same Compose file list with `logs --tail=100 api proxy`. Inspect privately and redact secrets/report content before sharing.

## Finish and keep it running

Record results in [release checklist](RELEASE_CHECKLIST.md). Set a demo end date, provider quota checks, operator contact and backups. Before relying on stored records, rehearse a database-plus-evidence restore. Monitoring, recovery and later-release procedures are included in [operations and recovery](#operations-and-recovery).

**Evidence boundary:** this documentation consolidation did not deploy services or rerun application tests. Previously recorded local tests and installation are summarised in [Description](DESCRIPTION.md#verification-and-deployment-position). Container/provider/device acceptance remains to execute. Free-tier offerings are not guaranteed by this guide. Administrative decisions and real-data launch approval remain tracked separately.


## Email delivery details

Registration accepts all email domains, as requested. Successful code verification creates a **student** account. It does not verify university membership or grant staff access. Password recovery uses a separate code purpose, sets a new password, revokes existing JWT sessions and disables that account's registered push devices.

Codes are eight digits, expire after 15 minutes, allow at most five incorrect attempts and are consumed on success. Resending requires a minute's wait. Source-address rate limits also apply. Code hashes, not plaintext codes, are kept in PostgreSQL. Email delivery is disabled by default; never expose verification codes through a public API or logs.

### SMTP configuration

Configure the server environment or ignored backend `.env` with your SMTP provider's values:

```dotenv
EMAIL_DELIVERY=smtp
SMTP_HOST=your-smtp-host
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_FROM=your-verified-sender@example.org
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-provider-secret
```

Use `SMTP_SECURITY=ssl` with the provider's implicit-TLS port when appropriate. Plaintext SMTP is not offered. Restart the backend after changing configuration. Configure/verify the sender with your chosen provider and test both inbox and spam-folder delivery. Do not paste SMTP credentials into chat or commit `.env`.

An email domain allowlist has deliberately not been added. Institution eligibility remains a future policy/integration decision. Staff accounts must still be provisioned by an authorised operator; public registration cannot choose a role.

### Email operation and limits

The server sends mail synchronously with a timeout. Delivery failure returns an actionable unavailable response and does not activate an account. SMTP acceptance is not proof of inbox delivery. Production mail queuing/retries, bounce handling, deliverability monitoring, durable challenge/throttle cleanup and institutional account management remain to be completed.

Rate limits currently use the connection source address and per-email resend interval. A reverse proxy must have a correctly restricted trusted-proxy configuration; an arbitrary forwarded header must never bypass limits. Shared-network users may share a source limit. This is a prototype control, not a replacement for production abuse protection.

Passwords and sign-in tokens are not stored for offline login. A password reset does not delete a user's encrypted local drafts; the same verified account ID can recover them after successful sign-in on the original device.

## Android push configuration

The code is implemented, but live Firebase delivery has **not** been verified: no HERVOICE Firebase project or credentials were available for this pass. Without project configuration the app still builds, sign-in and in-app updates still work, and Updates explains that phone notifications need setup.

### 1. Create and register the Android app

1. Create a project in the [Firebase console](https://console.firebase.google.com/). Google Analytics is not required for this implementation.
2. Add an Android app with the exact package **`com.hervoice.hervoice`**.
3. Download its `google-services.json` to **`flutter_app/android/app/google-services.json`**. This file must come from your project; there is no placeholder to edit.
4. Ensure the Firebase Cloud Messaging API is enabled for the project. Use the same project for the app and sending service account.
5. In Android Studio, open `flutter_app`, fetch dependencies, stop the running app and run it again. Hot reload cannot incorporate native Firebase configuration. The Google services Gradle plugin is already configured and is applied only when the JSON file exists.

The Android configuration identifies the Firebase project; it is different from the private server key. Both project-local paths below are ignored by Git. See [Firebase Android setup](https://firebase.google.com/docs/android/setup).

### 2. Configure the server

Use a service account permitted to send FCM messages in that project. For a local prototype, download its JSON private key through Firebase Project settings → Service accounts. Keep it on the server, for example at `/home/emmaa/Work/Her-voice/backend/.secrets/firebase-admin.json`, with owner-only read permissions. Never put this key in Flutter assets, `google-services.json`, source control, or chat. On hosted infrastructure, prefer a managed service identity instead of a downloaded key. See [Firebase server authentication](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

For hosting, configure the service identity or mount the server key read-only.
Set `PUSH_ENABLED=true`, provide `GOOGLE_APPLICATION_CREDENTIALS` in the
process environment, and recreate/restart the API using the same deployment
configuration. Apply `alembic upgrade head` before startup. There is one
in-process worker polling every five seconds; no separate worker command is needed.

`GOOGLE_APPLICATION_CREDENTIALS` must be exported in the server process environment (or configured as an IDE/service environment variable). Merely putting it in `.env` does not export it to the Firebase SDK. `PUSH_ENABLED` can be set in the environment or backend `.env`; its default is false. Invalid/missing credentials with push explicitly enabled fail server startup instead of pretending push is running.

For a manually managed PostgreSQL setup, apply `.venv/bin/alembic upgrade head` before starting Uvicorn. For Docker, mount the service account file read-only and supply its **container** path through `GOOGLE_APPLICATION_CREDENTIALS`, plus `PUSH_ENABLED=true`. Do not bake the key into an image.

The Android app keeps using the existing HERVOICE login/API. Firebase Authentication, Firestore and Analytics are not required by this feature. The server and phone need Internet access to Firebase; wireless debugging only provides the local connection to your API.

### Push acceptance

Use fictional records and separately provisioned staging test accounts; never run the local demo seeder on a hosted environment.

- [ ] With Firebase absent, the app opens and Updates shows the setup explanation.
- [ ] With Firebase configured, enable notifications and allow permission; Updates reports device registration.
- [ ] Submit a fictional report. On `/admin/`, change Submitted → Received using the confirmation dialog.
- [ ] With the app in the background, verify a notification titled **HERVOICE** with **“You have a new update. Open HERVOICE to view it.”** There should be no student name, report ID, staff reference, narrative or status in the payload.
- [ ] Tap it: Updates opens; a cold start requires sign-in first because app credentials remain memory-only.
- [ ] With the app in the foreground, another valid officer status change refreshes in-app data. No separate foreground system banner is implemented.
- [ ] Mark all updates read, refresh, and verify they stay read. This marks server updates read; it does not clear already displayed Android tray notifications.
- [ ] Disable phone notifications, then make another valid status change: the in-app update remains available and no new push should be sent to the revoked device.
- [ ] Sign out, enable under another student test account, and confirm the previous account's updates do not arrive.
- [ ] Deny permission and test loss of connectivity: reports and in-app updates should remain usable when the API is reachable.

Android force-stop prevents delivery until the app is reopened. Notification taps and foreground/background behavior follow [Firebase message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages). OS/network delivery is best-effort, not an emergency channel.

### Implemented behavior and limits

- Status change, student notification and per-device delivery queue entries commit together. Failed push attempts do not roll back case progress or remove in-app updates.
- The worker rechecks device ownership, active user/device status and whether an update is already read. It skips ineligible deliveries, retries transient failures up to five attempts with backoff, and disables invalid tokens. `sent` means Firebase accepted the request, not that a person saw it.
- Delivery is at least once: a process failure after provider acceptance but before commit can repeat an attempt. A stable Android notification tag reduces duplicate tray entries. Provider TTL is one hour after sending.
- Enabling affects future status changes, not historical notifications. Existing unread queued updates can be sent when the worker resumes.
- The client renews changed FCM tokens, revokes the prior token and retires its token on disable/sign-out. A fresh process retires the previous session's token; enable again after sign-in. Both server revocation and Firebase token deletion require connectivity. If both fail, generic notices can continue; use Android notification settings to stop previews immediately. Already delivered notices can remain in the tray.
- The app name remains visible. This is confidential reporting with restricted identity access, not anonymous reporting. Firebase receives the device routing token and neutral notification, not incident content.
- Flutter Firebase Core 4.x / Messaging 16.x and Firebase Admin 7.1 are used for the registration-token protocol. A future upgrade to Messaging 17's registration API needs a coordinated client/server review.
- This pass implements Android only. iOS/web push, delivery monitoring dashboards, token/queue retention policies, multi-stage identity approval and production operations remain outside this pass.

For diagnostics, inspect aggregate queue states (`pending`, `sent`, `skipped`, `failed`) in `push_deliveries` and server warnings. Do not copy device tokens or private credentials into logs. A running `/health` endpoint alone does not prove Firebase delivery.

## Android signing

Release signing now refuses to fall back to the debug certificate. Debug builds keep the existing local workflow. Release startup also requires an HTTPS API URL outside explicit demo mode.

1. Decide application ID/distribution ownership, retain a reviewed commit and approve the hosted staging endpoint. Do not change the application ID casually after distribution.
2. Create the signing key using Android Studio's signed bundle/APK flow or the JDK keytool, following https://docs.flutter.dev/deployment/android. Choose passwords privately. Keep the keystore outside the repository, restrict access and back it up under institutional ownership.
3. Copy `flutter_app/android/key.properties.example` to `flutter_app/android/key.properties`. Enter the absolute keystore path, alias and local passwords. The properties and keystore extensions are ignored by Git. Do not commit or upload signing material into test artifacts.
4. Set the version/build number in pubspec.yaml. From flutter_app build:

```bash
flutter build apk --release --dart-define=HERVOICE_API_BASE_URL=https://YOUR_HOST/api/v1
# For a store bundle instead:
flutter build appbundle --release --dart-define=HERVOICE_API_BASE_URL=https://YOUR_HOST/api/v1
```

5. Verify certificate identity using the Android SDK apksigner, install on a representative test phone and test over mobile data without ADB. Retain APK/bundle checksum, source revision and version. Test TalkBack, large text, restart, sign-in expiry, file selection and interrupted submissions.
6. A release certificate different from the installed debug certificate may prevent an in-place update. Do not uninstall to work around this until drafts have an approved recovery/migration path. Vault scope includes API URL and account ID; changing those values also affects recovery. Test upgrades on a disposable fictional-data installation first.

No signing key is generated or committed by the technical preparation pass. Real signed-release and device acceptance require the owner's key/configuration. CI runs unsigned technical tests and does not hold signing credentials. Real SMTP/S3/Firebase configuration and institutional acceptance remain launch gates.

## Operations and recovery

### Monitoring, backups and releases

Monitor HTTPS reachability, readiness, API errors/latency, disk and memory, database connection/capacity, storage failures, mail delivery and pending/failed push records. API access logs are disabled in the image and no proxy access log is enabled; application exceptions still need review for accidental sensitive fields. Send alerts to a named operator with response coverage. Do not collect narratives, identity reveal values, attachment bytes, JWTs, passwords, email codes or device tokens in monitoring.

A health probe and restart policy do not constitute an external monitoring system. Select/configure the institution's monitoring service and test an alert before launch. Container logs are rotated locally, not automatically backed up or centrally retained.

Define recovery point and recovery time targets. Back up PostgreSQL and matching evidence objects, retain access to encryption keys and protect backup credentials separately. For an operator-managed PostgreSQL backup, install matching PostgreSQL client tools and configure a protected `pg_service.conf` and password file; then use a service name rather than credentials in shell history:

```bash
pg_dump 'service=hervoice-backup' --format=custom --file=/SECURE_BACKUP_PATH/hervoice.dump
# Restore into a NEW isolated database using a separately configured service.
pg_restore --dbname='service=hervoice-restore-test' --exit-on-error /SECURE_BACKUP_PATH/hervoice.dump
```

Use provider-native snapshot/PITR and private object backup tooling where appropriate. Record object inventory/version references alongside the database recovery point. In staging, restore both and demonstrate report visibility, evidence integrity, account isolation and audit history. A live database dump plus unsynchronised object copy is not automatically a consistent recovery set. Do not restore over the running personal prototype or production database during rehearsal.

For a release, record commit/image tag, schema revision, configuration version, migration backup and approver. Rebuild the tagged image, run migrations once, recreate API/proxy, check readiness and execute a fictional end-to-end journey. Keep the previous image. Application rollback is safe only with compatible schema/data; never blindly run Alembic downgrade on live evidence/case records. Database recovery requires a planned maintenance/recovery procedure.


### Operational acceptance

These procedures are prepared instructions. External image execution, provider integration, monitoring alerts, backup restoration and host reboot still require recorded acceptance checks. Docker socket permission previously prevented local container execution; no host permissions were changed.


Neon table preparation completed: schema revision `0004`.
The migration-test branch `hervoice-migration-check-20261110-101836` expires after 24 hours.
Certificate verification for its connection required an explicit local CA bundle
(`/etc/ssl/certs/ca-certificates.crt`). No running API was restarted or switched.
