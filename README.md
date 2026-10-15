# HERVOICE

Authors: Nawonga Catherine (24/U/09989/PS), Arinda Emmanuel Nsiimenta (24/U/03629/PS)

Project: HERVOICE — A Secure Mobile Platform for Reporting and Coordinating Support for Sexual Harassment in Universities

The consolidated first prototype uses the redesigned Flutter Android client with FastAPI and PostgreSQL. Start with the [prototype runbook](docs/PROTOTYPE_RUNBOOK.md) and [comparison with the original plan](docs/CONSOLIDATION_REVIEW.md).

## Supported components

- `flutter_app/`: connected student client; sign-in, incident submission without files, current case status and in-app updates. The earlier fictional UI preview is opt-in.
- `backend/`: FastAPI, PostgreSQL migrations, role/owner checks, officer web dashboard and backend tests.
- `mobile/`: legacy Compose screen-flow reference.
- `legacy/main/`: preserved Node backend, older connected Flutter/Android work and scripts from the other branch. These are historical references, not a second active stack.
- `docs/`: current runbook, consolidation review, API contract and earlier design plans.

## Prototype limits

Use fictional data. Authentication and unsubmitted drafts are memory-only on the client; submitted reports persist on the server. Verified evidence upload, encrypted durable offline storage/synchronisation, registration/recovery, anonymous reporting and push/SMS are not complete. The report submission screen explicitly explains access and sends data only after confirmation.

This is the first connected reporting/case-coordination milestone, not completion of the original concept paper. See the requirement-by-requirement comparison and verification results in the linked documents.
