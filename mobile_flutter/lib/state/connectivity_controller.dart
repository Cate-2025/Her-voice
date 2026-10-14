import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Watches the device's wireless transport so the app knows when it is worth
/// attempting a synchronisation (sections 3.7 and 7.3).
///
/// It also exposes a manual "work offline" switch. That switch exists for two
/// reasons: students may deliberately want to prepare a report with no network
/// traffic at all, and it makes the offline-first behaviour demonstrable during
/// the project presentation without unplugging the machine's network.
class ConnectivityController extends ChangeNotifier {
  ConnectivityController({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _hasTransport = true;
  bool _forcedOffline = false;
  bool _started = false;

  /// True when the app should attempt network calls.
  bool get isOnline => _hasTransport && !_forcedOffline;

  bool get isForcedOffline => _forcedOffline;

  /// True when the operating system reports a usable transport.
  bool get hasTransport => _hasTransport;

  String get statusLabel {
    if (_forcedOffline) return 'Working offline (you chose)';
    if (!_hasTransport) return 'No network connection';
    return 'Connected';
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      _hasTransport = _hasTransportFrom(await _connectivity.checkConnectivity());
    } catch (_) {
      _hasTransport = true;
    }
    notifyListeners();

    _subscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final bool next = _hasTransportFrom(results);
      if (next == _hasTransport) return;
      _hasTransport = next;
      notifyListeners();
    });
  }

  static bool _hasTransportFrom(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((ConnectivityResult result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }

  Future<void> setForcedOffline(bool value) async {
    if (_forcedOffline == value) return;
    _forcedOffline = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
