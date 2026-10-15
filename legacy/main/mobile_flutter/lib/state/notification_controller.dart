import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/hervoice_repository.dart';
import '../models/app_notification.dart';

/// Loads secure notifications and tracks the unread badge (section 3.6).
class NotificationController extends ChangeNotifier {
  NotificationController(this._repository);

  final HerVoiceRepository _repository;

  List<AppNotification> _items = <AppNotification>[];
  int _unreadCount = 0;
  bool _loading = false;
  String? _errorMessage;
  String? _privacyNotice;

  List<AppNotification> get items => _items;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  String? get errorMessage => _errorMessage;
  String? get privacyNotice => _privacyNotice;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final ({int unreadCount, List<AppNotification> items}) result =
          await _repository.notifications();
      _items = result.items;
      _unreadCount = result.unreadCount;
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markNotificationRead(id);
      _items = _items
          .map((AppNotification item) => item.id == id
              ? AppNotification(
                  id: item.id,
                  category: item.category,
                  title: item.title,
                  body: item.body,
                  read: true,
                  caseId: item.caseId,
                  caseReference: item.caseReference,
                  channel: item.channel,
                  createdAt: item.createdAt,
                )
              : item)
          .toList();
      _unreadCount = _items.where((AppNotification item) => !item.read).length;
      notifyListeners();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllNotificationsRead();
      await load();
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
    }
  }

  /// Registers this install for push delivery. Until a token is registered the
  /// backend routes critical updates through the SMS fallback channel instead.
  Future<bool> registerDevice(String pushToken) async {
    try {
      await _repository.registerDevice(pushToken);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }
}
