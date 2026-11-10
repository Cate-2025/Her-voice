> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# HERVOICE project map and fresh demo plan

Updated 6 November 2026. This is the architecture reference. For the steps and expected results, use [Deployment](DEPLOYMENT.md). This map describes the checked-out files, not confirmation that a cloud deployment exists.

## The whole system

The student uses an Android app. It talks over HTTPS to the API. Officers and administrators use a browser website served by that same API. The API stores structured records in PostgreSQL and evidence files in private object storage. It sends verification/reset email through a mail provider and, when configured, generic phone notifications through Firebase.

Android local drafts are a separate encrypted copy on the phone. They are not the hosted database and do not constitute a server backup.

## Where to look

All paths are relative to `/home/emmaa/Work/Her-voice/`.

| Chunk | Files | Role | Deployment result |
| --- | --- | --- | --- |
| Student app | `flutter_app/`, especially `lib/features/` | Screens for access, home, reports, records, updates and support | Build an APK and install it on phones. App source is not installed on the API host. |
| App startup and navigation | `flutter_app/lib/main.dart`, `lib/app/app.dart`, `lib/app/shell.dart`, `lib/app/theme.dart` | API address, connected/preview mode, routes, navigation, visual system | Compiled into the APK. API address changes require a rebuild. |
| App/API coordination | `flutter_app/lib/core/api_client.dart`, `connected_store.dart` | Sign-in requests, data loading, durable submission/retry coordination | Compiled into the app. |
| Private device storage | `flutter_app/lib/core/encrypted_draft_vault.dart`, `draft_save_queue.dart`, `submission_intent.dart` | Encrypted drafts/evidence and stable retry intent | Runs on the phone. Same account and API URL are required for normal recovery. |
| API server | `backend/app/main.py`, `routers/`, `services/` | Authorisation, reports, evidence checks, status changes, email and push coordination | One running Python/FastAPI application, ordinarily packaged as a container. |
| Officer/admin website | `backend/app/static/admin/index.html`, `app.js`, `styles.css` | Browser queue, details, confirmations and controlled identity access | Included in the API deployment. Open `/admin/`; no separate frontend deployment is required. |
| Database structure | `backend/app/models.py`, `database.py`, `backend/migrations/versions/`, `alembic.ini` | Models and versioned database changes | Run migrations against the chosen PostgreSQL service. Migration files do not contain or migrate existing report data. |
| Evidence storage integration | `backend/app/services/storage.py`, `routers/evidence.py` | Writes/reads private evidence and controls authenticated transfers | Configure a separate private S3-compatible bucket for hosted use. Docker image is not the evidence store. |
| Email and push integration | `backend/app/services/email_access.py`, `push.py`; `flutter_app/lib/core/push_service.dart` | Email codes/reset and generic Android notifications | Mail provider and Firebase project/credentials are external setup. Push worker currently runs inside the API process. |
| Deployment packaging | `backend/Dockerfile`, `.dockerignore`, `deploy/compose.yaml`, `Caddyfile`, `compose.push.yaml` | Builds API image; optional VM orchestration, HTTPS and Firebase credential mount | Use Compose/Caddy on a VM, or adapt to a managed host's ingress/startup. A Dockerfile alone does not provision dependencies. |
| Tests and automated checks | `backend/tests/`, `flutter_app/test/`, `.github/workflows/checks.yml` | Regression tests and prepared CI checks | Development/release tools. They are not a separate public service and do not prove provider/device acceptance. |
| Reference material | `docs/` | Requirements, decisions, guides and recorded checks | Retain with source; not needed as a running service. |
| Historical work | `mobile/`, `legacy/main/` | Older Compose app and earlier branch implementations | Historical reference. Active development uses `flutter_app/` and `backend/`. |

## Local files versus hosted services

`backend/.prototype/` is hidden local development state: the prototype runner keeps its PostgreSQL data, evidence, JWT secret and optional development mail there. Preserve it if you need existing fictional test records. Do not upload the entire directory as an application image.

`scripts/run_prototype.py` creates/uses that local setup, migrates it, seeds missing fictional users and starts the API. It overrides database/storage settings. It is convenient for laptop testing; it is not the startup command for an external database deployment.

For hosted settings, `backend/app/config.py` reads environment variables and optionally `.env`. Examples are in `backend/.env.example` and `backend/deploy/.env.example`. They are templates, not actual configured cloud accounts. Real credentials belong in protected local configuration or the hosting platform's secret settings. Neither of those `.env` files existed at the paths checked for this map.

Initial hosted administration uses `backend/scripts/bootstrap_admin.py`; ordinary hosted deployment does not run `seed_demo_users.py`.

## What typically gets deployed

1. **API image:** application code, admin static files, dependencies, migrations and initial-admin bootstrap. One process serves the API and browser dashboard.
2. **PostgreSQL:** a managed database service, or a separately maintained database container/installation on a VM with persistent storage.
3. **Private bucket:** persistent evidence objects, separate from the replaceable API container.
4. **HTTPS entry point:** managed host's HTTPS endpoint, or Caddy plus DNS on a VM. The current Compose configuration is for the VM route; managed hosting needs its own configuration.
5. **Provider configuration:** mail credentials, optional Firebase identity, JWT secret, database URL and storage settings.
6. **Android APK:** built with the hosted `https://HOST/api/v1` address and installed on the demo phones. Staff use `https://HOST/admin/` in their browser.

Pushing a Git branch makes source available to a configured build/deploy system; it does not itself provision a database, bucket, mail service or phone build. Publishing to the Play Store is not required for a directly distributed demo APK.

## Where to go next

Follow [Deployment](DEPLOYMENT.md). Its ordered checklist is the current deployment plan. Use [manual testing](MANUAL_TESTING_CHECKLIST.md) to record acceptance; consult the stakeholder workbook for administrative decisions.
