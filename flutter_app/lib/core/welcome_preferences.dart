import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A device-level preference, separate from account-scoped encrypted drafts.
class WelcomePreferences {
  WelcomePreferences({
    Future<String?> Function(String)? read,
    Future<void> Function(String, String)? write,
  }) : _read = read ?? _readValue,
       _write = write ?? _writeValue;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  static const _key = 'hervoice-welcome-seen-v1';
  final Future<String?> Function(String) _read;
  final Future<void> Function(String, String) _write;

  static Future<String?> _readValue(String key) => _storage.read(key: key);
  static Future<void> _writeValue(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<bool> hasSeenWelcome() async {
    try {
      return await _read(_key) == 'yes';
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    try {
      await _write(_key, 'yes');
    } catch (_) {
      // An optional onboarding preference must never block account access.
    }
  }
}
