# HERVOICE

Authors: Nawonga Catherine (24/U/09989/PS), Arinda Emmanuel Nsiimenta (24/U/03629/PS)

Project: HERVOICE — A Secure Mobile Platform for Reporting and Coordinating Support for Sexual Harassment in Universities

This repository contains the HERVOICE prototype (Android client + backend).

Start here: [Flutter redesign and implementation plan](docs/FLUTTER_IMPLEMENTATION_PLAN.md), [implementation progress](docs/IMPLEMENTATION_PROGRESS.md), then [current API contract](docs/API_CONTRACT.md). The Android screen demo runs independently. The backend now supports a protected server draft → submit flow without attachments, Alembic migrations, and fictional user seeding; see its setup instructions. An interactive Flutter UI preview now lives in `flutter_app/`; it uses explicitly fictional, session-only data.

Suggested branch strategy

- `main` (protected): release/production-ready
- `develop`: integration branch
- `feature/*`: feature branches (e.g. `feature/mobile-auth`)

Directory layout

- `flutter_app/` — new Flutter student UI ([run instructions](flutter_app/README.md))
- `mobile/` — legacy Compose screen-flow reference
- `backend/` — FastAPI, PostgreSQL/MinIO services, and officer dashboard
- `docs/` — design docs, wireframes, interviews, and the delivery plan

Current backend progress

- Backend scaffold: auth, role checks, report/case schema, submission flow, officer endpoints, audit records, signed evidence URLs, generic in-app notifications, and an initial review-alert rule. See the plan for unfinished flows.
- Officer dashboard shell: `http://localhost:8000/admin` after running the backend.
- Current plan: [docs/FLUTTER_IMPLEMENTATION_PLAN.md](docs/FLUTTER_IMPLEMENTATION_PLAN.md).
- Earlier Compose delivery plan: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
- Backend diagram reference: [docs/BACKEND_STRUCTURE.md](docs/BACKEND_STRUCTURE.md).
- API contract: [docs/API_CONTRACT.md](docs/API_CONTRACT.md).
- Flutter UI design: [docs/FLUTTER_UI.md](docs/FLUTTER_UI.md).
- Android screen-flow starter: [mobile/README.md](mobile/README.md).

Next steps

- Follow the ordered packages and acceptance gates in the Flutter plan.
- Work currently begins on `feature/flutter-foundation` from the FastAPI `backend` baseline; reconcile the divergent `develop` branch before integration.
