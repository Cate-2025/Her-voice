# HERVOICE — project description

Current review baseline: 10 November 2026. Read this first to understand the
product, the parts in the repository and what a deployment delivers.
Use [Deployment](DEPLOYMENT.md) for actions and [Decisions](DECISIONS.md) for
scope and institutional questions.

## Product and intended users

HERVOICE is an Android student reporting and support application with a browser
workspace for authorised officers and administrators. It supports documenting
incidents, preserving drafts, submitting evidence, tracking case progress and
receiving neutral updates. It is account-linked confidential reporting; it does
not provide truly anonymous intake or emergency response.

Students use the Android app. Officers review submitted cases and permitted
evidence. Administrators have a separate reason-recorded, audited identity
access action. Narratives and evidence may themselves identify a person.

## Current capability and boundaries

| Area | Implemented | Boundary to understand |
| --- | --- | --- |
| Account access | Email-code student registration, password reset, sign-in, role checks | All email domains accepted; mailbox control does not prove university membership. Hosted inbox delivery requires SMTP acceptance. Sessions are memory-only. |
| Drafts | Encrypted Android text/evidence, same-account recovery after restart/sign-out | Keys and files stay on that device. Recovery scope includes account ID and API URL; uninstall/key loss or endpoint changes need a deliberate migration plan. |
| Submission | Explicit confirmation, persisted frozen operation, retry after interruption | Pending payload stays locked. No automatic background submission, offline sign-in or post-submission amendment workflow. |
| Evidence | Up to five files, 10 MiB each, format/checksum/read-back verification, authorised download | Verification is not malware scanning. Private hosted storage and retention/cleanup operation need acceptance. |
| Case handling | Readable date-tagged records, dated status history, officer queue/filtering/paging and confirmation | Officer access is broadly role-based, not assignment-scoped. Action required has no specific student follow-up workflow yet. Closure is not a finding of misconduct. |
| Identity | Normal officer responses omit account identity; admin reveal requires an audited reason | This is not an institution-approved disclosure/approval process by itself. |
| Updates | In-app read/read-all; optional Android Firebase push implementation | Firebase project/credentials and real phone delivery acceptance remain external setup. Firebase does not store the app's drafts or serve as its database. |
| Support | Published Makerere contacts and reporting guidance | Contacts were checked online on 10 November 2026, not called. Named ownership/hours and periodic review remain to agree. |
| Recurrence | Exact staff-reference rule over 90 days, three distinct reporting accounts; human-review alert | Free-text matching and account counts do not prove misconduct or three distinct people. Broader BI is not delivered. |

Home has no Prototype header badge. Routine device-storage text is kept in Records
and Privacy; actionable errors remain visible. Manual refresh is under
Account → Refresh records and updates. The visual direction is recorded in
[DESIGN.md](../DESIGN.md); product/design constraints remain in [PRODUCT.md](../PRODUCT.md).

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
| Database structure | `backend/app/models.py`, `database.py`, `backend/migrations/versions/`, `alembic.ini` | Models and versioned database changes | Run migrations against the chosen PostgreSQL service. Migrations update that database schema; they do not transfer your laptop database to a hosted service. |
| Evidence storage integration | `backend/app/services/storage.py`, `routers/evidence.py` | Writes/reads private evidence and controls authenticated transfers | Configure a separate private S3-compatible bucket for hosted use. Docker image is not the evidence store. |
| Email and push integration | `backend/app/services/email_access.py`, `push.py`; `flutter_app/lib/core/push_service.dart` | Email codes/reset and generic Android notifications | Mail provider and Firebase project/credentials are external setup. Push worker currently runs inside the API process. |
| Deployment packaging | `backend/Dockerfile`, `.dockerignore`, `deploy/compose.yaml`, `Caddyfile`, `compose.push.yaml` | Builds API image; optional VM orchestration, HTTPS and Firebase credential mount | Use Compose/Caddy on a VM, or adapt to a managed host's ingress/startup. A Dockerfile alone does not provision dependencies. |
| Tests and automated checks | `backend/tests/`, `flutter_app/test/`, `.github/workflows/checks.yml` | Regression tests and prepared CI checks | Development/release tools. They are not a separate public service and do not prove provider/device acceptance. |
| Reference material | `docs/` | Requirements, decisions, guides and recorded checks | Retain with source; not needed as a running service. |
| Historical work | `mobile/`, `legacy/main/` | Older Compose app and earlier branch implementations | Historical reference. Active development uses `flutter_app/` and `backend/`. |

