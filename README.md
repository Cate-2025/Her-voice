# HERVOICE

Authors: Nawonga Catherine (24/U/09989/PS), Arinda Emmanuel Nsiimenta (24/U/03629/PS)

Project: HERVOICE — A Secure Mobile Platform for Reporting and Coordinating Support for Sexual Harassment in Universities

This repository contains the HERVOICE prototype (Android client + backend).

Start here: [three-week implementation plan](docs/IMPLEMENTATION_PLAN.md), then [API contract and integration gaps](docs/API_CONTRACT.md). The Android screen demo runs independently; the backend and dashboard still need local setup and fictional users.

Suggested branch strategy

- `main` (protected): release/production-ready
- `develop`: integration branch
- `feature/*`: feature branches (e.g. `feature/mobile-auth`)

Directory layout

- `mobile/` — Android application (collaborator work)
- `backend/` — FastAPI, PostgreSQL/MinIO services, and officer dashboard
- `docs/` — design docs, wireframes, interviews, and the delivery plan

Current backend progress

- Backend scaffold: auth, role checks, report/case schema, submission flow, officer endpoints, audit records, signed evidence URLs, generic in-app notifications, and an initial review-alert rule. See the plan for unfinished flows.
- Officer dashboard shell: `http://localhost:8000/admin` after running the backend.
- Plan: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
- Backend diagram reference: [docs/BACKEND_STRUCTURE.md](docs/BACKEND_STRUCTURE.md).
- API contract: [docs/API_CONTRACT.md](docs/API_CONTRACT.md).
- Android screen-flow starter: [mobile/README.md](mobile/README.md).

Next steps

- Follow the Week 1 checklist in the implementation plan.
- Create `feature/backend-foundation` and `feature/mobile-report-flow` branches, then integrate through `develop`.
