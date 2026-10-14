# HERVOICE Flutter redesign and implementation plan

Prepared 12 October 2026. Planning baseline: local `backend` branch, commit `162380c`. This document records the original implementation roadmap. Actual completed work is tracked in [IMPLEMENTATION_PROGRESS.md](IMPLEMENTATION_PROGRESS.md); use [API_CONTRACT.md](API_CONTRACT.md) for current endpoint behaviour.

## 1. Delivery goal and assumptions

Deliver an Android-first Flutter app in which a student can privately document an incident, retain a protected offline draft, deliberately submit it with verified evidence, track its progress, and receive neutral updates. An authorised officer must be able to review the same case, access evidence, and update its status through the existing web dashboard.

Keep FastAPI, PostgreSQL, and private S3-compatible storage. Build Flutter in `flutter_app/`, retaining `mobile/` as the Compose reference until the new app passes acceptance. Keep the officer dashboard as a browser application; rebuilding it in Flutter is outside the first release.

Working defaults, subject to product decisions before the affected implementation:

- One university, English, Android as the first tested target. iOS follows only when Apple build/signing infrastructure and device testing are available. Flutter web and desktop are outside this scope.
- First integrated milestone uses fictional authenticated student accounts and one approved reporting mode. The existing `confidential` enum can support demo fixtures, but the UI must explain actual access without promising a distinct identity-protection policy that has not been implemented.
- In-app notifications first. Push notifications, anonymous follow-up, and richer officer assignment are later milestones.
- Evidence is optional; a report without a file remains valid. Initial allowed formats follow the backend: JPEG, PNG, PDF, MP3, and M4A, subject to content validation. The current configured limit is 10 MiB per file; propose five files per report and enforce an aggregate limit server-side.
- No fixed deadline was supplied. Estimates below are planning ranges, not delivery commitments.

## 2. What exists and what can be reused

| Area | Verified local state | Implementation treatment |
|---|---|---|
| Git | `backend` has FastAPI/Compose commits; `origin/develop` has separate Android auth and Node/Express work; `main` is the initial scaffold | Base the migration on `backend`; review collaborator work before merging into the shared integration branch |
| `mobile/` | One Compose activity with demo sign-in, case list, incident form, review, and in-memory submission | Reuse journey and wording selectively; reimplement UI/state in Dart |
| `backend/` | Models, JWT login, student report intake, officer queue/detail/status, signed URLs, notifications, pattern rule, static dashboard | Extend and test this implementation |
| `../hervoice-backend/` | No Git repository; README/config/database/models scaffold; lacks the repository's routers, services, and entry point | Compare unique model/config differences during baseline reconciliation; do not run as a second backend |
| Offline support | No durable mobile draft or protected attachment store | Implement before claiming draft saving |
| Evidence | Metadata reservation and signed URLs; no completion verification or officer evidence listing | Replace with a complete lifecycle |
| Operations | PostgreSQL/MinIO Compose, local table-creation script, pinned Python requirements | Add migrations, bucket bootstrap, fictional seed users, tests, CI, and runbook |
| Documentation | API contract, backend structure, old three-week Android plan | Preserve as history; reconcile with this Flutter plan during implementation |
| Tooling | `flutter` and `dart` were not found on the shell PATH during review | Verify existing installations, then install/configure a pinned SDK during setup |

GitHub was not fetched for this planning review. Local remote-tracking branches may be stale. No application build, database migration, backend execution, or end-to-end test was performed for this document.

### Source findings that affect implementation order

