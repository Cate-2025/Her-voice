# HERVOICE API reference

Maintained 10 November 2026. Prefix `/api/v1`; JSON requests and bearer
authentication. Implementation source: `backend/app/routers/`; checked-in
[OpenAPI snapshot](../openapi.json). The schema endpoint `/openapi.json` is
development-only; hosted staging/production disable public schema/Swagger routes.
This reference includes the later officer-workspace contracts. Current scope is
in [Description](../DESCRIPTION.md); earlier plans are in the [archive](../archive/README.md).

## Session

`POST /auth/login` accepts `{"email":"student@example.test","password":"your-fictional-password"}` and returns `access_token`/`token_type`. Access tokens expire after the configured period (30 minutes by default). Email verification and password reset are described below. Refresh tokens remain unimplemented. Password reset revokes existing tokens using the account token version.

`GET /auth/me` returns `id`, `email`, and `role`. Flutter holds its token only in memory. Android drafts and evidence are encrypted locally and recover after same-account authentication. Reauthenticate on `401`; pending operations retain their original payload and key.

## Draft → verified evidence → submit

Create a server draft only when the student explicitly starts online submission. Ordinary draft saving remains local in Flutter.

`POST /reports/drafts` (student token):

```json
{
  "report_mode": "confidential",
  "subject_staff_ref": "STAFF-DEMO-01",
  "course_ref": "COURSE-DEMO",
  "idempotency_key": "b4b37ee1-f0f0-470e-9875-3a1885f6c701",
  "timeline": [{
    "occurred_at": "2026-09-18T10:30:00+03:00",
    "location_hint": "Campus building",
    "narrative": "Fictional demonstration event."
  }]
}
```

Returns `201` with `id`, `report_mode`, `case_code` (null for authenticated reporting), `subject_staff_ref`, `course_ref`, `status=draft`, `created_at`, and `submitted_at=null`. Server draft creation requires complete incident fields; partial offline editing is a client responsibility. Timestamps require timezone offsets. Whitespace-only required fields fail validation.

The key is scoped to the authenticated account. Same key and canonical payload return the original report, including after finalisation. Same key with different content returns `409`. Equivalent timezone representations are canonicalised to UTC. Keep the payload snapshot and key stable through retries. Concurrent creation is protected by a database uniqueness constraint.

`GET /reports/{id}` returns the owner's report summary, timeline, evidence metadata/state and `status_history` (status and occurrence time only). Another student's report returns `404`; an officer using this student route gets `403`. No signed storage URLs or reporter identity are included in this response.

`POST /reports/{id}/submit` has no body. It locks the report, verifies incident presence and evidence readiness, and commits `status=submitted` with `submitted_at`. Retrying returns the same report and timestamp; if an officer has subsequently changed the status, the response returns that current status. Keep the original server ID after a lost success response.

`GET /cases/mine` returns submitted case summaries only. Server drafts are excluded. Pagination is implemented; see the list and officer-workspace contracts below. Dated history is included in report detail, derived from submission time and committed transition audit records.

The former `POST /reports` returns `410` with replacement instructions. `POST /anonymous-reports` returns `503` while anonymous capabilities/recovery are unimplemented. The authenticated draft route rejects `report_mode=anonymous`. Identified and confidential enum values remain accepted; account identity is excluded from officer case views and has a separate audited admin-only reveal endpoint.

## Verified evidence

`PUT /evidence/reports/{report_id}/files/{evidence_id}` accepts raw bytes with bearer authentication, `Content-Type`, `X-Evidence-Name` (URL-encoded filename), and `X-Evidence-SHA256`. The client creates and durably retains a UUID for each file before upload. The owner must be a student and the report a draft; at most five files of 10 MiB each are accepted. Content length, format signature, checksum and storage read-back are verified before committing evidence as verified.

Successful same-ID/same-metadata retries return the existing record, including after report submission. Changed metadata conflicts with 409. Verified keys are server-controlled and separate from legacy signed upload keys. There is no browser/device requirement to reach an S3 URL: the API streams authenticated data to/from storage. Local prototype storage and S3-compatible storage are supported; only the local implementation has integration acceptance in this pass.

`GET /evidence/{id}/file` requires officer/admin access to a submitted case and verified evidence. It rechecks the checksum, records `evidence_download_authorized`, and returns an attachment with `Cache-Control: no-store` and `nosniff`. Officer case detail includes evidence metadata. Assignment-scoped access is still future work.

Legacy upload/download URL endpoints are retired with 410 after their existing access/state checks. Legacy reserved files remain unverified. Malware scanning, retention/orphan cleanup and production storage operation remain pending.

## Officer cases

Existing routes: `GET /officer/cases`, `GET /officer/cases/{id}`, `PATCH /officer/cases/{id}/status`. Officer/admin role required; drafts are hidden, including direct-ID requests.

Status payload: `{"status":"received"}`. Allowed transitions:

```text
submitted → received → under_review → closed
                           ↕
                     action_required
```

Repeated identical status is a no-op. Invalid/backward transitions return `409`. The existing case action is audited and produces one neutral notification for each successful status change. Dated student history, stale-status conflict checks and officer evidence listings are implemented. Assignment-scoped access and explicit student follow-up remain later work. Specific student instructions for `action_required` still need an agreed follow-up workflow.

## Notifications and alerts

`GET /notifications` and `POST /notifications/{id}/read` remain available. Android FCM delivery and device registration are implemented; configuration is described in the push guide. Notification previews use neutral text.

