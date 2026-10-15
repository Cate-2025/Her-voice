# HERVOICE Flutter client

The default app is now connected to FastAPI. Follow the [prototype runbook](../docs/PROTOTYPE_RUNBOOK.md) for backend startup, student credentials, Android networking and acceptance checks. Use fictional incident details. Authentication and local drafts are memory-only; submitted reports persist on the server. Connected evidence uploads are disabled until verification is implemented.

The following notes describe the retained **disconnected design preview**, enabled with `--dart-define=HERVOICE_DEMO=true`. Commands below must include that flag to reproduce preview behaviour. The default build must not be described as sending no data.

An interactive, Android-first interface alongside the legacy Compose app in `../mobile/`. The web target is a convenient design preview, not a separate product commitment.

**This build is an explicit fictional preview.** It makes no API calls. Drafts and selected attachment metadata live only in memory and reset on reload/restart. Authentication and submission are simulated; selected file bytes are never uploaded. Do not use real incident details or credentials in this preview.

## Run

Pinned SDK: Flutter **3.47.7**, Dart **3.13.5**. The version is recorded in `.flutter-version`; dependencies are locked in `pubspec.lock`.

A workspace-local SDK is installed at `/home/emmaa/Work/.toolchains/flutter`. From this directory:

```bash
../../.toolchains/flutter/bin/flutter pub get
../../.toolchains/flutter/bin/flutter run --dart-define=HERVOICE_DEMO=true -d web-server --web-hostname 127.0.0.1 --web-port 8765
```

Open `http://127.0.0.1:8765`. If the static preview server is already running on that port, stop it before using the development server or choose a different port.

To serve the built release preview:

```bash
../../.toolchains/flutter/bin/flutter build web --release --dart-define=HERVOICE_DEMO=true
python -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

On another machine, use a Flutter 3.47.7 installation and substitute `flutter` for the workspace-local path. The consolidated Android debug APK was built on 15 October 2026 using the Android Studio JBR and installed SDK; see the runbook for paths. Connected device interaction still requires verification.

## Explore

Start at `/#/home`. One fictional draft and two fictional cases are supplied.

- Home: document a new incident, continue the example draft, open case details, or find support.
- My records: edit or explicitly delete a draft; open fictional case progress.
- Editor: narrative, person/reference, date/time picker, optional location/course, optional file selection/removal, and save/leave.
- Review: check incident details and attachment metadata, return to editing, acknowledge preview mode, and try a simulated submission.
- Confirmation/case: simulated case ID, preserved incident details, selected-file metadata, and progress history.
- Updates: mark a neutral example notification read or open its case.
- Support: expandable guidance and an explicitly unpopulated university contact directory.
- Account menu: preview/privacy explanation and welcome screen; welcome links to the simulated sign-in screen.

Direct preview routes: `/#/records`, `/#/document`, `/#/review`, `/#/updates`, `/#/support`, `/#/cases/HV-DEMO-024`, `/#/welcome`, `/#/signin`. Reloading seeds fictional data again; it does not restore an earlier session.

## Structure

```text
lib/app/              theme, router, responsive navigation shell
lib/core/             shared components and explicit fictional state
lib/features/auth/    welcome and simulated sign-in
lib/features/home/    overview and reporting entry
lib/features/reports/ incident/evidence editor, review and confirmation
lib/features/records/ drafts, case list and case detail
lib/features/updates/ neutral notification interaction
lib/features/support/ support guidance
```

`DemoStore` is deliberately independent of an API and credentials. Its name and preview labelling prevent it being mistaken for a live repository. Future integration should introduce account-scoped repositories and encrypted persistence, then replace the demo routes with explicitly configured real-data flows. File selection currently retains name/size metadata only; it is not an Evidence Vault implementation.

The shell uses a sidebar from 980 logical pixels and bottom navigation below that. Home content becomes two columns from 1180 pixels. Forms scroll, dismiss the keyboard on drag, and preserve editor values within the session. Large text can wrap labels and status rows; decorative sidebar content is omitted in short/enlarged-text windows.

## Verification

```bash
../../.toolchains/flutter/bin/flutter analyze
../../.toolchains/flutter/bin/flutter test
../../.toolchains/flutter/bin/flutter build web --release --dart-define=HERVOICE_DEMO=true
```

Thirty-three widget tests cover phone/desktop routes, narrow-phone enlarged text, a short desktop window, draft save/reopen/delete, date/time selection, review consent, simulated submission and case recovery, file metadata selection/removal, unknown-case recovery, incomplete direct-review submission, unsupported file rejection, and short landscape navigation. Tests treat missed taps as failures and use bundled fonts. The release browser preview has also been visually inspected.

Remaining work: real authentication, encrypted durable drafts/attachment bytes, complete date/unknown-subject decisions, multi-event incident entry, backend integration and retry progress, verified uploads, real notifications, confirmed support contacts, native device/accessibility testing, and production session/identity policy. No current UI claims these are complete.

## Fonts and artwork

Lora and Manrope are bundled for offline rendering under the SIL Open Font License; their licences are included in `assets/fonts/`. The petal illustration is drawn in Flutter. The web/native launcher mark is a repository-native vector. No network font or image service is used by the UI.

See [UI design notes](../docs/FLUTTER_UI.md) and [implementation progress](../docs/IMPLEMENTATION_PROGRESS.md).
