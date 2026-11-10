# HERVOICE

Authors: Nawonga Catherine (24/U/09989/PS), Arinda Emmanuel Nsiimenta (24/U/03629/PS)

HERVOICE is an Android platform for confidential university incident reporting,
evidence submission and support, with a browser workspace for officers and administrators.
The active application is `flutter_app/` plus FastAPI `backend/` and PostgreSQL.

## Review the project

| Read | Purpose |
| --- | --- |
| [Description](docs/DESCRIPTION.md) | What exists, file map, boundaries and current readiness |
| [Deployment](docs/DEPLOYMENT.md) | Host the API independently, configure services and distribute Android |
| [Development](docs/DEVELOPMENT.md) | Run locally, connect Android Studio and understand/test the code |
| [Release checklist](docs/RELEASE_CHECKLIST.md) | Record hosted/device/provider and operational acceptance |
| [Decisions](docs/DECISIONS.md) | Stakeholder questions and approved v1/pilot scope |

See the [documentation index](docs/README.md) for technical reference and archive.

The application has local regression/build evidence and is ready to attempt a
controlled fictional-data hosted demo. Independent deployment/provider acceptance
and real-report handling approval are separate checks, not established by a
successful localhost build.

`mobile/` and `legacy/main/` preserve earlier implementations; they are not a
second active deployment stack. Product and visual-system contracts remain in
[PRODUCT.md](PRODUCT.md) and [DESIGN.md](DESIGN.md).
