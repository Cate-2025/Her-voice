> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Android phone notifications: configuration and test guide

The code is implemented, but live Firebase delivery has **not** been verified: no HERVOICE Firebase project or credentials were available for this pass. Without project configuration the app still builds, sign-in and in-app updates still work, and Updates explains that phone notifications need setup.

## 1. Create and register the Android app

1. Create a project in the [Firebase console](https://console.firebase.google.com/). Google Analytics is not required for this implementation.
2. Add an Android app with the exact package **`com.hervoice.hervoice`**.
3. Download its `google-services.json` to **`flutter_app/android/app/google-services.json`**. This file must come from your project; there is no placeholder to edit.
4. Ensure the Firebase Cloud Messaging API is enabled for the project. Use the same project for the app and sending service account.
5. In Android Studio, open `flutter_app`, fetch dependencies, stop the running app and run it again. Hot reload cannot incorporate native Firebase configuration. The Google services Gradle plugin is already configured and is applied only when the JSON file exists.

The Android configuration identifies the Firebase project; it is different from the private server key. Both project-local paths below are ignored by Git. See [Firebase Android setup](https://firebase.google.com/docs/android/setup).

## 2. Configure the server

Use a service account permitted to send FCM messages in that project. For a local prototype, download its JSON private key through Firebase Project settings → Service accounts. Keep it on the server, for example at `/home/emmaa/Work/Her-voice/backend/.secrets/firebase-admin.json`, with owner-only read permissions. Never put this key in Flutter assets, `google-services.json`, source control, or chat. On hosted infrastructure, prefer a managed service identity instead of a downloaded key. See [Firebase server authentication](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

Stop the existing API from the terminal/IDE session that started it. Then:

```bash
cd /home/emmaa/Work/Her-voice/backend
.venv/bin/python -m pip install -r requirements-dev.txt
export GOOGLE_APPLICATION_CREDENTIALS="$PWD/.secrets/firebase-admin.json"
export PUSH_ENABLED=true
.venv/bin/python -m scripts.run_prototype
```

The existing runner preserves the database and existing passwords, applies migration `0003` and starts the API. Use your original seeded password. With push enabled, an in-process worker checks the delivery queue every five seconds. There is no separate worker command to run.

`GOOGLE_APPLICATION_CREDENTIALS` must be exported in the server process environment (or configured as an IDE/service environment variable). Merely putting it in `.env` does not export it to the Firebase SDK. `PUSH_ENABLED` can be set in the environment or backend `.env`; its default is false. Invalid/missing credentials with push explicitly enabled fail server startup instead of pretending push is running.

For a manually managed PostgreSQL setup, apply `.venv/bin/alembic upgrade head` before starting Uvicorn. For Docker, mount the service account file read-only and supply its **container** path through `GOOGLE_APPLICATION_CREDENTIALS`, plus `PUSH_ENABLED=true`. Do not bake the key into an image.

The Android app keeps using the existing HERVOICE login/API. Firebase Authentication, Firestore and Analytics are not required by this feature. The server and phone need Internet access to Firebase; wireless debugging only provides the local connection to your API.

## 3. Enable from Android Studio / your phone

You can continue launching the app from Android Studio. For the physical phone and local API:

- Keep the wireless-debugging device connected.
- Reapply `adb reverse tcp:8000 tcp:8000` if the connection was lost.
- Keep the run configuration argument `--dart-define=HERVOICE_API_BASE_URL=http://127.0.0.1:8000/api/v1`.
- Sign in as the student, open **Updates → Enable on this device**, and allow Android notification permission. If previously denied, enable it in Android Settings → Apps → HERVOICE Prototype → Notifications, then retry.

Android 13+ requires runtime notification permission. Use a physical device with Google Play services, or a Google Play-enabled emulator. See [Firebase Flutter prerequisites](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## 4. Acceptance checklist (pending your Firebase setup)

Use fictional records and the seeded accounts.

- [ ] With Firebase absent, the app opens and Updates shows the setup explanation.
- [ ] With Firebase configured, enable notifications and allow permission; Updates reports device registration.
- [ ] Submit a fictional report. On `/admin/`, change Submitted → Received using the confirmation dialog.
- [ ] With the app in the background, verify a notification titled **HERVOICE** with **“You have a new update. Open HERVOICE to view it.”** There should be no student name, report ID, staff reference, narrative or status in the payload.
- [ ] Tap it: Updates opens; a cold start requires sign-in first because app credentials remain memory-only.
- [ ] With the app in the foreground, another valid officer status change refreshes in-app data. No separate foreground system banner is implemented.
- [ ] Mark all updates read, refresh, and verify they stay read. This marks server updates read; it does not clear already displayed Android tray notifications.
- [ ] Disable phone notifications, then make another valid status change: the in-app update remains available and no new push should be sent to the revoked device.
- [ ] Sign out, enable under another student test account, and confirm the previous account's updates do not arrive.
- [ ] Deny permission and test loss of connectivity: reports and in-app updates should remain usable when the API is reachable.

Android force-stop prevents delivery until the app is reopened. Notification taps and foreground/background behavior follow [Firebase message handling](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages). OS/network delivery is best-effort, not an emergency channel.

## Implemented behavior and limits

- Status change, student notification and per-device delivery queue entries commit together. Failed push attempts do not roll back case progress or remove in-app updates.
- The worker rechecks device ownership, active user/device status and whether an update is already read. It skips ineligible deliveries, retries transient failures up to five attempts with backoff, and disables invalid tokens. `sent` means Firebase accepted the request, not that a person saw it.
- Delivery is at least once: a process failure after provider acceptance but before commit can repeat an attempt. A stable Android notification tag reduces duplicate tray entries. Provider TTL is one hour after sending.
- Enabling affects future status changes, not historical notifications. Existing unread queued updates can be sent when the worker resumes.
- The client renews changed FCM tokens, revokes the prior token and retires its token on disable/sign-out. A fresh process retires the previous session's token; enable again after sign-in. Both server revocation and Firebase token deletion require connectivity. If both fail, generic notices can continue; use Android notification settings to stop previews immediately. Already delivered notices can remain in the tray.
- The app name remains visible. This is confidential reporting with restricted identity access, not anonymous reporting. Firebase receives the device routing token and neutral notification, not incident content.
- Flutter Firebase Core 4.x / Messaging 16.x and Firebase Admin 7.1 are used for the registration-token protocol. A future upgrade to Messaging 17's registration API needs a coordinated client/server review.
- This pass implements Android only. iOS/web push, delivery monitoring dashboards, token/queue retention policies, multi-stage identity approval and production operations remain outside this pass.

For diagnostics, inspect aggregate queue states (`pending`, `sent`, `skipped`, `failed`) in `push_deliveries` and server warnings. Do not copy device tokens or private credentials into logs. A running `/health` endpoint alone does not prove Firebase delivery.