1. `routers/reports.py` submits immediately. A new server draft and explicit finalisation flow must precede the Flutter submission integration.
2. Idempotency compares a key and reporter ID but does not compare request content or handle concurrent creation safely. Anonymous requests all have a null reporter ID, so their retry ownership needs a separate design.
3. `routers/evidence.py` permits evidence reservations after submission and sets no verified state. `Evidence.uploaded_at` currently defaults to metadata creation time, which is not proof of an upload.
4. Officer access is role-wide, and the queue queries all reports. Introducing server drafts without changing these queries would expose unsubmitted material to officers.
5. Officer status updates accept any enum value. Repeated or backward updates can create misleading workflow and duplicate notifications.
6. `services/patterns.py` counts anonymous submissions as independent reporters. Its moving-window lookup can miss previous alerts as time advances and create duplicates. Correct both before presenting the alert count.
7. `subject_staff_ref` is required free text. Define an unknown-subject option and canonical matching; students should not need an internal staff ID to document an incident.
8. The dashboard lacks evidence controls and alert review actions. Its status-save callback also needs explicit error handling and detail refresh.
9. There is no refresh-token flow, registration endpoint, account recovery, migration system, or discovered test suite. Do not build client screens that assume these exist.

## 3. Product scope and redesign

### Navigation and visual direction

Use four primary destinations: Home, My records, Updates, and Support. Keep settings and sign-out in an account menu. The main action is “Document an incident”. My records separates “Saved on this device” from “Submitted reports”.

Proposed visual direction: warm neutral surfaces, deep plum primary colour, restrained teal secondary colour, readable typography, generous spacing, and simple cards. Validate colour contrast before adopting exact tokens. Use icons with labels and status text in addition to colour. Avoid decorative imagery in reporting forms, urgency cues, or success language implying that a case has been resolved.

Define shared tokens for colour, type, spacing, corner radius, elevation, focus/error states, and motion. Build reusable fields, primary/secondary buttons, draft cards, case cards, attachment rows, status chips, empty states, and progress panels. Check large text, small screens, keyboard visibility, screen-reader order, and at least 48 logical-pixel touch targets.

### Screen specification

| Screen | Content/actions | Required states and acceptance |
|---|---|---|
| Welcome | Short explanation of documentation, submission, and who handles reports | Can reach support without signing in; no unsupported anonymity promises |
| Sign in | University email and password, show/hide password | Loading, invalid credentials, offline, expired session; no registration button until supported |
| Home | Continue saved draft, document incident, recent case updates | Empty and returning-user layouts; sensitive narratives absent from overview |
| My records | Local drafts and submitted cases | Distinct local/server states; last refresh and offline indication |
| Draft editor | Incident narrative, date/time, optional location/course, subject information; multiple timeline events | Save/restore, validation, delete confirmation, unsaved-change handling |
| Evidence | System file picker, type/size information, remove attachment | Selected, preparing, uploading, verified, failed; no forced file submission |
| Review | Full report summary, edit links, access explanation, deliberate submit | Explains that submitting sends data to the university; no transmission on ordinary draft save |
| Submission progress | Preparation, uploads, verification, finalisation | Retriable interruption, expired session, cancel/pause, ambiguous response recovery |
| Confirmation | Server-confirmed identifier and next steps | Appears only after server confirmation; no invented response-time promise |
| Case detail | Timeline, attachment metadata, status history | Loading, inaccessible case, refresh failure; submitted content initially read-only |
| Updates | Neutral notification list and read state | No allegation details in previews; authenticated access to details |
| Support | Verified university services, availability, contact actions | Content owner and last-reviewed date; no invented phone numbers or emergency dispatch claims |
| Account/privacy | Session controls, draft storage explanation, local deletion | Account switching cannot reveal another student's drafts |

Use date/time pickers with an explicit timezone. Decide during the contract workshop how uncertain or approximate dates are recorded; never fabricate a precise date. Allow partial drafts, but validate required fields at submission. Default unknown-subject reports out of automatic staff matching.

Design deliverables before feature construction: navigation map, low-fidelity screens, one polished end-to-end reporting flow, component catalogue, and a copy/accessibility review. Review these on an Android-sized viewport using fictional content.

## 4. Flutter architecture

