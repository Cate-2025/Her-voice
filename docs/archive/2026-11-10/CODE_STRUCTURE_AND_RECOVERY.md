> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Code structure and recovery behaviour

Technical preparation dated 30 October 2026. This document describes current behaviour and the reason for each boundary. Administrative rules are not changed by this pass.

## Flutter responsibilities

- `report_models.dart`: drafts, attachment metadata, case display models, update models and date formatting. No data fixtures or network calls.
- `report_store.dart`: the screen-facing contract and ordinary in-memory editing. It starts empty. Production screens import this contract.
- `demo_store.dart`: fictional records and simulated submission only. Explicit preview selection constructs this store; it re-exports the contract for compatibility with existing preview tests.
- `connected_store.dart`: authenticated screen coordination, account generation/version guards, draft recovery, and the explicit submission lifecycle. It remains the coordinator; it is not an independent service locator or a replacement state framework.
- `draft_save_queue.dart`: serial, scope-aware encrypted metadata writes. A busy writer keeps the active write unchanged and coalesces consecutive queued snapshots for the same scope. A different scope is never merged. Waiters finish only when their snapshot or a newer one in that scope is saved; failure is propagated and subsequent writes can recover.
- `draft_vault.dart` and `encrypted_draft_vault.dart`: storage interface and Android AES-GCM implementation. File bytes are separate from metadata, keys come from platform secure storage and temporary writes are atomically renamed.
- `submission_intent.dart`: the deep-copied request body and stable server ID. This is a recovery record, not an automatic background job.
- `report_mapper.dart`: API detail to presentation conversion, without I/O.
- `api_client.dart`: HTTP/auth headers, error translation and paged list loading. It does not choose which account may see a case.
- `push_service.dart`: Android permission/provider interaction. The coordinator registers/revokes tokens against authenticated API access.

This is a bounded refactor, not a claim that every responsibility is fully extracted. Authentication and notification coordination remain in ConnectedStore because their generation guards protect pending account operations. Further extraction should have a concrete testable benefit rather than just moving methods between files.

## Draft lifecycle and write efficiency

A field edit produces a metadata snapshot bound to API URL plus account ID. Existing snapshots are never rebound to whichever account is active later. The queue writes one snapshot at a time; edits waiting behind a busy write replace the last queued same-scope snapshot. There is no timer delay. Explicit Save, sign-out UI and every submission checkpoint still await storage. Metadata snapshots are still encoded per edit; device CPU and latency need physical profiling before claiming broad performance gains.

Deterministic test: 200 edits plus an explicit final flush while the first write is blocked produce two writes, revisions 0 and 200, rather than 201 writes. The flush remains unresolved until the final revision is persisted. This is a controlled workload proving reduced redundant I/O, not a benchmark of Android storage speed or power use. Account-boundary and write-failure tests establish that coalescing does not combine accounts or falsely complete a failed save.

## Submission lifecycle

1. Validate sign-in, selected draft and required fields.
2. Freeze payload and a random operation key. Save this intent before any API side effect.
3. Create a private server draft. If the response is lost, retry the same payload and key. Persist the returned server ID before proceeding.
4. Read each encrypted attachment and upload with stable file ID, expected checksum and metadata. Server verifies owner, state, byte limit, type signature and storage read-back under the existing safeguards. A retry does not overwrite different evidence.
5. Explicitly submit the server draft. Then retrieve the confirmed case, save local completion and remove encrypted local copies where possible.
6. On failure, keep the frozen operation and offer explicit retry. No automatic submission occurs merely because a network returns.

Account generations prevent late asynchronous results from populating a later account's screen. Invalid tokens clear authentication while retaining recoverable drafts for the same account. A new login waits for outstanding writes before loading another account. API URL/account-ID changes select a different storage scope: use the planned migration process before switching hosted endpoints. Device uninstall or lost key can make local drafts unrecoverable.

## Case loading and limits

`/cases/mine`, `/officer/cases` and `/officer/pattern-alerts` accept limit 1 to 100 and non-negative offset; default is 100. Ordering adds a unique ID tie-breaker. All queries preserve their previous role/owner and draft exclusions. Clients follow pages to retain the current screen experience and full queue counts. Flutter overlaps at most four case-detail requests per batch instead of waiting for each one serially.

Limitations: the client still holds all loaded records; details are still one request per case; notification list/read-all remain unpaged. Offset pages are an eventually consistent view, not a frozen snapshot. A concurrent status change can move an item between pages; refresh again rather than interpreting a queue export as complete analytical evidence. Cursor pagination, lazy detail loading and server counts remain future capacity work if real volumes justify them.

## Backend access and transaction boundaries

Student endpoints check account ownership. Officer endpoints currently allow officer/admin roles broadly; assignment-scoped access is awaiting approved requirements. Identity release is admin-only and follows successful audit commit. Status changes lock the report, validate expected/current status and allowed transition, then create notification/outbox work in the transaction. Administrative status meanings and actions have not been changed.

Evidence upload buffers a bounded file and reads storage back while the report lock is held. This protects existing verification/idempotency but can increase lock time under slow storage. Runtime concurrency is capped in the container, storage calls have bounded timeouts, database connect/statement timeouts are explicit and S3 clients are reused. Aggregate memory, object-store throughput and high-concurrency acceptance still require measurement; streaming/quarantine is not silently introduced here.

Push delivery holds a row lock through the provider call; multiple API processes would each start a lifespan worker when enabled. Provider acceptance and DB commit cannot be one atomic transaction. Current retry logic therefore does not establish exactly-once phone delivery. Keep a single API process for the supplied starting deployment and review worker separation before scaling.

## Verification and operation

Backend tests run against an isolated temporary PostgreSQL cluster, never the personal prototype. Flutter tests cover encrypted restore, tampering, account switching, submission retries and the save queue. New loading tests verify bounded overlap and page traversal. Node tests exercise modal cancellation and confirmation against a stubbed browser surface, without modifying cases. They do not replace a real browser/accessibility acceptance pass.

Run backend checks from `backend`: `.venv/bin/python -m pytest -q`; run admin checks with `node --test tests/admin/status_confirmation.test.cjs`. Run Flutter checks from `flutter_app`: `flutter analyze` and `flutter test`. The optional live API test requires a separate fictional-data API and credentials; do not point it at real records. CI builds the image in addition to tests. The current local container-runtime permission limitation is documented in the independent backend runbook.


## Follow-up review on 1 November 2026

A failed sign-in from a previous account generation cannot clear the token of a newer session. Generation checks also stop old refresh and submission operations before issuing subsequent requests using a newer account's credentials. The admin HTTP helper rejects responses from an earlier session both after fetch and after asynchronous body parsing. These are client lifecycle protections; API ownership and role checks remain authoritative.

Paged loading rejects an identical repeated full page, preventing an older or misconfigured server that ignores offset from causing an endless loop. Offset pagination still does not provide a frozen snapshot during concurrent changes. Readiness now verifies the installed Alembic revision against the bundled migration heads as well as checking dependency access; merely accepting a PostgreSQL connection is insufficient.