Pattern alerts count distinct authenticated reporters over 90 days based on submission time (legacy records fall back to creation time), including submitted cases later closed. Drafts and anonymous reports are excluded. Evaluation serialises per staff reference and reuses an active unreviewed task. Matching still relies on free-text staff references; canonical matching and legacy duplicate-alert reconciliation remain planned. Alerts require human review and do not establish misconduct.

## Errors and development networking

Current errors use FastAPI's `detail` response: `401` missing/expired authentication, `403` wrong role, `404` hidden/absent resource, `409` conflicting operation/state, `422` malformed fields. Evidence size rejection uses 413, signature/checksum rejection 422, storage/mail unavailability 503 and auth throttling 429. Stable machine-readable error codes/request IDs and broader API quotas remain future work.

Android emulator API: `http://10.0.2.2:8000`; physical phone with adb reverse: `http://127.0.0.1:8000/api/v1`. See [Development](../DEVELOPMENT.md#2-connect-android-studio). Current evidence transfers use the API; retired signed-URL flows are not required for new clients. Shared environments require HTTPS; permit cleartext only in isolated development builds.


## October 2026 prototype updates

- `POST /api/v1/notifications/read-all`: authenticated, marks only the current account's unread notifications; returns the full account notification list. Existing read timestamps are preserved.
- `POST /api/v1/notifications/devices/register`: student-only; body `{ "token": "<FCM registration token>" }`. Registers/reassigns this device token to the signed-in account. Tokens are never returned by the API.
- `POST /api/v1/notifications/devices/revoke`: authenticated; same body; revokes only a token currently owned by this account. Repeated revocation is harmless.
- `POST /api/v1/officer/cases/{id}/reporter-identity`: admin-only, submitted cases only; body `{ "reason": "Authorised reason (10–500 characters)" }`. Commits `reporter_identity_viewed` audit entry before returning `{ "email": "..." }`, with `Cache-Control: no-store`. Normal officer/admin case responses still omit reporter identity.
- Status PATCH accepts optional `expected_status`; changed nonmatching status returns 409. Repeating the already-current target remains a no-op. Status changes create an in-app notice and per-device push queue entries in the same transaction.

See [push configuration and lifecycle](../DEPLOYMENT.md#android-push-configuration). The account identity restriction does not anonymize narrative content or remove the account link from storage. The generated [OpenAPI](../openapi.json) includes these additions.


## Email registration and recovery

`POST /auth/email-code` accepts `{ "email": "person@example.org", "purpose": "register" }` or purpose `reset`. With mail delivery configured it returns a generic message; no code is returned. All domains are currently allowed. Resend and source-address limits apply.

`POST /auth/email-code/complete` accepts email, purpose, an eight-digit code and a 12–128-character password. Valid registration creates only a student. Valid reset changes the existing password, increments its token version and revokes registered push devices. Codes expire after 15 minutes, allow five wrong guesses and are single-use. Email-delivery setup and limitations: [email configuration](../DEPLOYMENT.md#email-delivery-details).

## Technical preparation on 30 October 2026

Student case summaries (`GET /cases/mine`), officer queues (`GET /officer/cases`) and pattern alerts (`GET /officer/pattern-alerts`) retain list response bodies and now accept `limit` (1–100, default 100) and `offset` (minimum 0). Follow pages until fewer than `limit` rows are returned. Ordering includes an ID tie-breaker. Offsets are not a consistent snapshot under concurrent updates; clients should refresh and must not use this as a reconciled export. Update older clients that assumed a complete unbounded response before releasing against datasets larger than 100 items.

`GET /health` remains process liveness. `GET /ready` is unauthenticated dependency readiness, returns `{ "status": "ready" }` or HTTP 503 `{ "status": "unavailable" }`, and never returns infrastructure exception details. Hosted environments disable public Swagger/OpenAPI routes; regenerate the checked-in contract in development mode for review.

## Officer workspace refinement — 10 November 2026

The existing list endpoints remain compatible. The web workspace now uses these officer/admin-only endpoints:

- `GET /officer/case-page`: `{ "items": [OfficerReportResponse], "total": N }`. Supports `limit` (1–100, web uses 25), `offset`, `status_filter`, exact `staff_ref`, and inclusive timezone-aware `window_start`/`window_end` on submission time (creation time for legacy records). Drafts are excluded even if requested as a status. Invalid/reversed/naive windows return 422. Ordering is submission time descending then ID, so ordinary status edits do not move unfiltered rows. Filtering and concurrent insert/status changes still make offset pages a live view, not a reconciled snapshot/export.
- `GET /officer/case-summary`: `{ "total": N, "submitted": N, "under_review": N, "alerts": N }`. Counts all non-draft reports across queue filters and all unreviewed alerts; it is not the number on the loaded page. It returns no student identities.
- `GET /officer/alert-page`: `{ "items": [PatternAlertResponse], "total": N }`, unreviewed alerts only, bounded `limit`/`offset`, creation time descending then ID. Includes recorded window dates for read-only drill-through.

Related-report navigation filters the queue by the alert's exact staff reference and recorded time window. Its report count can differ from the alert's distinct-account count. It neither acknowledges nor resolves an alert. Those administrative actions remain a separate decision.

The UI bounds requests/body decoding (20 seconds, 60 for downloads), does not automatically repeat uncertain PATCH requests, and reloads details before offering another status choice. A timeout is not proof that the server did not commit. Queue, summary and alerts load independently and expose loading/stale feedback. Deploy the updated API and static assets together; no database migration is needed for these endpoints.