Use a small feature-based structure with UI controllers/view models, repositories, and services. Keep widgets free of networking and persistence logic. Repository boundaries coordinate local and remote data, consistent with [Flutter's architecture guidance](https://docs.flutter.dev/app-architecture/guide) and [offline-first guidance](https://docs.flutter.dev/app-architecture/design-patterns/offline-first).

```text
flutter_app/
  lib/
    app/                 # bootstrap, routing, dependency wiring, theme
    core/                # config, API errors, secure storage, local DB, logging
    features/
      auth/
      home/
      reports/           # editor, local drafts, submission coordinator
      evidence/
      cases/
      notifications/
      support/
      settings/
  test/                  # unit and widget tests
  integration_test/      # real journeys on emulator/device
backend/
  app/                   # existing API and officer dashboard
  migrations/            # new Alembic migrations
  tests/
  scripts/
docs/
```

Initial architecture decisions:

- Pin a supported Flutter stable SDK and commit the app dependency lockfile. Validate Android build tools and plugin support before choosing versions.
- Use one routing approach and one state-management approach. Default to `go_router` and SDK `ChangeNotifier`/`Listenable` view models with constructor injection; introduce another state package only for a demonstrated need. Routing choice follows [Flutter's recommendations](https://docs.flutter.dev/app-architecture/recommendations).
- Use typed request/response models and a single API client. Prefer OpenAPI-generated models if the generation tool passes a compatibility spike; otherwise maintain explicit models with contract tests.
- Separate the authenticated API client from evidence upload requests. Never attach the API bearer token to object-storage URLs.
- Keep demo repositories explicitly configured and visibly labelled in development; release builds must not silently fall back to demo data.
- Store tokens and encryption keys through platform-backed secure storage. Choose local database/file encryption dependencies only after a device spike verifies encryption, recovery, backup exclusions, and supported Android versions. A plain SQLite database is insufficient for sensitive drafts.
- Add development/staging/production configuration for public API addresses. Server secrets and object-storage credentials never belong in the app.

### Local draft and retry design

Persist a local draft ID, account ID, payload version, incident events, encrypted attachment locations, stable operation keys, server IDs when assigned, and per-step sync state. Drafts and attachment bytes must survive process death; temporary picker paths alone are insufficient.

Suggested local lifecycle:

```text
editing → ready → creating_server_draft → uploading → verifying → submitting → submitted
                            ↘ retry_needed / needs_sign_in / paused ↗
```

These are client operation states, separate from case statuses. Only an explicit submission action starts network transfer. Persist the outbox intent before sending requests. Initial implementation resumes in the foreground after explicit retry or continuation; background syncing is deferred.

Freeze a payload snapshot once submission starts. Retrying uses the same keys and snapshot. Editing an in-flight report requires a defined server-draft update/version flow; do not change a request while reusing an idempotency key. Offer pause rather than claiming transmitted data has been erased. A server-confirmed draft deletion operation is required to discard partially uploaded work remotely.

On timeout, reconcile the operation with the server before starting again. On `401`, retain the encrypted draft and require the same account to sign in. On sign-out, lock account-scoped drafts and clear credentials; explicitly offer local draft deletion. Report the limits of recovery if secure keys are lost or the application is uninstalled.

## 5. Backend changes and contract

Freeze the contract in `docs/API_CONTRACT.md` and an OpenAPI snapshot before Flutter's real-data integration. All routes below are target work unless explicitly marked existing.

| Method/path under `/api/v1` | Purpose |
|---|---|
| `POST /auth/login` (existing) | Issue access token; document expiry |
| `GET /auth/me` | Return authenticated account and role for safe session restoration |
| `POST /reports/drafts` | Create retry-safe server draft from the frozen payload |
| `GET /reports/{id}` | Owner-only timeline, evidence state, status/history, version |
| `DELETE /reports/{id}` | Owner-only deletion of an unsubmitted server draft, with eventual object cleanup |
| `POST /reports/{id}/evidence/upload-url` | Idempotently reserve an attachment/upload attempt |
| `POST /reports/{id}/evidence/{evidence_id}/complete` | Verify storage object and record completion |
| `DELETE /reports/{id}/evidence/{evidence_id}` | Remove an attachment from an unsubmitted draft |
| `POST /reports/{id}/submit` | Validate and atomically finalise the report; safe to repeat |
| `GET /cases/mine` (existing, extended) | Paginated submitted case summaries; keep server drafts out of this list |
| Officer queue/detail/status (existing, extended) | Filter submitted cases, enforce permissions, show history/evidence |
| `GET /officer/cases/{id}/evidence/{evidence_id}/download-url` | Case-scoped, audited access to verified evidence |
| Notification list/read (existing, extended) | Pagination and stable read semantics |

Use stable machine-readable error codes with field details and a request ID. Define `401`, `403`, hidden-resource `404`, state/idempotency `409`, oversized-payload `413`, validation `422`, and rate-limit `429`. Require timezone-aware timestamps and bounded, trimmed fields. Add pagination and deterministic ordering for lists.

Replace or disable the old immediate-submit routes once the Flutter flow takes over; leaving them active would bypass the new lifecycle. Review actual consumers first. Retire or gate the existing anonymous endpoint until its separate capability design is ready.

### Database and consistency

Introduce Alembic with a tested baseline for fresh databases and a reviewed upgrade/stamping procedure for any existing development database. Inspect data before migration; never reset an unknown database automatically.

Add evidence lifecycle fields (`reserved`, `uploaded`, `verified`, `rejected`, expiry, verified timestamp, immutable object version/reference), report submission time/version, status-history records, and durable operation records for idempotency. Scope idempotency to account and operation, store a canonical request hash, reject key reuse with a different payload, and handle database uniqueness races. Keys alone are never authorisation.

Finalisation must atomically check ownership, draft version, required fields, and all retained attachments, then record submission/history once. Ensure concurrent submit and evidence-removal requests cannot create an inconsistent report. Drafts must be excluded from officer queues, details, downloads, notifications, and pattern analysis.

Proposed case transitions:

```text
submitted → received → under_review → closed
                           ↕
                     action_required
```

Allow `action_required → under_review`; define who must act and what the student sees before enabling that state. No officer transition to `draft` or `submitted`. Treat repeated identical status updates as no-ops. Keep reopening closed cases out of the first release. Enforce optimistic concurrency so two officers cannot unknowingly overwrite status changes.

### Evidence integrity

Bootstrap a private bucket. Verify actual object existence, byte count, and SHA-256 server-side or using a storage-validated checksum; do not trust client metadata or treat an ETag as SHA-256. Inspect file content against allowed types and reject mismatches. Apply report/file limits and quotas, including cleanup of oversized or abandoned direct uploads.

Prevent a still-valid upload URL from overwriting already-verified evidence: pin a storage version or copy validated bytes to a final immutable key and serve that final object. Completion retries must return the same verified result. Short-lived signed URLs must be renewable for the same authorised operation without duplicating attachments.

Keep originals private, avoid filenames in object keys, and remove sensitive filenames/URLs from logs. Audit download URL issuance and distinguish it from proof that a file was downloaded. Real-case deployment additionally requires a quarantine/scanning policy. Add scheduled, idempotent cleanup for expired drafts and orphaned objects.

### Access, identity, and notifications

Document a role/action matrix for student, officer, and admin. A student sees only their own records. A proposed single-university demo may allow all officers to handle submitted cases; assignment-scoped access is a later explicit policy, not implied by the existing nullable assignment field.

Implement reporter identity visibility separately from report content access if identified/confidential modes are exposed as different promises. Existing response models omit reporter ID, but this alone does not establish a complete confidentiality policy. Audit any authorised identity access.

Keep the current short-lived access-token model for the first demo with clear reauthentication. Add refresh/revocation or university SSO later as a complete session lifecycle. Add login/submission throttling and redact credentials, narratives, tokens, and signed URLs from logs.

Record neutral notifications in the same transaction as a successful case transition. Prevent duplicate notifications on retries. Push delivery, if added later, uses an outbox with delivery retries and neutral payloads.

## 6. Officer dashboard and pattern alerts

Retain the static web dashboard and bring it to feature parity with the API: reliable sign-in expiry handling, filters/pagination, loading/error/empty states, case timeline, evidence metadata and download, status history, valid transition controls, and alert review. Catch save failures and refresh the selected case after a successful update.

Display only authorised submitted cases. Use safe text rendering for all report content. Keep session tokens out of persistent browser storage unless a reviewed session design replaces the current memory-only approach.

For pattern alerts, count unique authenticated reporters against a canonical staff reference. Exclude unknown references and anonymous submissions from the independence threshold. Define whether the 90-day window uses submission or incident time; use submission time for the initial implementation. Define which case statuses remain eligible rather than letting a status edit silently change the intended rule.

Replace the moving-window equality approach with one stable active review task per staff reference/rule, protected against concurrent duplicate creation. Store the underlying qualifying report references and evaluation timestamp. Specify what happens when more reports arrive after an alert is reviewed. Present “Reports requiring review”; never imply a finding or automatic sanction.

## 7. Ordered work packages and acceptance gates

Effort ranges are developer-days for focused engineering, including normal verification. Product feedback, unfamiliar Flutter tooling, and policy decisions can extend calendar time. Backend and UI work can overlap after the contract is frozen.

| Package | Depends on | Work and deliverable | Exit gate | Effort |
|---|---|---|---|---|
| P0 Baseline | None | Fetch/review remote history, compare duplicate folder, agree canonical repo and branch, verify SDK/toolchain, inventory any data, record decisions | Reproducible baseline and agreed platform/mode scope | 1–2 days |
| P1 UX and contract | P0 | Screen designs, component tokens, role matrix, state diagrams, OpenAPI target and example errors | Reviewed reporting journey and contract; unresolved policy features gated | 2–4 days |
| P2 Backend foundation | P1 | Migrations, bucket bootstrap, fictional users, auth/me, server drafts, detail, finalise, idempotency, draft filtering | Two students isolated; retry creates one case; officer cannot read draft | 3–5 days |
| P3 Flutter shell/local data | P1 | Routing/theme, sign-in UI, repository interfaces, secure-storage spike, encrypted durable draft editor and attachment copies | Draft survives restart/offline use; account isolation verified | 4–6 days |
| P4 First integrated slice | P2, P3 | Real login, no-file submission, server case list/detail, session recovery | Student submits once, officer sees same ID, timeout retry produces no duplicate | 2–3 days |
| P5 Evidence | P4 | Reservation, verified immutable object, cleanup, picker/progress/retry, dashboard evidence controls | Interrupted upload resumes safely; unauthorised access and overwrite attempts fail | 3–5 days |
| P6 Case handling | P5 | Transitions/history, dashboard state handling, in-app updates, corrected alerts | Officer update reaches student; retries do not duplicate notifications/alerts | 2–4 days |
| P7 Release rehearsal | P6 | Accessibility, adversarial integration tests, device performance, CI, APK, startup/reset/demo runbook | Full fictional journey passes on presentation device from a clean setup | 3–5 days |

Estimated total: 20–34 developer-days. A single developer should plan roughly 4–7 working weeks before contingency. Two collaborators can overlap P2/P3 and share testing; integration gates remain sequential. If constrained to three weeks, target P0–P5 with a small dashboard and basic in-app updates, defer pattern UI polish and all optional scope, and re-estimate after P0.

Suggested ownership: backend developer owns P2 and server portions of P5/P6; Flutter developer owns P3/P4 and mobile P5/P6; both own P1, integration acceptance, and P7. This allocation is a proposal, not an assumption about current availability.

## 8. Verification and definition of done

Use real PostgreSQL and MinIO in backend integration tests because the models use PostgreSQL UUID/JSONB and storage behaviours matter. Test Flutter controllers/repositories with deterministic fakes, widgets for visible states, and emulator/device journeys with the actual API. Flutter supplies [integration testing tools](https://docs.flutter.dev/testing/integration-tests) and [accessibility checks](https://docs.flutter.dev/ui/accessibility/accessibility-testing).

Required acceptance scenarios:

- Wrong password, malformed/expired token, inactive user, wrong role, and cross-student access are rejected appropriately.
- A local draft and selected attachment survive process death without a server request. Switching accounts cannot expose them.
- Same submission key and payload return the same report; different payload returns conflict. Concurrent retries and a lost success response produce one case.
- Server drafts remain inaccessible to officers, including direct-ID requests, evidence URLs, and aggregate alerts.
- Zero-file and multi-file submission work; missing, oversized, wrong-type, hash-mismatched, expired, and overwritten uploads cannot finalise as valid evidence.
- A student can recover after upload succeeds but the completion response is lost, or after finalisation succeeds but the app times out.
- Expired access tokens during upload/finalisation retain progress and require the original account to resume.
- Status transitions, concurrent officer edits, neutral notifications, and audit events are correct and retry-safe.
- Distinct reporters count once each; anonymous/unknown references do not inflate alerts; repeated evaluation does not create duplicate active tasks.
- Screen readers, enlarged text, small Android displays, keyboard overlap, loading states, and slow/offline networks are usable.
- API and signed storage addresses are reachable from both emulator and physical device; debug HTTP settings do not leak into a shared release configuration.

CI gates: backend test suite and migration checks; Flutter formatting, static analysis, unit/widget tests, and Android build. Run the real-service device journey at milestone/release gates. Publish an OpenAPI snapshot and ensure changes are reviewed with both clients.

Release bundle: installable APK, pinned toolchain/dependencies, fictional seed/reset procedure, environment setup guide, demo script, acceptance evidence, known limitations, and rollback steps. Do not mark the project integrated based only on widget tests or a successful APK build.

## 9. Follow-on scope

Anonymous reporting is a separate feature slice: high-entropy recovery capability with a stored verifier/hash, rate-limited lookup, no bearer identity attached, independent upload authorisation, deliberate code display/storage, and recovery/lost-code rules. Do not use a human-readable case ID or an idempotency key as access authorisation. Verify that logs and telemetry cannot silently reconnect anonymous submissions to an authenticated identity.

Later options: FCM/device-token lifecycle, account recovery or university SSO, iOS delivery, officer assignment, follow-up messaging, localisation, and user-controlled evidence export. Add these only with corresponding backend and acceptance work. AI allegation scoring, emergency dispatch, and in-app recording are outside this plan.

Before any real-case pilot, university owners must settle identity visibility, case handling responsibilities, support content, retention/deletion, and hosting/access policy. Then implement the resulting access rules, security review findings, monitoring, backup/restore rehearsal, incident procedures, and evidence scanning. This follows the existing project's fictional-demo boundary; it is not a prerequisite to building the prototype.

## 10. Git and documentation handoff

During P0, fetch current remote branches and inspect collaborator changes before establishing `feature/flutter-foundation` from the current FastAPI baseline. Reconcile the existing contribution guide's `develop` workflow explicitly: `develop` currently contains a different backend, so merging it wholesale would require an intentional backend choice. Preserve useful history and avoid forced updates to shared branches.

Keep `mobile/` working until Flutter meets P7. Compare the separate backend scaffold for useful differences, then document it as superseded; do not delete it during planning. Remove tracked IDE caches in a separate housekeeping change after review and extend ignore rules for Flutter-generated files.

Implement in small reviewable changes matching P0–P7, with backend contracts landing before dependent integration. Update the root README, backend/mobile instructions, `API_CONTRACT.md`, and `BACKEND_STRUCTURE.md` as behaviour changes. Mark the old three-week Compose plan as historical when implementation begins. Track each package with its acceptance gate, owner, and evidence of completion.

The first implementation session should complete P0 and produce the agreed P1 contract/design draft. The first functional milestone is one protected local Flutter draft becoming one server-confirmed case visible to an officer.
