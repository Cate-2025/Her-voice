# HERVOICE Backend Structure Reference

Use this document as the source for an architecture diagram. Solid arrows below are implemented interfaces; proposed arrows are labelled. See [API_CONTRACT.md](API_CONTRACT.md) for exact routes and current gaps.

## Diagram level one  System context

```text
Student Android application ── REST ──> HERVOICE API <── REST ── Officer web dashboard
       │                                             │
       │                                             ├── PostgreSQL
       └── signed URL upload ──> Private object storage
                                                     └── FCM (proposed, not implemented)
```

**External actors:** student, authorised safeguarding officer, administrator.

**Trust boundaries:**

1. The Android app and web browser are untrusted clients. They authenticate to the API; neither connects to PostgreSQL. The Android app can transfer evidence directly to storage only with a short-lived URL issued by the API.
2. The API is intended to enforce roles, ownership, audit logging, privacy rules, and signed evidence access. Some audit and evidence checks are still missing; see the implementation plan.
3. PostgreSQL holds structured records and metadata. Private object storage holds evidence bytes.
4. Push is proposed. If added, it should receive only a generic notification trigger, with no allegation text, names, case identifiers, or status wording.

## Diagram level two  API internals

```text
                  ┌─────────────────────────────────────┐
HTTPS request ───> │ FastAPI API                          │
                  │  Auth router  → token + role checks   │
                  │  Report router → create/case list     │
                  │  Evidence router → short-lived URLs   │
                  │  Officer router → queue/status/alerts │
                  │  Notification router → in-app updates │
                  └───────────────┬───────────────────────┘
                                  │
                 ┌────────────────┼─────────────────┐
                 ▼                ▼                 ▼
          PostgreSQL         S3/MinIO           FCM adapter
          transaction        private bucket     proposed only
```

## Components and responsibilities

### Source tree

```text
backend/
 ├─ app/main.py                 route registration, dashboard static mount, health check
 ├─ app/config.py               settings loaded from environment
 ├─ app/database.py             SQLAlchemy engine and session dependency
 ├─ app/models.py               PostgreSQL table definitions
 ├─ app/schemas.py              API request and response models
 ├─ app/security.py             Argon2 password checks, JWT, role dependencies
 ├─ app/routers/                auth, reports, evidence, officer, notifications
 ├─ app/services/               signed storage URLs and pattern rule
 ├─ app/static/admin/           browser dashboard HTML, CSS and JavaScript
 ├─ scripts/create_dev_database.py  local table creation only
 ├─ docker-compose.yml          PostgreSQL and MinIO services
 └─ requirements.txt            Python dependencies
```

For a component diagram, group `routers`, `security`, and `services` inside the API box. Draw `models/database` as the connection to PostgreSQL and `services/storage.py` as the connection to object storage. The dashboard static files run in the officer browser after FastAPI serves them.

| Component | Owns | Must not do |
|---|---|---|
| `routers/auth.py` | login and access-token issue | disclose whether an account exists on failed login |
| `security.py` | Argon2 verification, JWT validation, role dependencies | use client-side role claims without fetching an active user |
| `routers/reports.py` | authenticated/anonymous report intake, idempotency, student’s case list | decide whether an allegation is true |
| `routers/evidence.py` | owner check for upload, MIME/declared-size check, signed URLs | claim an upload completed before the object is verified |
| `routers/officer.py` | officer queue/detail/status and alert review | expose anonymous reporter identity |
| `services/patterns.py` | current 90-day threshold based on exact staff reference | treat anonymous submissions or typed names as verified independent matches |
| `routers/notifications.py` | in-app generic notification history | send sensitive push text |
| `AuditLog` | officer access/change trail | act as a general event store for private mobile drafts |

## Storage map

