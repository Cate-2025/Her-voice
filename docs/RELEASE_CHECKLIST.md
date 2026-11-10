# HERVOICE — release checklist and acceptance record

Consolidated 10 November 2026. All checks below are **not yet run** unless a tester records a result. Use fictional accounts, incidents and evidence in a separate test environment. Automated tests do not establish device, browser or provider acceptance.

## Record the build first

Record date, tester, phone/Android version, browser/version, APK filename and SHA-256, API URL, server revision and migration revision. Keep results against this exact combination; capture screenshots without credentials or real allegations.

Do not assume a desktop APK matches the reviewed source; record its build identity. Build/install a fresh APK before testing them; follow [Android signing](DEPLOYMENT.md#android-signing) for release signing and HTTPS. Do not uninstall or clear app data when testing draft recovery or upgrades. Draft storage is scoped to both account and API URL, so changing the URL is not a same-install recovery test.

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
| Android notifications | If push is in the approved scope, configure Firebase and test permission denial, enable/disable, foreground/background delivery, notification tap and sign-out/account switch. No sensitive report text should appear on the lock screen. Provider acceptance alone does not prove delivery. | Not run; defer explicitly if push is excluded |
| Browser usability | Test narrow viewport, long text, empty lists and errors. Navigate sign-in, report details and confirmation with keyboard; confirm focus and readable buttons. | Not run |
| Hosted independence | On the staging host, validate HTTPS, API/proxy startup, migrations and initial admin. Reboot the host; verify recovery and use the app without the development laptop. | Blocked until host configured |
| Operations | Exercise dependency failure alerts, backup and full restore of database plus evidence, and rollback using the runbook. Confirm restored evidence and records agree. | Blocked until services configured |
| Signed upgrade | Install the intended signed build, save a draft, then update with the same signing identity and API URL. Confirm draft recovery and normal sign-in. | Blocked until signing configured |

Record failures with reproduction steps, expected/actual result, build identity and sanitised logs. Mark a blocked or unavailable check explicitly; it is not a pass. Resolve data loss, cross-account exposure, duplicate submissions and inability to sign in/submit before expanding a pilot. Policy-dependent workflow acceptance still awaits administrative decisions.


## Launch decision

A controlled fictional-data demo may exclude push if Updates works and that
exclusion is recorded. Do not mark skipped checks as passed. Before a real-report
pilot, resolve the identity, case-handling, evidence and retention decisions in
[Decisions](DECISIONS.md). Sign-in/data loss, cross-account exposure, duplicate
submission and inaccessible evidence failures must be corrected before rollout.

| Release record | Fill in |
| --- | --- |
| Purpose, environment, cohort and size | Pending |
| Included features / explicit exclusions | Pending |
| Hosted service acceptance evidence | Pending |
| Device/browser and signed-upgrade evidence | Pending |
| Restore and operator handover evidence | Pending |
| Open issues, mitigation and acceptance owner | Pending |
| Approver, decision and date | Pending |
| Demo/pilot end date and review date | Pending |

## Known verification baseline

The latest local UI pass recorded 74 Flutter tests passed, one optional live-API
test skipped, static analysis clean, debug APK build/install and a successful
phone-to-local-API readiness check. These results do not fill the hosted/provider,
accessibility or operational rows above. See [Description](DESCRIPTION.md#verification-and-deployment-position)
for the dated scope. No new application tests were run for the documentation move.


## Hosted API check — 10 November 2026

Render Free service Her-voice is live at https://her-voice-e2mu.onrender.com,
revision `e879424`, deployment `dep-dbphl9rrjlhs73fv4lu0`.
Public `/health`, `/ready` and `/admin/` returned HTTP 200 after private
Neon/database/JWT/bucket settings were applied. The private bucket separately
passed synthetic upload/read/delete and rejected anonymous access with 403.
Mail and push are deliberately disabled. User sign-in and the complete hosted
student/officer journey, independent phone build, signed upgrades and operational
restore checks remain to execute; no credentials were used to sign in for this pass.


## Hosted Android build — 10 November 2026

Built with `HERVOICE_API_BASE_URL=https://her-voice-e2mu.onrender.com/api/v1`.
Flutter static analysis: no issues. Debug APK compiled; hosted URL verified in
its compiled kernel. Installed using `adb install -r` on TECNO CK6 and launched;
no uninstall/data clear. Copied to `/home/emmaa/Desktop/HERVOICE-hosted-debug.apk`.
SHA-256: `e60c695c32906047551ea40e5198b67dfb8a3aeb29d2ac4f6e8dea0ffbfe8055`.

The Android Studio profile and app default both use the hosted URL; explicit
Dart defines still permit local testing. Drafts from the local account/API scope
remain separate. No hosted student sign-in/submission was performed. Neon admin
credentials belong to the web dashboard, not the student-only Android sign-in.
Registration/reset delivery remains unavailable until mail is configured.


## Hosted operator journey — owner-run verification

The owner ran `scripts.provision_test_accounts` through private terminal prompts
and reported successful creation of student/officer test accounts, hosted sign-in,
evidence integrity, officer identity omission, status progression and read-all.
Retained fictional report: `64d291c6-07b9-429c-8a40-7068bcb5c054`.
This is owner-reported operator-script evidence, not a completed phone UI or
accessibility acceptance pass. No passwords or tokens were shared in chat.
