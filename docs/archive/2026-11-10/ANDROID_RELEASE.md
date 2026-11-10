> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Android release preparation

Release signing now refuses to fall back to the debug certificate. Debug builds keep the existing local workflow. Release startup also requires an HTTPS API URL outside explicit demo mode.

1. Decide application ID/distribution ownership, retain a reviewed commit and approve the hosted staging endpoint. Do not change the application ID casually after distribution.
2. Create the signing key using Android Studio's signed bundle/APK flow or the JDK keytool, following https://docs.flutter.dev/deployment/android. Choose passwords privately. Keep the keystore outside the repository, restrict access and back it up under institutional ownership.
3. Copy `flutter_app/android/key.properties.example` to `flutter_app/android/key.properties`. Enter the absolute keystore path, alias and local passwords. The properties and keystore extensions are ignored by Git. Do not commit or upload signing material into test artifacts.
4. Set the version/build number in pubspec.yaml. From flutter_app build:

```bash
flutter build apk --release --dart-define=HERVOICE_API_BASE_URL=https://YOUR_HOST/api/v1
# For a store bundle instead:
flutter build appbundle --release --dart-define=HERVOICE_API_BASE_URL=https://YOUR_HOST/api/v1
```

5. Verify certificate identity using the Android SDK apksigner, install on a representative test phone and test over mobile data without ADB. Retain APK/bundle checksum, source revision and version. Test TalkBack, large text, restart, sign-in expiry, file selection and interrupted submissions.
6. A release certificate different from the installed debug certificate may prevent an in-place update. Do not uninstall to work around this until drafts have an approved recovery/migration path. Vault scope includes API URL and account ID; changing those values also affects recovery. Test upgrades on a disposable fictional-data installation first.

No signing key is generated or committed by the technical preparation pass. Real signed-release and device acceptance require the owner's key/configuration. CI runs unsigned technical tests and does not hold signing credentials. Real SMTP/S3/Firebase configuration and institutional acceptance remain launch gates.
