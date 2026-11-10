# HERVOICE backend

FastAPI in `app/` serves both `/api/v1` and the officer/admin website at `/admin/`.
PostgreSQL and private evidence storage are separate services.

- [Deployment, email, push, monitoring and recovery](../docs/DEPLOYMENT.md)
- [Local startup, tests, code boundaries and existing-database adoption](../docs/DEVELOPMENT.md)
- [API contract](../docs/reference/API_CONTRACT.md)
- [Acceptance record](../docs/RELEASE_CHECKLIST.md)

From this directory, install `requirements-dev.txt`, then run
`.venv/bin/python -m pytest -q` and `node --test tests/admin/*.test.cjs`.
Tests use an isolated temporary PostgreSQL cluster and require local process/socket
access. They do not target the personal `.env` database.

Use `alembic upgrade head` for an empty configured database. For an existing
database, follow the adoption guidance in [Development](../docs/DEVELOPMENT.md#existing-databases);
do not stamp a revision to bypass an unknown schema mismatch.
