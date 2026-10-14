# HERVOICE backend — Flutter foundation

FastAPI is the canonical backend. The separate `../hervoice-backend/` folder is an older, incomplete scaffold. Read [the current contract](../docs/API_CONTRACT.md) and [Flutter implementation plan](../docs/FLUTTER_IMPLEMENTATION_PLAN.md).

## Local setup

```bash
cp .env.example .env
# Edit .env as described below before running the API.
docker compose up -d postgres minio
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
alembic upgrade head
PYTHONPATH=. python scripts/seed_demo_users.py
uvicorn app.main:app --reload
```

For host-run Python, set the database host to `localhost` and storage endpoint to `http://localhost:9000`. Keep database/storage passwords consistent with Docker Compose and replace the JWT secret. The seed script prompts for a fictional password of at least 12 characters and creates `student@example.test`, `officer@example.test`, and `admin@example.test`. It runs only in development and never changes existing accounts or passwords. `HERVOICE_DEMO_PASSWORD` can supply the password through the environment for local automation; do not commit it.

The no-attachment draft/submission flow does not require MinIO. Evidence operations additionally require a private `hervoice-evidence` bucket and reachable signed URLs; automatic bucket setup and verified attachment completion are not implemented yet.

API docs: `http://localhost:8000/docs`. Officer dashboard: `http://localhost:8000/admin`.

## Existing databases

Migration `0001` captures the original prototype schema; `0002` introduces account-scoped retry keys, request fingerprints, submission timestamps, and unverified evidence state. On an empty database, run `alembic upgrade head`.

If the old `create_dev_database.py` has already created tables, back up the database and compare it with revision `0001` before running `alembic stamp 0001`, then `alembic upgrade head`. Stamping is only appropriate for that exact baseline; it must not be used to conceal unknown schema differences. No existing database was modified during this refactor.

Legacy submitted cases keep their creation timestamp as the best available submission time. Legacy evidence is marked reserved and its metadata timestamp cleared because no upload was ever verified. Downloads remain blocked until a future revalidation flow exists. Downgrading `0002` refuses if different accounts share an idempotency key, because the original schema cannot represent that state; its legacy evidence timestamp reconstruction must not be treated as upload proof.

## Tests

```bash
pip install -r requirements-dev.txt
pytest -q
```

Tests start a temporary real PostgreSQL cluster using `pixeltable-pgserver`, migrate it, and discard its data. They override application database/storage settings and never use your `.env` database. No Docker or sudo is needed, but the environment must permit local process and socket creation. This test runtime is a development dependency only.

Current coverage: draft ownership/role isolation, concurrent retries/finalisation, payload conflicts, timezone validation, status rules, generic notification deduplication, evidence verification gating, fictional seeding, pattern reporter counting, fresh migration round trips, and legacy-data preservation. MinIO transfer verification and Flutter device tests are not part of this milestone.

## Current limits

Server drafts contain a frozen complete payload; no remote edit/delete endpoint exists yet. Submission works without attachments. Reserved evidence blocks submission because completion verification has not landed. Anonymous intake is gated. Token refresh, pagination, student status history, identity-visibility policy, assignment scope, rate limiting, full evidence auditing, canonical staff references, CI, and production operations remain in the plan. Use fictional records for this prototype.
