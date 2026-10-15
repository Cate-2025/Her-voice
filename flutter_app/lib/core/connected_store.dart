import 'dart:convert';
import 'dart:math';

import 'api_client.dart';
import 'demo_store.dart';

/// Account-scoped, memory-only prototype. Never falls back to fictional records.
class ConnectedStore extends ReportStore {
  ConnectedStore(this.api) : super(isConnected: true);
  final ApiClient api;
  String? _accountId;
  bool _authenticated = false, _loading = false, _disposed = false;
  int _generation = 0;
  int _recordsVersion = 0;
  String? _error;
  final _updates = <CaseUpdate>[];
  final _pending = <String, _Submission>{};
  @override
  bool get authenticated => _authenticated;
  @override
  bool get loading => _loading;
  @override
  String? get error => _error;
  @override
  List<CaseUpdate> get updates => List.unmodifiable(_updates);
  @override
  bool get submissionPending => _pending.containsKey(active?.id);
  @override
  bool draftPending(String id) => _pending.containsKey(id);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  void _clear() {
    drafts.clear();
    cases.clear();
    _updates.clear();
    _pending.clear();
    active = null;
  }

  void _failed(Object error) {
    _error = error is ApiException
        ? error.message
        : 'The request could not complete. Please retry.';
    if (error is ApiException && error.status == 401) {
      _authenticated = false;
      api.token = null;
      // Retain session drafts for reauthentication to the same account.
    }
  }

  @override
  Future<void> login(String email, String password) async {
    final generation = _generation;
    _authenticated = false;
    api.token = null;
    final result = await api.request('POST', '/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    if (!_current(generation)) return;
    api.token = result['access_token'] as String;
    try {
      final user = await api.request('GET', '/auth/me');
      if (!_current(generation)) return;
      if (user['role'] != 'student') {
        throw const ApiException(
          'Use a student account here. Officers use the web dashboard.',
        );
      }
      if (_accountId != user['id']) _clear();
      _accountId = user['id'] as String;
      _authenticated = true;
      _error = null;
      _notify();
      await refresh();
    } catch (_) {
      api.token = null;
      rethrow;
    }
  }

  @override
  void signOut() {
    _generation++;
    api.token = null;
    _authenticated = false;
    _accountId = null;
    _loading = false;
    _error = null;
    _clear();
    _notify();
  }

  @override
  Future<void> refresh() async {
    if (!_authenticated || _loading) return;
    final generation = _generation;
    final version = _recordsVersion;
    _loading = true;
    _error = null;
    _notify();
    try {
      final summaries = await api.request('GET', '/cases/mine') as List;
      final loaded = <PreviewCase>[];
      for (final summary in summaries) {
        if (!_current(generation)) return;
        loaded.add(
          _case(await api.request('GET', '/reports/${summary['id']}')),
        );
      }
      final notices = await api.request('GET', '/notifications') as List;
      if (!_current(generation)) return;
      if (version == _recordsVersion) {
        cases
          ..clear()
          ..addAll(loaded);
      }
      _updates
        ..clear()
        ..addAll(
          notices.map(
            (n) => CaseUpdate(
              n['id'] as String,
              n['body'] as String,
              DateTime.parse(n['created_at'] as String).toLocal(),
              n['read_at'] != null,
            ),
          ),
        );
    } catch (e) {
      if (_current(generation)) _failed(e);
    } finally {
      if (_current(generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  @override
  Future<void> readUpdate(String id) async {
    try {
      await api.request('POST', '/notifications/$id/read');
      await refresh();
    } catch (e) {
      _failed(e);
      _notify();
    }
  }

  @override
  Future<PreviewCase> submit() async {
    final draft = active;
    if (!_authenticated || draft == null || !draft.canSubmit) {
      throw const ApiException(
        'Sign in and complete your incident details first.',
      );
    }
    if (draft.attachments.isNotEmpty) {
      throw const ApiException(
        'Attachment uploads are not available in this milestone.',
      );
    }
    // Freeze the exact payload and key before the first request. A lost response
    // must never turn a retry into another report or a changed allegation.
    final pending = _pending.putIfAbsent(
      draft.id,
      () => _Submission({
        'report_mode': 'confidential',
        'subject_staff_ref': draft.subject.trim(),
        'course_ref': draft.course.trim().isEmpty ? null : draft.course.trim(),
        'idempotency_key': List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join(),
        'timeline': [
          {
            'occurred_at': draft.occurredAt!.toUtc().toIso8601String(),
            'location_hint': draft.location.trim().isEmpty
                ? null
                : draft.location.trim(),
            'narrative': draft.narrative.trim(),
          },
        ],
      }),
    );
    final generation = _generation;
    _error = null;
    try {
      if (pending.serverId == null) {
        final result = await api.request(
          'POST',
          '/reports/drafts',
          pending.payload,
        );
        pending.serverId = result['id'] as String;
      }
      if (!_current(generation)) throw const ApiException('The session ended.');
      await api.request('POST', '/reports/${pending.serverId}/submit');
      final report = _case(
        await api.request('GET', '/reports/${pending.serverId}'),
      );
      if (!_current(generation)) throw const ApiException('The session ended.');
      _recordsVersion++;
      cases.removeWhere((c) => c.id == report.id);
      cases.insert(0, report);
      drafts.remove(draft);
      _pending.remove(draft.id);
      active = null;
      _notify();
      return report;
    } catch (e) {
      if (_current(generation)) {
        _failed(e);
        _notify();
      }
      rethrow;
    }
  }

  @override
  void deleteDraft(String id) {
    if (_pending.containsKey(id)) return;
    super.deleteDraft(id);
  }

  PreviewCase _case(dynamic json) {
    final timeline = json['timeline'] as List;
    final first = timeline.isEmpty ? null : timeline.first;
    final status = switch (json['status']) {
      'submitted' => 'Submitted',
      'received' => 'Received',
      'under_review' => 'Under review',
      'action_required' => 'Action required',
      'closed' => 'Closed',
      _ => 'Unknown',
    };
    final date = DateTime.parse(
      (json['submitted_at'] ?? json['created_at']) as String,
    ).toLocal();
    return PreviewCase(
      id: json['id'] as String,
      date: date,
      status: status,
      narrative: timeline.map((e) => e['narrative'] as String).join('\n\n'),
      location: first?['location_hint'] as String? ?? '',
      subject: json['subject_staff_ref'] as String,
      course: json['course_ref'] as String? ?? '',
      occurredAt: first == null
          ? null
          : DateTime.parse(first['occurred_at'] as String).toLocal(),
      events: [(status, 'Current server status')],
      attachments: (json['evidence'] as List? ?? [])
          .map(
            (e) =>
                Attachment(e['original_name'] as String, e['byte_size'] as int),
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    api.close();
    super.dispose();
  }
}

class _Submission {
  _Submission(Map<String, dynamic> value)
    : payload = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  final Map<String, dynamic> payload;
  String? serverId;
}
