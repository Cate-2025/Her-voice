# Backend quick start

This is the intended authority for users, reports, cases, evidence metadata, notifications, audit records, and internal review alerts. The officer dashboard calls its REST API. Android currently runs a screen demo and has not been connected. Read [the API contract](../docs/API_CONTRACT.md) before integration.

## Run locally

```bash
cp .env.example .env
docker compose up -d postgres minio
python -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=. python scripts/create_dev_database.py
uvicorn app.main:app --reload
```

Before running the table-creation command, edit `.env`: change the database host `postgres` to `localhost`, the storage endpoint `http://minio:9000` to `http://localhost:9000`, and replace the development JWT secret. Those service names work only inside the Compose network; this README runs Python on the host. The current Compose passwords and `.env.example` values match as starter values; change both together for any shared setup. The MinIO bucket `hervoice-evidence` must be created separately. No seed-user command exists yet, so login and the dashboard cannot be exercised until fictional users with Argon2 password hashes are inserted. These are Week 1 tasks, not completed setup steps.

Visit `http://localhost:8000/docs` for generated route documentation and `http://localhost:8000/admin` for the dashboard shell. The current signed URL uses the storage endpoint configured for the API; an Android emulator or phone must also be able to resolve and reach that endpoint. Local HTTP access may need Android debug network configuration.

## Current API surface

- `POST /api/v1/auth/login`
- `POST /api/v1/reports` and `POST /api/v1/anonymous-reports`
- `GET /api/v1/cases/mine`
- `POST /api/v1/evidence/reports/{report_id}/upload-url`
- `GET /api/v1/evidence/{evidence_id}/download-url` (officer/admin)
- `GET/PATCH /api/v1/officer/cases...` (officer/admin)
- `GET /api/v1/officer/pattern-alerts` (officer/admin)
- `GET /api/v1/notifications`

The upload route records metadata and signs a URL, but does not confirm the object was uploaded. The officer case detail does not list evidence. There is no FCM integration, migration tool, seed command, or automatic bucket setup yet. The dashboard currently offers case status controls but no assignment or alert-review controls.

Do not expose this development configuration publicly. The current table creation script is intentionally local-only; introduce reviewed Alembic migrations, university SSO/MFA, production secret management, malware scanning, retention jobs, and monitoring before deployment.
