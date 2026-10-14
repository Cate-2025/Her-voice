import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// Non-sensitive preferences: the backend address, the privacy-safe notification
/// preference and a one-time consent flag.
///
/// Nothing here is confidential, so plain preferences are appropriate; the
/// session token lives in [SecureSessionStore] instead.
class PreferencesStore {
  PreferencesStore(this._preferences);

  static const String _baseUrlKey = 'hervoice.api.baseUrl';
  static const String _privacyConsentKey = 'hervoice.consent.privacyAcknowledged';
  static const String _locationConsentKey = 'hervoice.consent.attachLocation';

  final SharedPreferences _preferences;

  static Future<PreferencesStore> open() async {
    return PreferencesStore(await SharedPreferences.getInstance());
  }

  String get apiBaseUrl => _preferences.getString(_baseUrlKey) ?? AppConfig.defaultBaseUrl;

  Future<void> setApiBaseUrl(String value) => _preferences.setString(_baseUrlKey, value.trim());

  Future<void> resetApiBaseUrl() => _preferences.remove(_baseUrlKey);

  /// The allegation-versus-finding statement is shown once and acknowledged.
  bool get privacyAcknowledged => _preferences.getBool(_privacyConsentKey) ?? false;

  Future<void> setPrivacyAcknowledged(bool value) =>
      _preferences.setBool(_privacyConsentKey, value);

  /// GPS coordinates are only attached when the student opts in (section 3.11).
  bool get attachLocation => _preferences.getBool(_locationConsentKey) ?? false;

  Future<void> setAttachLocation(bool value) => _preferences.setBool(_locationConsentKey, value);
}
