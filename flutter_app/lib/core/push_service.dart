import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Android notifications contain no case content. API authentication remains
/// necessary when a notification opens the Updates screen.
class PushService extends ChangeNotifier {
  bool available = false, enabled = false, busy = false;
  String status = 'Phone notifications are available in the Android app.';
  String? token;
  bool opened = false;
  VoidCallback? onMessage, onOpened;
  Future<void> Function(String)? register;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _pending = Future.value();
  int _generation = 0;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await Firebase.initializeApp();
      available = true;
      status = 'Off. Enable notifications without names or report details.';
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((_) => onMessage?.call()),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((_) {
          opened = true;
          onOpened?.call();
        }),
      );
      opened = await FirebaseMessaging.instance.getInitialMessage() != null;
      // Sign-in is memory-only. Retire any prior session's device registration
      // before a new account explicitly enables notifications.
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 10),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((value) {
          if (enabled) unawaited(_registerToken(value));
        }),
      );
    } catch (_) {
      available = false;
      status = 'Phone notifications are currently unavailable. You can still view updates here.';
    }
  }

  Future<void> _registerToken(String value) async {
    final generation = _generation;
    try {
      final callback = register;
      if (callback == null) return;
      await callback(value);
      if (generation != _generation) return;
      token = value;
      enabled = true;
      status = 'Enabled on this device. You can also check Updates for the latest information.';
    } catch (_) {
      if (generation != _generation) return;
      status = 'Could not enable phone notifications. Check your connection and try again.';
      enabled = false;
    }
    _notify();
  }

  Future<void> enable() {
    if (!available || busy) return Future.value();
    final generation = _generation;
    busy = true;
    _notify();
    _pending = _pending.then((_) async {
      try {
        if (generation != _generation) return;
        final settings = await FirebaseMessaging.instance.requestPermission();
        if (generation != _generation) return;
        if (settings.authorizationStatus != AuthorizationStatus.authorized) {
          status = 'Permission is off. Allow notifications in Android app settings, then retry.';
          return;
        }
        // Keep automatic collection off; explicitly get a token after consent.
        final value = await FirebaseMessaging.instance.getToken();
        if (generation != _generation) return;
        if (value == null) throw StateError('Token unavailable');
        await _registerToken(value);
      } catch (_) {
        if (generation == _generation) status = 'Phone notifications could not be enabled. Check your connection and retry.';
      } finally {
        if (generation == _generation) {
          busy = false;
          _notify();
        }
      }
    });
    return _pending;
  }

  Future<void> disable() {
    _generation++;
    enabled = false;
    token = null;
    busy = false;
    if (available) {
      status = 'Off. Enable notifications without names or report details.';
    }
    _notify();
    _pending = _pending.then((_) async {
      if (!available) return;
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {
        status = 'Could not finish turning off notifications. Turn them off in Android settings.';
        _notify();
      }
    });
    return _pending;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    onMessage = null;
    onOpened = null;
    register = null;
    super.dispose();
  }
}
