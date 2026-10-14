import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted-at-rest storage for the session token (section 3.12 IV).
///
/// `flutter_secure_storage` uses the Android Keystore-backed EncryptedShared
/// Preferences, so the bearer token is never written to plain preferences where
/// another application could read it.
class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _tokenKey = 'hervoice.session.token';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      // A corrupt keystore entry must not block the student from signing in
      // again, so it is treated as "no session".
      return null;
    }
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      // Nothing further to do: the caller discards the in-memory session anyway.
    }
  }
}
