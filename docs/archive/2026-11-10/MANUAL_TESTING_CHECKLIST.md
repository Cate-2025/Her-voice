> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Manual acceptance checklist

Prepared 1 November 2026. All checks below are **not yet run** unless a tester records a result. Use fictional accounts, incidents and evidence in a separate test environment. Automated tests do not establish device, browser or provider acceptance.

## Record the build first

Record date, tester, phone/Android version, browser/version, APK filename and SHA-256, API URL, server revision and migration revision. Keep results against this exact combination; capture screenshots without credentials or real allegations.

The existing desktop APK predates the latest fixes. Build/install a fresh APK before testing them; follow ANDROID_RELEASE.md for release signing and HTTPS. Do not uninstall or clear app data when testing draft recovery or upgrades. Draft storage is scoped to both account and API URL, so changing the URL is not a same-install recovery test.

Restart the development server normally to load current code, applying required migrations to the test database first. Check `/health` and `/ready`; the latter requires current migrations and reachable storage/database. For local wireless debugging, verify the phone is connected and `adb reverse tcp:8000 tcp:8000` is present when the app uses `http://127.0.0.1:8000/api/v1`. Recheck after reconnecting. A hosted HTTPS build should reach its server without Android Studio or adb.

## Test in this order

| Check | Steps and expected result | Result / evidence |
| --- | --- | --- |
| Account access | Register using a test mailbox, enter the received code, sign in and reset the password. Wrong/expired codes fail clearly. Verify the former password no longer signs in. Real email delivery requires SMTP setup. | Not run |
| Session isolation | Sign in as student A, load records and updates, then sign out and sign in as B. No A records/drafts appear for B. Repeat during a slow request. | Not run |
| Durable draft | As A, save a draft with fictional evidence. Close/reopen the app and sign in again; text and attachments remain. Repeat after a phone reboot and after sign-out. | Not run |
| Submission recovery | Start a submission, interrupt connectivity, then restore it and retry the saved submission. Repeat after closing/reopening the app. Exactly one submitted report exists, with the intended evidence. | Not run |
| Storage trouble | On a dedicated test device/profile, simulate unavailable storage if practicable. Failed saving must be visible and must not silently send an unpersisted submission. After recovery, retry saving. Do not fill a personal phone to perform this check. | Not run / unavailable |
| Evidence | Test supported file types, an unsupported file, an oversized file and five-file limit. Accepted files download intact through authorised access. Another student cannot read them. Use valid harmless fixtures. | Not run |
| Officer privacy | Open the report as an officer: student account identity is absent. An officer cannot invoke administrator identity access. Narrative/evidence can themselves identify someone; check handling separately with stakeholders. | Not run |
| Administrator disclosure | With an authorised administrator, reveal identity with a reason; verify the audit record. Missing reason and unauthorised requests fail. Use fictional identity only. | Not run |
| Status confirmation | Open a status update; cancel leaves it unchanged. Reopen and confirm using pointer and keyboard. It changes once, and a stale second-browser update is rejected clearly. | Not run |
| Student updates | Confirm the dated report and new status appear for the submitting student. Read one update and read all; reopen/reload to verify read state persists. | Not run |
| Android notifications | Once Firebase is configured, test permission denial, enable/disable, foreground/background delivery, notification tap and sign-out/account switch. No sensitive report text should appear on the lock screen. Provider acceptance alone does not prove delivery. | Blocked until configured |
| Browser usability | Test narrow viewport, long text, empty lists and errors. Navigate sign-in, report details and confirmation with keyboard; confirm focus and readable buttons. | Not run |
| Hosted independence | On the staging host, validate HTTPS, API/proxy startup, migrations and initial admin. Reboot the host; verify recovery and use the app without the development laptop. | Blocked until host configured |
| Operations | Exercise dependency failure alerts, backup and full restore of database plus evidence, and rollback using the runbook. Confirm restored evidence and records agree. | Blocked until services configured |
| Signed upgrade | Install the intended signed build, save a draft, then update with the same signing identity and API URL. Confirm draft recovery and normal sign-in. | Blocked until signing configured |

Record failures with reproduction steps, expected/actual result, build identity and sanitised logs. Mark a blocked or unavailable check explicitly; it is not a pass. Resolve data loss, cross-account exposure, duplicate submissions and inability to sign in/submit before expanding a pilot. Policy-dependent workflow acceptance still awaits administrative decisions.
