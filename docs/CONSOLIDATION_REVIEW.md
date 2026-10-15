# HERVOICE consolidation and original-plan comparison

Reviewed 15 October 2026 against `/home/emmaa/Desktop/case.doc` (the supplied document contains sections 6–10), remote main `38b13df`, and backend `0993dde`. The user selected the redesigned Flutter interface with FastAPI. This is a first connected prototype milestone, not completion of the full concept paper.

## What changed from the original plan

The purpose and four-layer architecture in section 7 remain intact: an Android client, authenticated REST API, database plus separate evidence storage, and an authorised officer dashboard. The supplied sections do not prescribe Node versus Python or a particular mobile framework. Choosing Flutter/FastAPI/PostgreSQL therefore changes implementation choices, not that architecture.

The significant difference is completion depth. The original week 4 outcome includes evidence upload; weeks 5–8 add an evidence vault, offline synchronisation, notifications, security, and final testing. The consolidated milestone connects reporting and case handling but does not yet meet all those gates. Calendar weeks are planning labels, not evidence of elapsed progress; no user-research or final acceptance evidence was supplied in this review.

| Section 10 expected outcome | Consolidated milestone | Remaining work before claiming the planned outcome |
|---|---|---|
| 1. Secure student authentication | Seeded student accounts, password hashing, expiring JWTs, role checks; client session token is memory-only | Registration/recovery, session policy, rate limiting, shared-environment HTTPS and device security testing |
| 2. Create and submit an incident report | Connected Flutter editor → explicit consent → FastAPI private server draft → submit → PostgreSQL; retry uses a frozen payload and idempotency key | Durable recovery after process death; fuller server-side draft lifecycle |
| 3. Attach and securely manage evidence | Deferred in connected client; standalone UI demo can select metadata only | Verified upload completion, byte/hash/type checks, private storage lifecycle, authorised officer download and auditing |
| 4. Incident timeline | One dated incident entry from the client; API accepts multiple events | Multi-event editor and complete event presentation/editing policy |
| 5. Confidential reporting | Authenticated reporting, owner checks, officer role access; no identity fields in student/officer response summaries | A reviewed identity-disclosure policy. The database links reports to accounts; this is not anonymous reporting |
| 6. Case-status tracking | Submitted reports and current server status reload after sign-in and on Refresh | Full dated status history, pagination and richer follow-up |
| 7. Administrative case management | Web officer queue/detail, valid status transitions and audit records | Assignment-scoped access, evidence review controls, analytics/exports and fuller alert handling |
| 8. Offline creation and synchronisation | Draft editing is memory-only during a signed-in session; network errors retain it and retries are deliberate | Encrypted durable local drafts and attachment bytes, account-scoped sync queue, reconnect/restart recovery |
| 9. Secure notifications | Neutral in-app notices from officer status changes, explicit refresh and mark-read | Push, SMS fallback, device registration, delivery preferences and lock-screen testing |
| 10. Basic recurring-report pattern detection | Tested backend rule: distinct authenticated reporters, rolling window, human-review alerts | Canonical subject matching, review workflow and evaluation with agreed scenarios; never a finding of misconduct |

Other section 7 expectations: support guidance exists, but the contact directory is intentionally unpopulated until contacts are verified. Self-service registration, anonymous capability/recovery, mapping and third-party notification integrations are not enabled. This review did not change these requirements into promises of completion.

## Why the two branches could not simply be combined

- Local main was still the initial scaffold (`6bfa856`). Fetch confirmed remote main at `38b13df`, five commits ahead; its work is included in the merge ancestry.
- Main contained `mobile_flutter/` with a Node/Express API at `/api` (port 4000), JSON data/files, registration, reporting pathways, evidence transfer, offline queue, notifications and Flutter officer screens.
- Backend contained `flutter_app/` with the newer design and fictional memory-only state, plus FastAPI at `/api/v1` (port 8000), PostgreSQL migrations, S3 reservation scaffolding and a browser officer dashboard.
- Requests, response fields, token names, statuses and evidence lifecycles differ. Pointing the old client at FastAPI would not work.
- Main's SQLite queue stores payload JSON directly in a TEXT column. Its presence does not establish the original plan's secure offline-storage requirement. It was not copied into the active client as a finished solution.
- Android projects also had incompatible Gradle layouts and activity packages. The Compose reference from backend is retained as `mobile/`; the active client is `flutter_app/`.