```text
PostgreSQL
 ├─ users              account email, Argon2 password hash, role, active state
 ├─ reports            mode, nullable reporter link, staff reference, status, assignment
 ├─ timeline_events    date/time, location hint, incident narrative
 ├─ evidence           private object key, type, size, SHA-256, original name
 ├─ notifications      generic in-app update record
 ├─ audit_logs         officer action, report reference, time, safe metadata
 └─ pattern_alerts     staff reference, count, 90-day window, reviewer

Private object storage
 └─ reports/{report_id}/{evidence_id}
    └─ private provider object named by UUID; encryption at rest must be configured and verified
```

## Core data flows for arrows in your diagram

### A  Authenticated student report

1. Android app will send credentials to `POST /api/v1/auth/login` once connected. Its current sign-in is a local demo screen.
2. API verifies Argon2 password hash and returns a short-lived JWT.
3. The planned Android app will prepare a protected offline draft; this is not implemented yet.
4. Current API: a student sends a report and idempotency key to `POST /api/v1/reports`.
5. API validates the student role, creates a `submitted` report plus timeline entries, then evaluates the review-alert rule.
6. Current evidence route can issue a signed upload URL after the report exists. It stores metadata before the file is transferred and has no completion check.
7. Current `GET /api/v1/cases/mine` and `GET /api/v1/notifications` exist, but Android does not call them yet. The desired draft → upload → verify → submit sequence is specified in the API contract.

### B  Anonymous report

1. A client can send an intentional anonymous request to `POST /api/v1/anonymous-reports` with no authentication token. Android has no screen for this yet.
2. API stores no `reporter_id` and returns a randomly generated case code.
3. A future Android screen must ask the student to retain the case code. The API has no case-code lookup, anonymous evidence upload, or anonymous two-way message channel.

### C  Officer review and notification

1. Officer signs in and requests `GET /api/v1/officer/cases`.
2. API checks `officer`/`admin` role, returns the queue, and writes an audit log.
3. Officer opens a case or changes its status; API audits that action.
4. Where there is an identified/confidential reporter, API creates an in-app generic notification. FCM has not been implemented.

### D  Internal review alert

1. A submitted or actively reviewed case reaches the rule service.
2. Current service counts unique authenticated reporters plus each anonymous submission with the same exact staff reference during the last 90 days. This does not prove independence or identity of a staff member. The plan changes the rule before the integrated demo.
3. At three or more, it creates/updates a `PatternAlert` visible to authorised reviewers only.
4. An officer marks the alert reviewed. The alert remains a review prompt, not a conclusion.

## API ownership matrix

| Endpoint group | Student | Officer | Admin | Anonymous caller |
|---|---:|---:|---:|---:|
| Login | yes | yes | yes | no |
| Create report | yes | no | no | separate anonymous endpoint |
| My cases / notifications | own records only | no | no | no |
| Evidence upload | own identified/confidential report only | no | no | no |
| Officer case queue/detail/status | no | yes | yes | no |
| Evidence download URL | no | yes, unaudited today | yes, unaudited today | no |
| Pattern alerts | no | yes | yes | no |

## Deployment shape

For local development: Docker Compose defines PostgreSQL and MinIO, while FastAPI is intended to run on the developer machine. The supplied `.env.example` currently uses Docker service hostnames, so it needs host addresses before this topology will run. The bucket and fictional users also need creation. For the diagram, show the API as a separate service between clients and both stores.

For a real deployment: place API, database, and object storage in the institution-approved network/account; terminate TLS at an approved gateway; keep the database and bucket private; use managed secrets; introduce Alembic migrations, backups, retention jobs, malware scanning, monitoring, university SSO/MFA, and a security review.

## Diagram legend language

Use these exact labels where possible:

- “HTTPS REST API with role-based access control”
- “PostgreSQL case and metadata database”
- “Private evidence object storage”
- “Short-lived signed upload/download URLs”
- “Generic in-app notification” (push proposed)
- “Internal rule-based review alert”
- “Encrypted offline drafts on device” (proposed, not yet implemented)

Avoid labels such as “guilty lecturer detection,” “anonymous but traceable,” or “public evidence storage.”
