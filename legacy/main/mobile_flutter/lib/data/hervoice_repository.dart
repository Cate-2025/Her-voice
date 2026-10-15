import 'dart:io';

import 'package:uuid/uuid.dart';

import '../core/app_config.dart';
import '../models/app_notification.dart';
import '../models/auth_user.dart';
import '../models/enums.dart';
import '../models/evidence_item.dart';
import '../models/incident_report.dart';
import '../models/support_resource.dart';
import '../models/timeline_event.dart';
import 'api_client.dart';
import 'offline_queue.dart';

/// A file the student selected as supporting evidence.
class EvidenceUpload {
  const EvidenceUpload({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.kind,
    this.note,
    this.lawfulDeclaration = false,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final EvidenceKind kind;
  final String? note;
  final bool lawfulDeclaration;
}

/// Outcome of a create/report action so the UI can tell the student exactly
/// where her record is.
class SubmitOutcome {
  const SubmitOutcome({
    required this.queuedOffline,
    this.reference,
    this.caseId,
    this.patternDetected = false,
    this.message,
  });

  /// True when the incident is still only on the device.
  final bool queuedOffline;
  final String? reference;
  final String? caseId;
  final bool patternDetected;
  final String? message;
}

/// Result of flushing the offline queue.
class SyncOutcome {
  const SyncOutcome({required this.synced, required this.failed, this.patternAlerts = 0});

  final int synced;
  final int failed;
  final int patternAlerts;

  bool get didNothing => synced == 0 && failed == 0;
}

/// Single entry point used by every controller. It hides whether a piece of data
/// travelled over the network or through the local queue, which is what makes the
/// offline-first behaviour transparent to the rest of the app.
class HerVoiceRepository {
  HerVoiceRepository({
    required ApiClient api,
    required OfflineQueue queue,
    Uuid? uuid,
  })  : _api = api,
        _queue = queue,
        _uuid = uuid ?? const Uuid();

  final ApiClient _api;
  final OfflineQueue _queue;
  final Uuid _uuid;

  ApiClient get api => _api;

  String newClientReference() => _uuid.v4();

  // --- Authentication -----------------------------------------------------

  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _api.postJson('/auth/register', <String, dynamic>{
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    final ({String token, AuthUser user}) session =
        await login(email: email, password: password);
    return session.user;
  }

  /// Signs in and returns both the session token and the account profile.
  Future<({String token, AuthUser user})> login({
    required String email,
    required String password,
  }) async {
    final dynamic response = await _api.postJson('/auth/login', <String, dynamic>{
      'email': email,
      'password': password,
    });
    final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
    final String token = json['token']?.toString() ?? '';
    if (token.isEmpty) throw ApiException('The server did not return a session token');
    _api.setToken(token);
    return (token: token, user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)));
  }

  Future<AuthUser> currentUser() async {
    final dynamic response = await _api.getJson('/auth/me');
    return AuthUser.fromJson(Map<String, dynamic>.from((response as Map)['user'] as Map));
  }

  // --- Support directory --------------------------------------------------

  Future<SupportDirectory> supportDirectory() async {
    final dynamic response = await _api.getJson('/support/resources');
    return SupportDirectory.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<EmergencyDirectory> emergencyDirectory() async {
    final dynamic response = await _api.getJson('/support/emergency-contacts');
    return EmergencyDirectory.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Logs a quick-support request. Never replaces emergency services.
  Future<void> requestQuickSupport({
    required String reason,
    String channel = 'IN_APP',
  }) async {
    await _api.postJson('/support/quick-support', <String, dynamic>{
      'reason': reason,
      'channel': channel,
    });
  }

  // --- Incident reporting -------------------------------------------------

  /// Creates an incident. When the device is offline the record is written to
  /// the local queue instead and [SubmitOutcome.queuedOffline] is true, so the
  /// student can keep documenting without connectivity (section 3.7).
  Future<SubmitOutcome> createIncident(
    IncidentDraft draft, {
    bool asDraft = false,
    bool forceOffline = false,
  }) async {
    final String clientRef = newClientReference();

    if (forceOffline) {
      return _queueIncident(draft, clientRef, asDraft);
    }

    try {
      final dynamic response = await _api.postJson('/reports', draft.toJson(clientRef: clientRef, asDraft: asDraft));
      final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
      return SubmitOutcome(
        queuedOffline: false,
        reference: json['reference']?.toString(),
        caseId: json['reportId']?.toString(),
        patternDetected: json['patternDetected'] == true,
        message: json['message']?.toString(),
      );
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem || error.isUnauthorised) rethrow;
      return _queueIncident(draft, clientRef, asDraft);
    }
  }

  Future<SubmitOutcome> _queueIncident(
    IncidentDraft draft,
    String clientRef,
    bool asDraft,
  ) async {
    await _queue.enqueueIncident(
      PendingIncident(
        clientRef: clientRef,
        payload: draft.toJson(asDraft: asDraft),
        createdAt: DateTime.now(),
      ),
    );
    return const SubmitOutcome(
      queuedOffline: true,
      message: 'Saved securely on this device. HERVOICE will send it when you are back online.',
    );
  }

  /// Adds a file to the Evidence Vault. Large files are never held in memory for
  /// longer than the upload itself, and an offline capture is queued by path.
  Future<EvidenceItem> attachEvidence(String reportId, EvidenceUpload upload) async {
    final int size = await File(upload.path).length();
    final PendingEvidence pending = PendingEvidence(
      id: 'local_${_uuid.v4()}',
      reportRef: reportId,
      filePath: upload.path,
      fileName: upload.fileName,
      mimeType: upload.mimeType,
      kind: upload.kind.wire,
      note: upload.note,
      lawfulDeclaration: upload.lawfulDeclaration,
      capturedAt: DateTime.now(),
    );

    try {
      return await _uploadEvidence(pending, size);
    } on ApiException catch (error) {
      if (!error.isConnectivityProblem || error.isUnauthorised) rethrow;
      await _queue.enqueueEvidence(pending);
      return EvidenceItem(
        id: pending.id,
        kind: upload.kind,
        originalName: upload.fileName,
        mimeType: upload.mimeType,
        sizeBytes: size,
        note: upload.note,
        capturedAt: pending.capturedAt,
        lawfulDeclaration: upload.lawfulDeclaration,
        pendingSync: true,
      );
    }
  }

  Future<EvidenceItem> _uploadEvidence(PendingEvidence pending, [int? knownSize]) async {
    final List<int> bytes = await File(pending.filePath).readAsBytes();
    final int size = knownSize ?? bytes.length;
    if (size > AppConfig.maxEvidenceBytes) {
      throw ApiException(
        'This file is larger than the ${AppConfig.maxEvidenceBytes ~/ (1024 * 1024)} MB prototype limit.',
      );
    }

    final dynamic response = await _api.postJson(
      '/reports/${pending.reportRef}/evidence',
      pending.toUploadBody(bytes),
    );
    final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
    return EvidenceItem.fromJson(Map<String, dynamic>.from(json['evidence'] as Map));
  }

  Future<List<EvidenceItem>> listEvidence(String reportId) async {
    final dynamic response = await _api.getJson('/reports/$reportId/evidence');
    return ((response as Map)['evidence'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(EvidenceItem.fromJson)
        .toList();
  }

  Future<List<int>> downloadEvidence(String evidenceId) => _api.downloadBytes('/evidence/$evidenceId');

  Future<void> deleteEvidence(String reportId, String evidenceId) async {
    await _api.deleteJson('/reports/$reportId/evidence/$evidenceId');
  }

  // --- Case tracking ------------------------------------------------------

  Future<List<CaseSummary>> listCases() async {
    final dynamic response = await _api.getJson('/reports');
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CaseSummary.fromJson)
        .toList();
  }

  Future<IncidentReport> getCase(String caseId) async {
    final dynamic response = await _api.getJson('/reports/$caseId');
    return IncidentReport.fromJson(Map<String, dynamic>.from((response as Map)['report'] as Map));
  }

  /// Records a subsequent incident on the existing timeline (section 3.1 A, VII).
  Future<List<TimelineEvent>> addFollowUp(
    String caseId, {
    required String title,
    String? detail,
  }) async {
    final dynamic response = await _api.postJson('/reports/$caseId/timeline', <String, dynamic>{
      'title': title,
      'detail': detail,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    return ((response as Map)['timeline'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(TimelineEvent.fromJson)
        .toList();
  }

  /// Submits a draft through the reporting pathway the student selected.
  Future<SubmitOutcome> submitDraft(String caseId) async {
    final dynamic response = await _api.postJson('/reports/$caseId/submit', null);
    final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
    return SubmitOutcome(
      queuedOffline: false,
      reference: json['reference']?.toString(),
      caseId: caseId,
      patternDetected: json['patternDetected'] == true,
      message: json['message']?.toString(),
    );
  }

  Future<Map<String, dynamic>> caseStatus(String caseId) async {
    final dynamic response = await _api.getJson('/reports/$caseId/status');
    return Map<String, dynamic>.from(response as Map);
  }

  // --- Offline synchronisation (section 7.3) -------------------------------

  Future<int> pendingCount() => _queue.pendingCount();

  Future<List<PendingIncident>> pendingIncidents() => _queue.pendingIncidents();

  /// Flushes everything held on the device. Incidents go up in one batch so the
  /// backend can deduplicate them by client reference, then any queued evidence
  /// is attached to the case the server just created.
  Future<SyncOutcome> synchronise({String? caseIdForEvidence}) async {
    final List<PendingIncident> incidents = await _queue.pendingIncidents();
    final List<PendingEvidence> evidence = await _queue.pendingEvidence();
    if (incidents.isEmpty && evidence.isEmpty) {
      return const SyncOutcome(synced: 0, failed: 0);
    }

    int synced = 0;
    int failed = 0;
    int alerts = 0;

    if (incidents.isNotEmpty) {
      try {
        final dynamic response = await _api.postJson('/reports/sync', <String, dynamic>{
          'reports': incidents.map((PendingIncident item) => item.body).toList(),
        });
        final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
        alerts = ((json['alerts'] as List<dynamic>?) ?? <dynamic>[]).length;

        for (final dynamic entry in (json['results'] as List<dynamic>?) ?? <dynamic>[]) {
          final Map<String, dynamic> result = Map<String, dynamic>.from(entry as Map);
          final String? clientRef = result['clientRef']?.toString();
          if (clientRef == null) continue;
          if (result['accepted'] == true) {
            await _queue.removeIncident(clientRef);
            synced += 1;
          } else {
            await _queue.recordIncidentFailure(
              clientRef,
              result['message']?.toString() ?? 'The server rejected this record',
            );
            failed += 1;
          }
        }
      } on ApiException catch (error) {
        for (final PendingIncident item in incidents) {
          await _queue.recordIncidentFailure(item.clientRef, error.message);
        }
        failed += incidents.length;
      }
    }

    // Only evidence whose case already exists on the server can be uploaded.
    if (evidence.isNotEmpty && caseIdForEvidence != null) {
      for (final PendingEvidence item in await _queue.pendingEvidence(reportRef: caseIdForEvidence)) {
        try {
          await _uploadEvidence(item);
          await _queue.removeEvidence(item.id);
          synced += 1;
        } on ApiException catch (error) {
          await _queue.recordEvidenceFailure(item.id, error.message);
          failed += 1;
        }
      }
    }

    return SyncOutcome(synced: synced, failed: failed, patternAlerts: alerts);
  }

  // --- Notifications ------------------------------------------------------

  Future<({int unreadCount, List<AppNotification> items})> notifications() async {
    final dynamic response = await _api.getJson('/notifications');
    final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
    return (
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      items: ((json['notifications'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList(),
    );
  }

  Future<void> markNotificationRead(String id) async {
    await _api.postJson('/notifications/$id/read', null);
  }

  Future<void> markAllNotificationsRead() async {
    await _api.postJson('/notifications/read-all', null);
  }

  /// Registers the device for push delivery. Until a token is registered the
  /// backend flags critical notifications for the SMS fallback channel.
  Future<void> registerDevice(String pushToken, {String deviceLabel = 'Android device'}) async {
    await _api.postJson('/notifications/devices', <String, dynamic>{
      'pushToken': pushToken,
      'platform': 'android',
      'deviceLabel': deviceLabel,
    });
  }

  OfflineQueue get queue => _queue;
}