## Merge decisions and traceability

- Active product: `flutter_app/` + `backend/` (FastAPI) + PostgreSQL + browser officer dashboard.
- Main's Node backend, connected Flutter client, older Android client and Windows scripts are preserved byte-for-byte under `legacy/main/` for reference and selective future porting. They are outside the supported prototype run path; do not run them against FastAPI.
- Both branch histories are retained by a merge commit. Backup refs `backup/main-before-integration-20261015` and `backup/backend-before-integration-20261015` preserve the initial local tips. No remote push is part of this pass.
- Seven textual merge conflicts were resolved. Tracked IDE caches were excluded from the active project. Local generated files and SDK paths are ignored.
- The earlier Flutter review fixes remain: required-field checks at review, scrollable short-window sidebar, unsupported-file rejection in demo mode and waiting for file selection before review.

## Connected work completed in this pass

1. Configurable FastAPI HTTP client with timeouts, status handling and no fictional-data fallback.
2. Student sign-in and protected routes; sign-out clears local account data. Expired sessions require reauthentication; same-account in-memory drafts survive that reauthentication, while changing accounts clears them.
3. Explicit real-submission consent and server-backed confirmation. Each pending submission preserves its exact request and operation key; editing/deletion is locked while its result is unresolved.
4. Server case loading, current status, neutral notifications, mark-read and manual refresh. No invented dated status history is displayed.
5. Connected attachment controls explicitly explain that uploads are unavailable. UI preview remains opt-in with `HERVOICE_DEMO=true`.
6. Restricted browser-development CORS, Android internet permission and debug-only cleartext for local development. Release use requires an HTTPS endpoint.
7. Officer login errors are visible; student accounts cannot enter the officer dashboard; Refresh is available; reviewed alerts are excluded from the active list.
8. Local PostgreSQL prototype runner, migration/seed setup, regression tests and a real Flutter repository → HTTP API → PostgreSQL acceptance test.

## Verification and practical limits

Verified on 15 October 2026:

- Flutter analyzer: no issues.
- Flutter suite: 40 passed; the opt-in live-server test is skipped in the ordinary suite.
- Live Flutter/API/PostgreSQL acceptance test: passed separately.
- Backend PostgreSQL suite: 15 passed. One upstream Starlette/httpx deprecation warning remains; no test failure.
- Release web build: succeeded.
- Android debug APK: built successfully using the installed Android Studio JBR/SDK. SDK XML/native-access tooling warnings did not prevent the build.
- Officer dashboard JavaScript syntax: passed.
- Connected physical-device UI and TalkBack/lifecycle checks: not performed; no device attached.


See [prototype runbook](PROTOTYPE_RUNBOOK.md) for reproducible checks and demo steps. The user reported that the backend branch's Android UI launches and looks consistent. That is recorded as user feedback, not a completed connected Android acceptance test. No device was attached during this pass.

The live automated acceptance test uses fictional data: student login → report creation/submission → officer queue → received status → student refresh → notification read → sign-out/re-login → case recovery. PostgreSQL tests also cover role/owner isolation, migration upgrades, concurrent retries, evidence blocking and pattern rules.

First follow-up milestone: verified evidence end to end, then encrypted durable drafts/sync and device lifecycle testing. These are required before the original section 10 demonstration can include attached evidence and offline recovery. This milestone is suitable for a supervised fictional-data demonstration of reporting and case coordination, not deployment for real incidents.
