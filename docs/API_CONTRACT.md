# HERVOICE API Contract and Integration Gaps

The prefix is `/api/v1`. JSON requests use `Content-Type: application/json`; protected endpoints use `Authorization: Bearer <access_token>`. The current source of truth is `backend/app/routers/` and the generated `/docs` page when the API runs. This document distinguishes **implemented now** from **proposed before Android integration**.

## Implemented requests

### Login

`POST /api/v1/auth/login`

```json
{"email":"student@example.test","password":"fictional-password"}
```

Returns `{"access_token":"...","token_type":"bearer"}`. No registration, token refresh, or development seed account exists yet.

### Authenticated report

`POST /api/v1/reports` (student token)

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

Returns `201` and `id`, `report_mode`, `case_code`, `subject_staff_ref`, `course_ref`, `status`, `created_at`. Today status becomes `submitted` immediately. The same idempotency key returns the original report for the same student; the implementation does not yet check that a repeated payload is identical.

`POST /api/v1/anonymous-reports` uses the same body and no token. The API forces `report_mode=anonymous`, stores no reporter ID, and returns a case code. There is no case-code lookup or anonymous evidence path yet. This route needs abuse controls before real use.

The case code is currently stored in plaintext. Before building case-code lookup, store a verifier/hash instead and decide how lost codes are handled without deanonymising the student.

`GET /api/v1/cases/mine` returns only the authenticated student’s report summaries. It does not return timeline or evidence details. `GET /api/v1/notifications` returns neutral notification records; `POST /api/v1/notifications/{id}/read` marks one read.

### Officer

`GET /api/v1/officer/cases` returns report summaries. `GET /api/v1/officer/cases/{report_id}` adds timeline events. `PATCH /api/v1/officer/cases/{report_id}/status` accepts `{"status":"under_review"}`. Officer/admin roles are enforced. The current API accepts any enum status, including invalid backward transitions, so implement transition rules before integration.

`GET /api/v1/officer/pattern-alerts` lists internal alerts. `POST /api/v1/officer/pattern-alerts/{alert_id}/review` marks one reviewed. The current dashboard lists alerts but does not offer a review control.

### Evidence today

`POST /api/v1/evidence/reports/{report_id}/upload-url` is available only to the authenticated report owner. It accepts `original_name`, `content_type`, `byte_size`, and a 64-character hex `sha256`. It returns `evidence_id`, `object_key`, and `upload_url`. The client sends the bytes with HTTP `PUT` to `upload_url`, using the exact signed `Content-Type`.

The current API writes evidence metadata **before** upload, does not verify the object afterwards, does not create the bucket, and does not provide an evidence-list endpoint. `GET /api/v1/evidence/{evidence_id}/download-url` issues an officer/admin download URL but does not currently audit it. A signed URL can be used by whoever possesses it until expiry. Do not rely on this route for a real evidence demo until these gaps are closed.

## Proposed contract to freeze before Android integration

1. `POST /reports/drafts` creates a server draft only when the student explicitly starts online submission; the device’s offline draft remains local.
2. `POST /reports/{id}/evidence/upload-url` reserves an evidence record and returns a signed upload target.
3. Client `PUT`s bytes to object storage. It calls `POST /reports/{id}/evidence/{evidence_id}/complete`; API verifies the object and marks evidence `uploaded`.
4. `POST /reports/{id}/submit` validates the incident and completed evidence, changes status to `submitted`, and is safe to retry.
5. `GET /reports/{id}` returns the student’s own timeline/evidence and current status; `GET /officer/cases/{id}` includes the officer evidence list.
6. `GET /officer/cases/{id}/evidence/{evidence_id}/download-url` authorises and audits the officer’s access.

These six endpoints are **not implemented**. If the team chooses a simpler order, update this document and both clients before implementation. Do not invent a `/complete` call in the Android client against the current API.

## Error and retry decisions

- Use `401` for missing/expired authentication, `403` for a valid account with the wrong role, `404` for a resource hidden from that caller, `409` for an idempotency conflict or invalid state transition, `413` for oversized evidence, and `422` for malformed fields. Some current routes do not yet follow this exactly.
- Keep one random idempotency key per logical report through all retries. Never create a new key merely because the response timed out.
- Dates must be ISO 8601 with a timezone offset. The Android UI should use a date/time picker; avoid parsing free-text dates.
- Return a stable server case ID and explicit sync/upload states so the UI never displays a local draft as submitted.
- Define pagination before case queues grow; the prototype may use an unpaginated list with fictional data only.

## Network setup for development

Android emulator reaches a host API at `http://10.0.2.2:8000`; a physical device needs the host’s LAN address and a reachable firewall port. The currently generated MinIO signed URL uses its configured endpoint and must also be reachable by the Android client. A Docker-only hostname such as `minio` will not work on a phone. Development cleartext HTTP may require an Android debug network configuration; use HTTPS for any shared demo environment.
