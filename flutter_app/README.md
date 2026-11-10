# HERVOICE Android client

The default app connects to the HERVOICE API. Android drafts/evidence persist
encrypted for the same account, API URL and device; sign-in sessions are memory-only.

- [Android Studio, local API and developer tests](../docs/DEVELOPMENT.md)
- [Hosted API configuration, optional Firebase and Android signing](../docs/DEPLOYMENT.md)
- [Current behaviour and limits](../docs/DESCRIPTION.md)
- [Device and release acceptance](../docs/RELEASE_CHECKLIST.md)

Pinned SDK: Flutter 3.47.7 / Dart 3.13.5; see `.flutter-version`.
The workspace SDK is `/home/emmaa/Work/.toolchains/flutter`.
Run `flutter analyze --no-pub` and `flutter test --no-pub` from this directory.

Use `--dart-define=HERVOICE_DEMO=true` only for the optional disconnected fictional
preview. It has no real authentication or submission and does not persist drafts
after restart. Preview instructions are in Development; they are not the normal
Android connection flow.

The Open Notebook visual system is in [DESIGN.md](../DESIGN.md). Lora and Manrope
are bundled under the licences in `assets/fonts/`.
