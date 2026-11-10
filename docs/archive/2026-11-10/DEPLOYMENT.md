> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Deploy HERVOICE — start here

Updated 6 November 2026. **This is the single deployment walkthrough.** Follow steps 0–7 in order. Each step says what you need, what to do and what working looks like. The current repository contains deployment groundwork; cloud deployment has not been established or certified by these documentation passes.

Use fictional records for the demo. You do not need to read the progress reports or historical plans to follow this guide.

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

## 0. Choose one route

| Route | What to use | Status in this repository |
| --- | --- | --- |
| Laptop only | Prototype runner and adb reverse | Use [local testing](PROTOTYPE_RUNBOOK.md). This still depends on the laptop. Stop reading the hosted steps if that is all you need today. |
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

## 2. Create private evidence storage

**You need:** an S3-compatible HTTPS endpoint, private bucket, service access key/secret and any required signing region.

**Do:** create the bucket and keep public access disabled. Give the API permission to write/read its `reports/*` objects and perform bucket readiness checks. On AWS S3, HeadBucket requires the appropriate bucket `ListBucket` permission; other providers have their own access controls. Configure provider encryption/versioning and backup arrangements.

**Expected result:** a private bucket and API credentials exist. It is normal that no evidence appears before an actual report upload. The API does not create the bucket. Files must survive replacement/restart of the API container.

## 3. Configure email

**You need:** SMTP host/port, TLS mode, sender and credentials (or an approved restricted relay).

**Do:** verify the sender with the provider, including required DNS records. Confirm the API host permits that outbound connection. Use `starttls` or `ssl` as the provider specifies; never work around a port restriction by disabling TLS.

**Expected result:** the provider account/sender is ready. Real verification/reset delivery is tested after API deployment in step 5. With hosted settings, the current API requires configured SMTP even if you initially demonstrate only existing accounts. Local file mail is development-only.

**Only if needed:** [email details](EMAIL_ACCESS_SETUP.md) explains code expiry, reset behaviour and mail limitations.

## 4. Deploy the API and included admin website

### 4a. Supply configuration

Source files: `backend/Dockerfile` and `backend/app/`. Set these in the managed host's secret/environment settings, or in protected `backend/deploy/.env` on the VM:

| Setting | Value / purpose |
| --- | --- |
| `APP_ENV` | `staging` for this demo deployment |
| `DATABASE_URL` | PostgreSQL URL from step 1, with verified TLS |
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

Templates: `backend/.env.example` for host-run Python; `backend/deploy/.env.example` for VM Compose. Templates are not usable credentials. Hosted validation rejects placeholders, local evidence, disabled/file mail and HTTP storage/browser origins. Keep `APP_ENV=staging` and fix the failing setting rather than bypassing validation.

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

Only open [Android push setup](ANDROID_PUSH_SETUP.md) if testing phone notifications now. The project needs Android package `com.hervoice.hervoice`, its `google-services.json` in `flutter_app/android/app/`, and a separate server sending identity from that same Firebase project.

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

For the distributable signed release, follow [Android release signing](ANDROID_RELEASE.md), then build with the same HTTPS define. Release builds require HTTPS and owner-supplied signing; the project refuses debug-signing fallback. A Play Store listing is not required for a directly shared APK.

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

Record results in [Manual testing checklist](MANUAL_TESTING_CHECKLIST.md). Set a demo end date, provider quota checks, operator contact and backups. Before relying on stored records, rehearse a database-plus-evidence restore. For detailed monitoring, recovery and later releases, open [Backend operations](INDEPENDENT_BACKEND_RUNBOOK.md) only when needed.

**Evidence boundary:** this consolidation checked instructions against repository code/configuration; it did not deploy services or rerun application tests. Container/provider/device acceptance remains to execute. Free-tier offerings are not guaranteed by this guide. Administrative decisions and real-data launch approval remain tracked separately.
