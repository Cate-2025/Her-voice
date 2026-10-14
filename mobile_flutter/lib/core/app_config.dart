import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Runtime configuration for the HERVOICE client.
///
/// The backend is reached over HTTP/REST (section 3.11 of the concept paper).
/// [defaultBaseUrl] points at the host loopback address as seen from an Android
/// emulator (10.0.2.2 maps to the developer machine's 127.0.0.1). A physical
/// device needs the machine's LAN address instead, which can be supplied at
/// build time:
///
/// ```sh
/// flutter run --dart-define=HERVOICE_API_BASE_URL=http://192.168.0.10:4000/api
/// ```
///
/// It can also be changed at runtime from Settings without rebuilding.
class AppConfig {
  const AppConfig._();

  static const String _defineBaseUrl =
      String.fromEnvironment('HERVOICE_API_BASE_URL', defaultValue: '');

  static const Duration requestTimeout = Duration(seconds: 20);

  /// Prototype cap that mirrors `MAX_EVIDENCE_BYTES` on the server.
  static const int maxEvidenceBytes = 10 * 1024 * 1024;

  static String get defaultBaseUrl {
    if (_defineBaseUrl.isNotEmpty) return _defineBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:4000/api';
    // Android emulators reach the development machine through 10.0.2.2.
    if (Platform.isAndroid) return 'http://10.0.2.2:4000/api';
    return 'http://127.0.0.1:4000/api';
  }

  /// Text shown to the student when she has to choose a reporting pathway.
  static const String allegationDisclaimer =
      'HERVOICE lets you record and submit an allegation. It does not decide whether '
      'misconduct occurred. Only the authorised institutional investigation process can '
      'make that determination, and every person named is presumed innocent until then.';

  /// Lock-screen safety statement (section 3.6).
  static const String notificationPrivacyNotice =
      'Notifications never include case details. Tap one, authenticate, and the message '
      'opens inside HERVOICE.';
}
