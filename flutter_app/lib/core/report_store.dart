import 'package:flutter/foundation.dart';

import 'report_models.dart';
export 'report_models.dart';

/// Shared presentation contract and in-memory editing; no fictional records.
class ReportStore extends ChangeNotifier {
  ReportStore({this.isConnected = false});
  final bool isConnected;
  bool get authenticated => !isConnected;
  bool get loading => false;
  String? get error => null;
  List<CaseUpdate> get updates => const [];
  Future<void> login(String email, String password) async {}
  Future<void> requestEmailCode(String email, String purpose) async {
    throw StateError('Connected mode required');
  }

  Future<void> completeEmailCode(
    String email,
    String purpose,
    String code,
    String password,
  ) async {
    throw StateError('Connected mode required');
  }

  void signOut() {}
  Future<void> refresh() async {}
  bool get durableDrafts => false;
  String? get draftStorageError => null;
  String get draftStorageStatus => 'Drafts are held in this session only.';
  Future<void> flushDrafts() async {}
  Future<void> addAttachment(
    IncidentDraft draft,
    String name,
    Uint8List bytes,
  ) async {
    draft.attachments.add(Attachment(name, bytes.length));
    changed();
  }

  Future<void> removeAttachment(IncidentDraft draft, Attachment file) async {
    draft.attachments.remove(file);
    changed();
  }

  Future<void> readUpdate(String id) async {}
  Future<void> readAllUpdates() async => markRead();
  bool get updatingNotifications => false;
  String get pushStatus =>
      'Phone notifications are not available in design preview.';
  bool get pushAvailable => false;
  bool get pushEnabled => false;
  bool get pushBusy => false;
  bool notificationOpened = false;
  Future<void> enablePush() async {}
  Future<void> disablePush() async {}
  Future<PreviewCase> submit() async =>
      throw StateError('Submission is not configured.');
  String get submissionProgress => '';
  bool get submissionPending => false;
  bool draftPending(String id) => false;

  final drafts = <IncidentDraft>[];
  final cases = <PreviewCase>[];
  bool updateRead = false;
  int _next = 1;
  IncidentDraft? active;

  IncidentDraft startDraft() {
    final draft = IncidentDraft(id: 'draft-${_next++}');
    drafts.insert(0, draft);
    active = draft;
    notifyListeners();
    return draft;
  }

  void openDraft(String id) {
    active = drafts.where((d) => d.id == id).firstOrNull;
    notifyListeners();
  }

  void changed() => notifyListeners();
  void deleteDraft(String id) {
    drafts.removeWhere((d) => d.id == id);
    if (active?.id == id) active = null;
    notifyListeners();
  }

  void markRead() {
    updateRead = true;
    notifyListeners();
  }

  PreviewCase? caseById(String id) =>
      cases.where((c) => c.id == id).firstOrNull;
}
