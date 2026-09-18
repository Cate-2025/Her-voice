# Android application starter

The first Compose implementation is deliberately a screen-flow prototype. It includes sign-in, private case list, incident documentation, review, and submission confirmation. It currently uses in-memory demo data rather than a network client.

## Screen flow

```text
Sign in → Private records → Document incident → Review → Submitted case list
                              ↖ Save draft       ↙ Edit
```

The next Android work should replace the demo actions in `MainActivity.kt` with the backend contract:

1. Login with `POST /api/v1/auth/login`; store the short-lived token securely.
2. Store a protected local report draft before any network call.
3. Agree on the draft → upload → verify → submit API flow in [API_CONTRACT.md](../docs/API_CONTRACT.md). The current `POST /api/v1/reports` submits immediately; there is no upload-complete endpoint yet.
4. Keep one idempotency key across retries and display the server-confirmed case ID only after a successful response.
5. Refresh `GET /api/v1/cases/mine` and `GET /api/v1/notifications` after successful sync.

The prototype pins AGP 8.10.1, Gradle 8.11.1, Kotlin/Compose compiler 2.0.21, Compose BOM 2024.12.01 and Activity Compose 1.9.3. It compiles and targets API 36 with Java/Kotlin bytecode set to 17. Keep this combination together: newer Compose releases may require a newer AGP and compile SDK.

Open `mobile/` in Android Studio, select JDK 17 for Gradle, sync, and run the `app` configuration on an emulator or device running Android 8 or newer. Choose **Continue with demo account** to try the reporting screens; no backend is needed. Reports exist only in memory and demo submissions do not reach an officer.
