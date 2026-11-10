> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# HERVOICE documentation — start here

## Deploy the demo

**Read [DEPLOYMENT.md](DEPLOYMENT.md).** It is the only deployment walkthrough: choose a route, prepare database/storage/email, deploy the API, verify it, then build the Android app. Every stage includes an expected result.

Use [MANUAL_TESTING_CHECKLIST.md](MANUAL_TESTING_CHECKLIST.md) to record whether the deployed system actually works.

You do not need the documents below to begin. Open one only for the named task.

## Optional references

| Task | Reference |
| --- | --- |
| Understand folders and component roles | [Project map](PROJECT_MAP_AND_DEMO_PLAN.md) |
| Run/debug on this laptop, adb connection or local service rehearsal | [Local testing](PROTOTYPE_RUNBOOK.md) |
| Set up monitoring, backup/restore or later updates | [Backend operations](INDEPENDENT_BACKEND_RUNBOOK.md) |
| Configure Firebase and test Android delivery | [Push details](ANDROID_PUSH_SETUP.md) |
| Understand email verification/reset and SMTP behaviour | [Email details](EMAIL_ACCESS_SETUP.md) |
| Prepare Android signing and release upgrades | [Release signing](ANDROID_RELEASE.md) |
| Review officer-web and Android usability findings | [UI audit](UI_DASHBOARD_AUDIT.md), [mobile review](UI_DASHBOARD_AUDIT.md#mobile-flow-review-and-corrections--10-november-2026) |
| Understand API endpoints or code/recovery behaviour | [API contract](../../reference/API_CONTRACT.md), [code structure](CODE_STRUCTURE_AND_RECOVERY.md) |
| Answer administrative/v1 questions | [Stakeholder workbook](v1-planning/HERVOICE_V1_Readiness_and_Decisions.docx) — its original technical snapshot predates later changes |

## Progress records and historical plans

These explain decisions and previous work; **they are not deployment checklists**. Dated test results do not establish the current cloud/device acceptance state.

- `TECHNICAL_PREPARATION_PROGRESS.md`, `GAP_BRIDGING_PROGRESS.md`, `PROTOTYPE_UPDATE_RUNDOWN.md`, `UI_DASHBOARD_AUDIT.md`: dated implementation/review records.
- `IMPLEMENTATION_PLAN.md`, `IMPLEMENTATION_PROGRESS.md`, `FLUTTER_IMPLEMENTATION_PLAN.md`, `FLUTTER_UI.md`, `BACKEND_STRUCTURE.md`: earlier design/development references. Older limitations may have been superseded.
- `CONSOLIDATION_REVIEW.md`, `REQUIREMENTS_COMPLETION_AND_BI.md`: historical branch/requirements comparisons.
- `EXTERNAL_SERVICES_SETUP.md`: retained as a redirect to the consolidated deployment guide.
- `openapi.json`: generated API reference; `ui-audit/` and `ui-preview/`: saved UI artifacts.