## Local files versus hosted services

`backend/.prototype/` is hidden local development state: the prototype runner keeps its PostgreSQL data, evidence, JWT secret and optional development mail there. Preserve it if you need existing fictional test records. Do not upload the entire directory as an application image.

`scripts/run_prototype.py` creates/uses that local setup, migrates it, seeds missing fictional users and starts the API. It overrides database/storage settings. It is convenient for laptop testing; it is not the startup command for an external database deployment.

For hosted settings, `backend/app/config.py` reads environment variables and optionally `.env`. Examples are in `backend/.env.example` and `backend/deploy/.env.example`. They are templates, not actual configured cloud accounts. Real credentials belong in protected local configuration or the hosting platform's secret settings. This guide does not inspect or publish any private environment values.

Initial hosted administration uses `backend/scripts/bootstrap_admin.py`; ordinary hosted deployment does not run `seed_demo_users.py`.

## What typically gets deployed

1. **API image:** application code, admin static files, dependencies, migrations and initial-admin bootstrap. One process serves the API and browser dashboard.
2. **PostgreSQL:** a managed database service, or a separately maintained database container/installation on a VM with persistent storage.
3. **Private bucket:** persistent evidence objects, separate from the replaceable API container.
4. **HTTPS entry point:** managed host's HTTPS endpoint, or Caddy plus DNS on a VM. The current Compose configuration is for the VM route; managed hosting needs its own configuration.
5. **Provider configuration:** mail credentials, optional Firebase identity, JWT secret, database URL and storage settings.
6. **Android APK:** built with the hosted `https://HOST/api/v1` address and installed on the demo phones. Staff use `https://HOST/admin/` in their browser.

Pushing a Git branch makes source available to a configured build/deploy system; it does not itself provision a database, bucket, mail service or phone build. Publishing to the Play Store is not required for a directly distributed demo APK.



## Verification and deployment position

Most recent recorded local results, from the UI pass on 10 November 2026:
74 Flutter tests passed, one optional live-API test skipped, static analysis clean,
and a debug Android APK compiled and installed on the TECNO CK6 while retaining
app data. The phone reached the local API through adb port reversal and received
HTTP 200/ready. The officer review separately recorded 69 backend tests and,
after its motion changes, 24 admin tests; these are dated results, not checks
rerun by this documentation consolidation.

This is sufficient groundwork to attempt a small hosted fictional-data demo.
A working localhost installation does not establish independent hosted operation.
The subsequent Neon integration pass recorded 75 backend tests passed on isolated
temporary PostgreSQL. Neon database settings were linked and verified read-only;
the application schema was subsequently tested on an isolated branch and migrated
to production. The Render API service is now live at https://her-voice-e2mu.onrender.com;
HTTPS health, dependency/schema readiness and the staff dashboard returned 200.
Private Neon evidence storage has now passed synthetic upload/download/deletion
and anonymous-access checks. Real SMTP/Firebase acceptance, signed hosted upgrade,
full physical-device accessibility pass or restore exercise is established by
these records. Complete [Release checklist](RELEASE_CHECKLIST.md) for the actual
hosted build before expanding use. Real-report use also requires the relevant
[stakeholder decisions](DECISIONS.md).

## Makerere reporting context

Support text uses Makerere's [contact directory](https://mak.ac.ug/get-touch),
[School of Medicine safeguarding guidance](https://som.mak.ac.ug/makerere-university-school-of-medicine-safeguarding/)
and [published sexual-harassment policy](https://policies.mak.ac.ug/policy/policy-regulations-sexual-harassment-prevention).
MakSafeSpace is a separate official reporting service. HERVOICE has no automatic
handoff or institutional referral integration. Review identity disclosure,
staff duties and the official handling process with the institutional owner
before treating HERVOICE submission as an official complaint.

## Earlier requirements and design work

The original requirement comparison, branch consolidation notes, UI audits and
stakeholder Word workbook are preserved in [Archive](archive/README.md). They are
historical evidence. Features later implemented are summarised above, so an old
unfinished-item list must not be used as the current release scope.
