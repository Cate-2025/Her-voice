import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as digest;

import 'draft_vault.dart';
import 'draft_save_queue.dart';
import 'report_mapper.dart';
import 'submission_intent.dart';

import 'api_client.dart';
import 'report_store.dart';
import 'push_service.dart';

/// Coordinates authenticated screens; persistence and payload mapping are separate services.
class ConnectedStore extends ReportStore {
  ConnectedStore(this.api, {this.push, this.vault}) : super(isConnected: true) {
    push?.addListener(_notify);
    push?.onMessage = () => unawaited(refresh());
    push?.onOpened = () {
      notificationOpened = true;
      unawaited(refresh());
      _notify();
    };
    notificationOpened = push?.opened ?? false;
  }
  final PushService? push;
  final DraftVault? vault;
  late final DraftSaveQueue? _saves = vault == null
      ? null
      : DraftSaveQueue(vault!);
  String? _storageError;
  int _writes = 0;
  bool _submitting = false;
  String _submissionProgress = '';
  @override
  String get submissionProgress => _submissionProgress;
  @override
  bool get durableDrafts => vault != null;
  @override
  String? get draftStorageError => _storageError;
  @override
  String get draftStorageStatus =>
      _storageError ??
      (vault == null
          ? 'Drafts are kept only while the app remains open on this device.'
          : _writes > 0
          ? 'Saving encrypted draft…'
          : 'Saved securely on this device. Sign in to the same account to continue after closing the app.');
  String _scope(String account) => '${api.baseUrl}|$account';
  static String _uuid() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Map<String, dynamic> _snapshot() => {
    'version': 1,
    'active': active?.id,
    'drafts': drafts
        .map(
          (d) => {
            'id': d.id,
            'subject': d.subject,
            'course': d.course,
            'location': d.location,
            'narrative': d.narrative,
            'occurredAt': d.occurredAt?.toIso8601String(),
            'attachments': d.attachments
                .map(
                  (a) => {
                    'id': a.id,
                    'name': a.name,
                    'bytes': a.bytes,
                    'contentType': a.contentType,
                    'sha256': a.sha256,
                  },
                )
                .toList(),
          },
        )
        .toList(),
    'pending': _pending.map(
      (id, op) =>
          MapEntry(id, {'payload': op.payload, 'serverId': op.serverId}),
    ),
  };
  void _restore(Map<String, dynamic> state) {
    drafts.clear();
    _pending.clear();
    for (final value in state['drafts'] as List) {
      final d = value as Map<String, dynamic>;
      drafts.add(
        IncidentDraft(
          id: d['id'],
          subject: d['subject'],
          course: d['course'],
          location: d['location'],
          narrative: d['narrative'],
          occurredAt: d['occurredAt'] == null
              ? null
              : DateTime.parse(d['occurredAt']),
          attachments: (d['attachments'] as List)
              .map(
                (a) => Attachment(
                  a['name'],
                  a['bytes'],
                  id: a['id'],
                  contentType: a['contentType'],
                  sha256: a['sha256'],
                ),
              )
              .toList(),
        ),
      );
    }
    for (final entry in (state['pending'] as Map<String, dynamic>).entries) {
      _pending[entry.key] = SubmissionIntent(
        Map<String, dynamic>.from(entry.value['payload']),
      )..serverId = entry.value['serverId'];
    }
    active = drafts.where((d) => d.id == state['active']).firstOrNull;
  }

  Future<void> _persist() {
    final account = _accountId;
    if (vault == null || account == null) return Future.value();
    final state = jsonDecode(jsonEncode(_snapshot())) as Map<String, dynamic>;
    final generation = _generation;
    _writes++;
    final operation = () async {
      try {
        await _saves!.save(_scope(account), state);
        if (_current(generation)) _storageError = null;
      } catch (_) {
        if (_current(generation)) _storageError = 'Draft could not be saved. Keep the app open and retry Save draft before leaving.';
        throw const ApiException(
          'Could not update encrypted device storage. Keep the app open and retry with storage available.',
        );
      } finally {
        _writes--;
        if (_current(generation)) _notify();
      }
    }();
    return operation;
  }

  @override
  Future<void> flushDrafts() => _persist();
  @override
  void changed() {
    unawaited(_persist().catchError((Object _) {}));
    _notify();
  }

  @override
  IncidentDraft startDraft() {
    final draft = IncidentDraft(id: _uuid());
    drafts.insert(0, draft);
    active = draft;
    changed();
    return draft;
  }

  @override
  void openDraft(String id) {
    super.openDraft(id);
    changed();
  }

