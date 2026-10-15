# Consolidation update — 15 October 2026

The two branch histories are consolidated around Flutter/FastAPI. The first connected student-to-officer journey is implemented; see [the comparison and decisions](CONSOLIDATION_REVIEW.md) and [runbook](PROTOTYPE_RUNBOOK.md). The previous milestone notes below are historical; the default Flutter build now sends explicitly submitted reports to the configured server. Evidence uploads and durable offline storage remain unfinished.

# Flutter migration progress

## 12 October 2026 — backend foundation slice

Branch: `feature/flutter-foundation`, based on `backend` at `162380c`. Remote history was fetched and matched the reviewed local history. No commits were pushed and no existing application database was changed.

### Completed in this slice

- Authenticated server draft creation and owner-only timeline/evidence detail.
- Explicit finalisation without attachments, stable submission timestamps, and retry recovery after officer processing.
- Account-scoped idempotency keys, canonical payload fingerprints, conflict rejection, and concurrent retry handling.
- Draft exclusion from student submitted lists and officer queues, direct case access, status actions, evidence downloads, and pattern evaluation.
- Timezone-aware incident validation and whitespace trimming.
- `/auth/me` for session identity restoration.
- Allowed officer transitions, repeated-status no-ops, and dashboard error handling/valid status options.
- Evidence reservation state distinct from upload verification; unverified attachments block finalisation and downloads.
- Distinct authenticated reporter counting and serialised reuse of active pattern-review tasks.
- Frozen Alembic baseline and upgrade, legacy-case preservation, guarded downgrade, and a development-only fictional account seed command.
- Updated API/setup documentation and OpenAPI snapshot. Earlier Compose documents are labelled historical/reference material.

### Verification

Verification result: **13 tests passed** against a real temporary PostgreSQL instance. Tests cover draft privacy, role/ownership checks, concurrent draft creation and finalisation, conflicting retry content, validation, legacy-route retirement, evidence gating, status/notification deduplication, account identity/login, migration round trips/schema agreement, legacy-data preservation, demo seeding, and pattern counting. JavaScript syntax and Git whitespace checks also pass.

Tests use a temporary user-local PostgreSQL runtime because Docker daemon access requires administrator privileges on this machine. No MinIO bytes were transferred. The officer UI was syntax-checked but has not been visually exercised. Flutter/device builds have not run.

### Milestone status

| Package | State | Remaining work |
|---|---|---|
| P0 baseline | Partial | Flutter installed; Android toolchain verification, collaborator confirmation, platform/mode choices remain |
| P1 design/contract | Partial | UI design and contract foundation implemented; review, role policy, unknown-subject/date decisions remain |
| P2 backend foundation | Partial | Draft edit/delete/cleanup, complete workflow history/version conflicts, error envelope, rate limits, pagination |
| P3 Flutter shell/local data | Partial | Responsive screens and session editing implemented; encrypted durable persistence remains |
| P4 integrated slice | Preview only | Backend no-file path exists; Flutter API integration and device journey remain |
| P5 evidence | Gating only | Verified/immutable upload, completion, idempotent reservation, cleanup, bucket bootstrap, downloads/audit |
| P6 case handling | Partial | Student history/updates UI, full officer evidence/alert controls, canonical matching and legacy alert reconciliation |
| P7 release | Partial | Web preview builds and widget checks pass; CI, device/accessibility acceptance, APK and rehearsal remain |

### Compatibility changes

`POST /reports` now returns `410`; use `POST /reports/drafts` then `POST /reports/{id}/submit`. Anonymous intake returns `503` until its separate recovery/capability flow is implemented. Existing evidence is migrated to unverified state rather than assumed uploaded. The Compose app remains a local demo and is unaffected by these server routes.

### Next implementation slice after the backend foundation

1. Configure/pin Flutter and Android tools and create `flutter_app/` alongside `mobile/`.
2. Review the screen design, reporting mode explanation, unknown-subject handling, and uncertain incident dates.
3. Implement routing/theme, login, repository interfaces, and a verified encrypted local-draft store.
4. Integrate the no-file reporting journey with this API and test on an emulator/physical device.
5. Complete server draft deletion/recovery and verified evidence lifecycle before enabling attachments in submission.

Keep [FLUTTER_IMPLEMENTATION_PLAN.md](FLUTTER_IMPLEMENTATION_PLAN.md) as the delivery roadmap; this log records actual progress rather than marking entire phases complete early.

## 12 October 2026 — Flutter UI preview

Implemented the responsive Flutter shell and themed components, home, draft/case lists, incident editor, date/time picker, optional system file selection/removal, review/consent, simulated confirmation, case progress/detail, neutral updates, support guidance, welcome, and simulated sign-in. Lora/Manrope fonts and HERVOICE vector branding are bundled.

Flutter 3.47.7 / Dart 3.13.5 is installed in the workspace, with SDK version and dependency lockfile recorded. Android and web scaffolds are present. The web release build passes; `flutter analyze` reports no issues; 30 widget tests pass, including narrow/enlarged-text layouts and the complete demo journey. Browser screenshots were inspected and saved under `docs/ui-preview/`.

P1 now has an implemented visual design to review. P3 has the UI shell and session editing, but encrypted persistent data is still pending. P4 remains a simulated UI journey; no API calls are made by the app. Native Android build/device verification remains pending because Java/toolchain configuration is incomplete. Read [FLUTTER_UI.md](FLUTTER_UI.md) and [flutter_app/README.md](../flutter_app/README.md) for launch instructions, design decisions, and limitations.

### Next after the UI preview

Review the running UI, resolve required-field/policy decisions, and implement encrypted account-scoped draft storage before wiring real authentication and submission. Confirm Java/Android tools, then run on an Android device.
