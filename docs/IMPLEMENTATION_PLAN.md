# HERVOICE Three Week Implementation Plan

## Goal and delivery boundary

Build a demonstrable student Android app, REST API, and officer dashboard for one university. A fictional student should be able to submit a report with one timeline event and one evidence file; an officer should be able to review it, update status, and trigger a generic student update. A rule may flag multiple reports for human review. The application must never describe a report or alert as proof of misconduct.

Use fictional accounts and evidence for the demo. University policy and a security review are required before accepting real reports.

## Current state as of 18 September 2026

| Area | Exists now | Still required for the integrated demo |
|---|---|---|
| Android | Compose screen flow builds to an APK | API login, real case list, submission, evidence picker/upload, protected local draft, retry UX |
| API | Login, report intake, student case list, officer queue/detail/status, notification records, pattern rule | Development users, migrations, contract tests, stricter status transitions, correct evidence lifecycle |
| Storage | Signed URL functions and evidence metadata model | Bucket creation, upload verification, private download audit, emulator/device reachable URL |
| Dashboard | Sign-in, queue, timeline, status controls, alert count | Evidence list/download, assignment or remove assignment from scope, alert review control, error/empty states |
| Notifications | Generic in-app notification records | Student Android view; FCM only if time and credentials allow |
| Operations | Docker Compose for PostgreSQL and MinIO, table creation script | Working host configuration, seed command, migration tool, end-to-end runbook |

The current Android “Submit report” button updates memory only. The current backend has not been demonstrated end to end. Do not claim that a student can already send a report to an officer.

## Ownership and integration

| Work | Owner | Handoff |
|---|---|---|
| Database, API, storage, dashboard, seed data, backend tests | Backend/dashboard developer | OpenAPI schema, test credentials, reachable development server |
| Android screens, secure local draft, attachment picker, sync, API client | Android collaborator | APK, screen-flow demo, request/response integration feedback |
| Reporting modes, demo script, fictional data, usability review | Both | Written decisions and one shared integration test |

Use the exact request/response examples in [API_CONTRACT.md](API_CONTRACT.md). Agree on any contract change in the repository before either side builds against it. The dashboard calls the API; it never reads PostgreSQL directly.

## Scope decisions to lock before implementation

1. **Primary demo path:** identified or confidential student report. Anonymous reporting is present in the API but has no case-code lookup or evidence upload yet. Either implement those before showing the anonymous path or keep it out of the demo.
2. **Evidence order:** choose the proposed draft → upload → verify → submit flow in the API contract. Today the API submits immediately and permits an upload afterwards. Do not build the Android integration around this temporary order.
3. **Confidentiality:** currently identified and confidential reports share the same reporter link and officer role. Define which role can see reporter identity and implement that policy before claiming distinct confidentiality.
4. **Status:** only server-created `draft` records should be drafts. A student’s unsent offline draft remains on the device. Define allowed officer transitions and disallow officers setting `draft`/`submitted` arbitrarily.
5. **Alert rule:** treat same staff reference as a candidate match. Staff identifiers need a canonical source or manual review; exact typed names are unreliable. Anonymous submissions cannot be assumed independent.
6. **Notifications:** deliver the in-app generic record first. FCM is optional for the three-week demo. There is no FCM token registration or sender in the current code.

Deferred: SMS, emergency dispatch, chat, maps, AI/ML analysis, recording inside the app, multi-university tenancy, production SSO/MFA, and real-case use.

### Coverage of the concept note

| Concept-note capability | Three-week treatment |
|---|---|
| Document incidents and timeline | Integrated demo path; at least one event per report |
| Evidence Vault | One or more selected files with verified upload and authorised officer access |
| Report and track cases | Integrated demo path with a small, defined status set |
| Identified/confidential/anonymous choices | Identified/confidential first; anonymous only if case-code follow-up and policy are resolved |
| Offline-first | Protected local draft and retry; no need for full offline case-history sync |
| Secure notifications | In-app generic update; FCM optional |
| Pattern detection | Internal rule and human review; no automated finding |
| Support directory/quick support | Static information only if time remains; no emergency dispatch |

## Technical layout

```text
Android app ── HTTPS/REST ──┐
                           ├── FastAPI ── PostgreSQL (accounts, reports, metadata, audit)
Officer browser ── HTTPS ──┘        └──── private S3/MinIO bucket (evidence bytes)
```

The API authorises each operation. For direct evidence transfer, it issues a short-lived signed URL after checking report ownership or officer role. The Android app keeps offline drafts and selected files on the device until server confirmation. Use Room plus Android Keystore-backed encryption or an equivalent reviewed design. See [BACKEND_STRUCTURE.md](BACKEND_STRUCTURE.md) for diagram labels and trust boundaries.

## Three-week sequence with exit criteria

### Week 1 — one report reaches the officer queue

1. Fix local setup: host-accessible database and storage URLs, bucket bootstrap, fictional student/officer seed accounts, and reviewed migration path.
2. Freeze reporting mode, required incident fields, date/time format, errors, and idempotency behavior in the API contract. Implement the server draft and submit endpoints in their final shape, initially without evidence.
3. Connect Android login and the draft → submit flow to the API. Create a protected local draft record and retain the same idempotency key through retries.
4. Display returned case ID and `submitted` state from the server; refresh `cases/mine` from the API.
5. Confirm on two machines or an emulator plus host: one submitted report appears in the officer queue. Confirm a student cannot call officer endpoints.

### Week 2 — evidence and case handling

1. Extend the agreed draft → submit flow with signed upload and verification between those two steps. The server verifies the object exists, size/type/hash as feasible, and records an `uploaded` state. Remove incomplete objects/metadata on expiry.
2. Add Android document picker, upload progress, retry behavior, and a report review screen that distinguishes selected from uploaded evidence.
3. Add officer evidence listing and audited private download, plus case status transitions. Implement assignment only if the dashboard will actually use it.
4. Show a generic in-app notification on status change. Student refreshes notifications after opening the app.
5. Test wrong-role access, cross-student report access, invalid file type/size, interrupted upload, and duplicate submission.

### Week 3 — integration, alerts, demo

1. Implement canonical staff reference or a clearly labelled manual matching step. Count unique authenticated reporters within 90 days. Exclude anonymous reports from the independence threshold until anti-abuse policy exists.
2. Add officer alert review action and confirm it is audited. Use “review required” language only.
3. Test offline draft creation, app restart, retry, and return to the exact server case without duplicates.
4. Run the fictional student → API → officer → student scenario on the devices used for presentation. Build a debug APK and document startup commands and known limitations.
5. Freeze code for the final demo; use remaining time for fixes and documentation. Optional FCM comes after the in-app flow works.

## Required acceptance checks

- Authentication and role checks: invalid token is rejected; student cannot see officer routes or another student’s case.
- Report: one retry with the same idempotency key returns the same report, including after a network timeout.
- Evidence: a selected file is uploaded to a private bucket, verified before submission, listed for the officer, and unavailable to an unauthorised caller.
- Audit: officer case detail, evidence download, status change, and alert review each create an audit record.
- Offline: an unsent draft survives process death and does not appear on the server until the student submits.
- Notification: the lock screen and in-app list use neutral text; status detail is available only after authentication.
- Demo: the Android case ID and officer case ID match, and the status update appears on Android after refresh.

## Decisions needing university input before real use

The university must approve which reporting modes exist, who can see confidential identity, who can read evidence, retention/deletion periods, emergency escalation, lawful recording rules, hosting location, consent text, and breach response. Until then, use fictional data only.