  @override
  Future<void> addAttachment(
    IncidentDraft draft,
    String name,
    Uint8List bytes,
  ) async {
    if (vault == null || _accountId == null || _pending.containsKey(draft.id)) {
      throw const ApiException('Secure attachment storage is unavailable.');
    }
    if (bytes.isEmpty ||
        bytes.length > 10 * 1024 * 1024 ||
        draft.attachments.length >= 5) {
      throw const ApiException(
        'Choose up to five files, each no larger than 10 MB.',
      );
    }
    final contentType = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'pdf': 'application/pdf',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
    }[name.split('.').last.toLowerCase()];
    if (contentType == null) {
      throw const ApiException('Unsupported evidence type.');
    }
    final id = _uuid(), scope = _scope(_accountId!);
    final generation = _generation;
    await vault!.putFile(scope, id, bytes);
    if (!_current(generation)) {
      await vault!.removeFile(scope, id);
      return;
    }
    draft.attachments.add(
      Attachment(
        name,
        bytes.length,
        id: id,
        contentType: contentType,
        sha256: digest.sha256.convert(bytes).toString(),
      ),
    );
    await _persist();
    _notify();
  }

  @override
  Future<void> removeAttachment(IncidentDraft draft, Attachment file) async {
    if (_pending.containsKey(draft.id)) return;
    final scope = _accountId == null ? null : _scope(_accountId!);
    draft.attachments.remove(file);
    await _persist();
    if (vault != null && scope != null && file.id != null) {
      await vault!.removeFile(scope, file.id!);
    }
    _notify();
  }

  @override
  String get pushStatus =>
      push?.status ??
      'Phone notifications are currently unavailable. You can still view updates here.';
  @override
  bool get pushAvailable => push?.available ?? false;
  @override
  bool get pushEnabled => push?.enabled ?? false;
  @override
  bool get pushBusy => push?.busy ?? false;
  @override
  Future<void> enablePush() async {
    if (!_authenticated || push == null) return;
    final generation = _generation;
    push!.register = (value) async {
      if (!_current(generation) || !_authenticated) {
        throw StateError('Session ended');
      }
      final previous = push!.token;
      await api.request('POST', '/notifications/devices/register', {
        'token': value,
      });
      if (!_current(generation)) throw StateError('Session ended');
      if (previous != null && previous != value) {
        await api.request('POST', '/notifications/devices/revoke', {
          'token': previous,
        });
      }
    };
    await push!.enable();
  }

  @override
  Future<void> disablePush() async {
    final token = push?.token;
    // Capture the current Authorization header before signOut clears the API.
    final revoke = token == null
        ? Future<dynamic>.value()
        : api.request('POST', '/notifications/devices/revoke', {
            'token': token,
          });
    push?.register = null;
    final cleanup = push?.disable();
    try {
      await revoke;
    } catch (_) {
      /* Device token deletion also revokes delivery. */
    }
    await cleanup;
  }

  @override
  Future<void> requestEmailCode(String email, String purpose) async {
    await api.request('POST', '/auth/email-code', {
      'email': email,
      'purpose': purpose,
    });
  }

  @override
  Future<void> completeEmailCode(
    String email,
    String purpose,
    String code,
    String password,
  ) async {
    await api.request('POST', '/auth/email-code/complete', {
      'email': email,
      'purpose': purpose,
      'code': code,
      'password': password,
    });
  }

  final ApiClient api;
  String? _accountId;
  bool _authenticated = false, _loading = false, _disposed = false;
  int _generation = 0;
  int _recordsVersion = 0;
  int _updatesVersion = 0;
  bool _updatingNotifications = false;
  @override
  bool get updatingNotifications => _updatingNotifications;
  String? _error;
  final _updates = <CaseUpdate>[];
  final _pending = <String, SubmissionIntent>{};
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
    final generation = ++_generation;
    _loading = false;
    if (push?.token != null) await disablePush();
    if (!_current(generation)) return;
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
      if (_accountId != user['id']) {
        await _saves?.idle;
        if (!_current(generation)) return;
        final saved = await vault?.load(_scope(user['id'] as String));
        if (!_current(generation)) return;
        _accountId = null;
        _clear();
        if (saved != null) _restore(saved);
      }
      _accountId = user['id'] as String;
      _storageError = null;
      _authenticated = true;
      _error = null;
      _notify();
      await refresh();
    } catch (_) {
      if (_current(generation)) api.token = null;
      rethrow;
    }
  }

  @override
  void signOut() {
    unawaited(_persist().catchError((Object _) {}));
    unawaited(disablePush());
    _generation++;
    api.token = null;
    _authenticated = false;
    _accountId = null;
    _loading = false;
    _updatingNotifications = false;
    _error = null;
    _clear();
    _notify();
  }

  @override
  Future<void> refresh() async {
    if (!_authenticated || _loading) return;
    final generation = _generation;
    final version = _recordsVersion;
    final updatesVersion = _updatesVersion;
    _loading = true;
    _error = null;
    _notify();
    try {
      final summaries = await api.listPages('/cases/mine');
      final loaded = <PreviewCase>[];
      // Cap concurrent detail requests instead of a sequential N-request waterfall.
      for (var start = 0; start < summaries.length; start += 4) {
        if (!_current(generation)) return;
        final batch = summaries.skip(start).take(4);
        loaded.addAll(
          await Future.wait(
            batch.map(
              (summary) async => reportFromJson(
                await api.request('GET', '/reports/${summary['id']}'),
              ),
            ),
          ),
        );
      }
      if (!_current(generation)) return;
      final notices = await api.request('GET', '/notifications') as List;
      if (!_current(generation)) return;
      if (version == _recordsVersion) {
        cases
          ..clear()
          ..addAll(loaded);
      }
      if (updatesVersion == _updatesVersion) {
        _updates
          ..clear()
          ..addAll(notices.map(_update));
      }
    } catch (e) {
      if (_current(generation)) _failed(e);
    } finally {
      if (_current(generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  CaseUpdate _update(dynamic value) => CaseUpdate(
    value['id'] as String,
    value['body'] as String,
    DateTime.parse(value['created_at'] as String).toLocal(),
    value['read_at'] != null,
  );

  @override
  Future<void> readUpdate(String id) =>
      _markUpdates('/notifications/$id/read', all: false);

  @override
  Future<void> readAllUpdates() =>
      _markUpdates('/notifications/read-all', all: true);

  Future<void> _markUpdates(String path, {required bool all}) async {
    if (!_authenticated || _updatingNotifications) return;
    final generation = _generation;
    _updatingNotifications = true;
    _error = null;
    _notify();
    try {
      final result = await api.request('POST', path);
      if (!_current(generation)) return;
      final updated = (all ? result as List : [result]).map(_update).toList();
      _updatesVersion++;
      if (all) {
        _updates
          ..clear()
          ..addAll(updated);
      } else {
        final index = _updates.indexWhere(
          (item) => item.id == updated.single.id,
        );
        if (index >= 0) _updates[index] = updated.single;
      }
    } catch (e) {
      if (_current(generation)) _failed(e);
    } finally {
      if (_current(generation)) {
        _updatingNotifications = false;
        _notify();
      }
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
    if (draft.attachments.isNotEmpty && vault == null) {
      throw const ApiException(
        'Secure attachment storage is unavailable on this device.',
      );
    }
    if (_submitting) {
      throw const ApiException('Submission is already in progress.');
    }
    // Freeze the exact payload and key before the first request. A lost response
    // must never turn a retry into another report or a changed allegation.
    final pending = _pending.putIfAbsent(
      draft.id,
      () => SubmissionIntent({
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
    _submitting = true;
    final scope = _scope(_accountId!);
    try {
      await _persist(); // Persist explicit intent before the first network side effect.
      if (!_current(generation)) throw const ApiException('The session ended.');
      if (pending.serverId == null) {
        final result = await api.request(
          'POST',
          '/reports/drafts',
          pending.payload,
        );
        if (!_current(generation)) {
          throw const ApiException('The session ended.');
        }
        pending.serverId = result['id'] as String;
        await _persist();
      }
      if (!_current(generation)) throw const ApiException('The session ended.');
      var fileNumber = 0;
      for (final file in draft.attachments) {
        _submissionProgress =
            'Uploading evidence ${++fileNumber} of ${draft.attachments.length}…';
        _notify();
        final bytes = await vault!.readFile(scope, file.id!);
        if (!_current(generation)) {
          throw const ApiException('The session ended.');
        }
        await api.upload(
          '/evidence/reports/${pending.serverId}/files/${file.id}',
          bytes,
          name: file.name,
          contentType: file.contentType!,
          checksum: file.sha256!,
        );
      }
      if (!_current(generation)) throw const ApiException('The session ended.');
      _submissionProgress = 'Confirming your report…';
      _notify();
      await api.request('POST', '/reports/${pending.serverId}/submit');
      if (!_current(generation)) throw const ApiException('The session ended.');
      final report = reportFromJson(
        await api.request('GET', '/reports/${pending.serverId}'),
      );
      if (!_current(generation)) throw const ApiException('The session ended.');
      _recordsVersion++;
      cases.removeWhere((c) => c.id == report.id);
      cases.insert(0, report);
      drafts.remove(draft);
      _pending.remove(draft.id);
      active = null;
      await _persist();
      for (final file in draft.attachments) {
        if (file.id != null) {
          try {
            await vault?.removeFile(scope, file.id!);
          } catch (_) {
            /* Encrypted orphan; never block a confirmed report. */
          }
        }
      }
      _notify();
      return report;
    } catch (e) {
      if (_current(generation)) {
        _failed(e);
        _notify();
      }
      rethrow;
    } finally {
      _submitting = false;
      _submissionProgress = '';
      _notify();
    }
  }

  @override
  void deleteDraft(String id) {
    if (_pending.containsKey(id)) return;
    final removed = drafts.where((d) => d.id == id).firstOrNull;
    final scope = _accountId == null ? null : _scope(_accountId!);
    super.deleteDraft(id);
    unawaited(
      _persist()
          .then((_) async {
            if (removed != null && scope != null) {
              for (final file in removed.attachments) {
                if (file.id != null) await vault?.removeFile(scope, file.id!);
              }
            }
          })
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    push?.removeListener(_notify);
    if (push != null) {
      push!.onMessage = null;
      push!.onOpened = null;
      push!.register = null;
    }
    api.close();
    super.dispose();
  }
}
