> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../../README.md).

# HERVOICE backend

FastAPI in `app/` is the active backend, and it also serves the officer/admin website at `/admin/`.

- **Deploy:** [one deployment guide](../DEPLOYMENT.md).
- **Run on the laptop:** [local testing reference](../PROTOTYPE_RUNBOOK.md).
- **Understand endpoints:** [API contract](../../../reference/API_CONTRACT.md).
- **Understand code and recovery:** [code structure](../CODE_STRUCTURE_AND_RECOVERY.md).

The sections below concern database history and developer tests; they are not additional deployment steps.

## Existing databases

Migration `0003` adds device registration and the durable Android push queue; configure it using [Android push setup](../ANDROID_PUSH_SETUP.md). Migration `0001` captures the original prototype schema; `0002` introduces account-scoped retry keys, request fingerprints, submission timestamps, and unverified evidence state. Migration `0004` adds email challenges, auth throttles and token versions. On an empty database, run `alembic upgrade head`.

If the old `create_dev_database.py` has already created tables, back up the database and compare it with revision `0001` before running `alembic stamp 0001`, then `alembic upgrade head`. Stamping is only appropriate for that exact baseline; it must not be used to conceal unknown schema differences. No existing database was modified during this refactor.

Legacy submitted cases keep their creation timestamp as the best available submission time. Legacy evidence is marked reserved and its metadata timestamp cleared because no upload was ever verified. Downloads remain blocked until a future revalidation flow exists. Downgrading `0002` refuses if different accounts share an idempotency key, because the original schema cannot represent that state; its legacy evidence timestamp reconstruction must not be treated as upload proof.

## Tests

```bash
pip install -r requirements-dev.txt
pytest -q
```

Tests start a temporary real PostgreSQL cluster using `pixeltable-pgserver`, migrate it, and discard its data. They override application database/storage settings and never use your `.env` database. No Docker or sudo is needed, but the environment must permit local process and socket creation. This test runtime is a development dependency only.

Current coverage: draft ownership/role isolation, concurrent retries/finalisation, payload conflicts, timezone validation, status rules, generic notification deduplication, evidence verification gating, fictional seeding, pattern reporter counting, fresh migration round trips, and legacy-data preservation. Live S3/MinIO integration and physical Flutter device acceptance still require the manual setup checks.

## Current limits

Server drafts contain a frozen complete payload; no remote edit/delete endpoint exists yet. Submission works with or without newly verified attachments. Legacy reserved evidence still blocks submission until explicitly revalidated. Anonymous intake is gated. Token refresh, institutional identity-access approval policy, assignment scope, broader API quotas/abuse controls, complete evidence lifecycle auditing, canonical staff references and verified production operations remain open. Bounded pagination and technical CI are implemented; hosted execution and provider acceptance remain pending. Use fictional records for this prototype.
