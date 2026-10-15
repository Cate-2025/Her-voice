# HERVOICE API contract — Flutter foundation

Updated 12 October 2026. Prefix `/api/v1`; JSON requests and bearer authentication. Current implementation source: `backend/app/routers/`; generated schema: `/openapi.json`; checked-in snapshot: [openapi.json](openapi.json). This contract describes the first refactor milestone, not the full target in [FLUTTER_IMPLEMENTATION_PLAN.md](FLUTTER_IMPLEMENTATION_PLAN.md).

## Session

`POST /auth/login` accepts `{"email":"student@example.test","password":"your-fictional-password"}` and returns `access_token`/`token_type`. Access tokens expire after the configured period (30 minutes by default). There is no refresh, registration, or password recovery endpoint yet.

`GET /auth/me` returns `id`, `email`, and `role`. The first connected Flutter milestone holds its token only in memory; platform-backed persistence is future work. Reauthenticate on `401`; retain the current in-memory draft for same-account reauthentication. Encrypted durable drafts are not implemented.

## Draft → submit (implemented, without attachments)

Create a server draft only when the student explicitly starts online submission. Ordinary draft saving remains local in the future Flutter client.

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

`GET /reports/{id}` returns the owner's report summary, timeline, and evidence metadata/state. Another student's report returns `404`; an officer using this student route gets `403`. No signed storage URLs or reporter identity are included in this response.

`POST /reports/{id}/submit` has no body. It locks the report, verifies incident presence and evidence readiness, and commits `status=submitted` with `submitted_at`. Retrying returns the same report and timestamp; if an officer has subsequently changed the status, the response returns that current status. Keep the original server ID after a lost success response.

`GET /cases/mine` returns submitted case summaries only. Server drafts are excluded. Pagination and status history remain planned.

The former `POST /reports` returns `410` with replacement instructions. `POST /anonymous-reports` returns `503` while anonymous capabilities/recovery are unimplemented. The authenticated draft route rejects `report_mode=anonymous`. Identified and confidential enum values remain accepted; a distinct identity-visibility policy has not yet been implemented.

## Evidence: incomplete lifecycle, integration deferred

The existing `POST /evidence/reports/{report_id}/upload-url` reserves an attachment only on an owned server draft. It accepts `original_name`, allowed `content_type`, positive `byte_size`, and hex `sha256`, and returns `evidence_id`, `object_key`, and `upload_url`.

Reservation records `verification_status=reserved` and no upload timestamp. A file PUT is not verification. There is **no completion endpoint yet**, so a report with reserved evidence cannot be finalised. Use the no-attachment flow for the first milestone. The future lifecycle must verify bytes and protect verified objects from overwrite before enabling attachment submission.

The legacy officer download route returns `404` for draft evidence and `409` for unverified evidence. Migrated evidence is unverified until explicitly revalidated in a future migration/tool. Bucket setup, completion, cleanup, idempotent reservation, and case-scoped download audit remain required.

## Officer cases

Existing routes: `GET /officer/cases`, `GET /officer/cases/{id}`, `PATCH /officer/cases/{id}/status`. Officer/admin role required; drafts are hidden, including direct-ID requests.

Status payload: `{"status":"received"}`. Allowed transitions:

```text
submitted → received → under_review → closed
                           ↕
                     action_required
```

Repeated identical status is a no-op. Invalid/backward transitions return `409`. The existing case action is audited and produces one neutral notification for each successful status change. Full history, stale-version conflict handling, assignment-scoped access, and officer evidence listings are later work. Product wording for `action_required` still requires review before exposing it in Flutter.

## Notifications and alerts

`GET /notifications` and `POST /notifications/{id}/read` remain available. No FCM sender or device-token registration exists. Notification previews use neutral text.

Pattern alerts count distinct authenticated reporters over 90 days based on submission time (legacy records fall back to creation time), including submitted cases later closed. Drafts and anonymous reports are excluded. Evaluation serialises per staff reference and reuses an active unreviewed task. Matching still relies on free-text staff references; canonical matching and legacy duplicate-alert reconciliation remain planned. Alerts require human review and do not establish misconduct.

## Errors and development networking

Current errors use FastAPI's `detail` response: `401` missing/expired authentication, `403` wrong role, `404` hidden/absent resource, `409` conflicting operation/state, `422` malformed fields. Stable machine-readable error codes/request IDs and rate limiting are future work. Current evidence size/type rejection may use `400`; align to the target contract during evidence implementation.

Android emulator API: `http://10.0.2.2:8000`; physical device: a reachable host LAN address. Signed storage URLs must also be reachable from that device. Docker-only names such as `minio` cannot be used by a phone. Shared environments require HTTPS; permit cleartext only in isolated development builds.
