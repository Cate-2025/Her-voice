> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Prototype update rundown — 17 October 2026

This records the four changes requested after the original prototype review. The earlier [requirements and BI assessment](REQUIREMENTS_COMPLETION_AND_BI.md) remains the historical baseline; it has not been silently rewritten to imply all original requirements are complete.

| Request | Implemented in this pass | Remaining external work / limits |
|---|---|---|
| Read all on Updates | Account-scoped “Mark all as read”, unread count, disabled/busy action; failed requests leave unread data intact | Android tray notifications are separate from read status |
| System notification access | Android permission/enable control, Firebase initialization, authenticated device registration/revocation, persistent server queue and retries, foreground refresh and notification-tap routing | Create/configure Firebase and complete the phone acceptance checklist in [Android setup](ANDROID_PUSH_SETUP.md); real delivery not yet verified |
| Officer dashboard and update clarity | Responsive queue, status filters and counts, date labels, status explanations, legal next-step selection, confirmation dialog and stale-status protection | Officer assignment scopes and a fuller investigation/follow-up interface remain future work. “Action required” sends a generic update; it does not deliver specific instructions |
| Human-readable case names | `Report · 17 Oct 2026` with submission time on cards and detail; full reference available in case details | Multiple reports can share a date/time label. The original unique reference remains the authoritative identifier; no stored records were renamed |
| Student identity hidden from officers | Existing officer responses omit identity; new admin-only identity reveal requires a reason, records an audit entry before returning account email, and disables response caching | Account-linked confidentiality, not true anonymity. Narratives/attachments can identify people. Admin role is broad; institutional authority, audit review, retention and stronger approval controls still need definition |

## Run the updated prototype

1. Restart the backend with the existing prototype runner; it applies the new migration and preserves records/passwords. An already running API will not pick up these Python changes automatically. Do not reset/reseed passwords to fix a connection error.
2. Stop and rerun Flutter from Android Studio to load native dependencies. Keep the physical-device API URL and ADB reverse mapping described in the [runbook](PROTOTYPE_RUNBOOK.md).
3. Open `/admin/` in the browser and refresh it to load the dashboard assets.
4. Phone notifications can stay unconfigured while testing the other changes. Follow [Android push setup](ANDROID_PUSH_SETUP.md) when ready.

## Review steps

- Submit a fictional report and check its date/time label in Home, Records and confirmation.
- Sign into the web dashboard as `officer@example.test`: filter/select it, read the next-status explanation, cancel a change once and then confirm it.
- Refresh the student app: check current status and the neutral update; mark all read and refresh again.
- Officers must not see the account-email reveal control. Sign in as `admin@example.test`, open a submitted case, expand controlled identity access and provide a reason. The account email should appear only after the recorded access succeeds. A short/blank reason must fail.
- Complete the separate Firebase checklist before calling phone delivery verified.

## Business intelligence implications

Report IDs and submitted timestamps remain stable for later aggregation. Date labels are presentation only. Status-change audit entries support later workflow analysis, but the student app still shows current status rather than full status history. Pattern alerts count distinct reporting accounts and request human review; they do not establish misconduct or independent verified reporters.

Notification read timestamps indicate a user action in the app. Queue `sent` counts indicate provider acceptance. Neither proves that a student read case content or that a concern was resolved. Identity-access audit events record actor, report, time and reason; routine BI should aggregate these and restrict raw reasons/identities. No BI dashboard or analytics export was added.

## Verification for this pass

Passed: 23 backend tests against isolated PostgreSQL; 44 Flutter tests including the live Flutter-to-API acceptance journey; Flutter static analysis with no issues; Android debug APK build without Firebase configuration; Git whitespace check. The test API was stopped after verification. Your existing prototype database/server were not migrated or restarted during this pass. Dashboard JavaScript receives a syntax check; visual browser review could not run because no browser surface was available in this session. Firebase project setup and actual device delivery remain pending.

The build reports a Firebase Core Kotlin Gradle compatibility warning for future Flutter versions. The current build succeeds; review plugin compatibility before upgrading Flutter. The backend test runner also reports an existing Starlette/httpx deprecation warning.
