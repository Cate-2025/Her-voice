import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// One incident waiting to reach the server, together with the number of failed
/// attempts so the UI can explain why it is still on the device.
class PendingIncident {
  const PendingIncident({
    required this.clientRef,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final String clientRef;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Body sent to `/reports/sync`; the client reference makes the replay
  /// idempotent on the server.
  Map<String, dynamic> get body => <String, dynamic>{
        ...payload,
        'clientRef': clientRef,
      };
}

/// Evidence captured while offline: the bytes stay in the app's own storage and
/// are uploaded once connectivity returns.
class PendingEvidence {
  const PendingEvidence({
    required this.id,
    required this.reportRef,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.kind,
    required this.capturedAt,
    this.note,
    this.lawfulDeclaration = false,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String reportRef;
  final String filePath;
  final String fileName;
  final String mimeType;
  final String kind;
  final DateTime capturedAt;
  final String? note;
  final bool lawfulDeclaration;
  final int attempts;
  final String? lastError;

  /// Serialises into the exact body shape the evidence route expects, so the
  /// same code path serves online and offline uploads.
  Map<String, dynamic> toUploadBody(List<int> bytes) => <String, dynamic>{
        'fileName': fileName,
        'mimeType': mimeType,
        'kind': kind,
        'note': note,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'lawfulDeclaration': lawfulDeclaration,
        'dataBase64': base64Encode(bytes),
      };
}

/// Local draft queue backing the offline-first requirement (sections 3.7 and
/// 7.3). Incidents and evidence are written here whenever the device cannot
/// reach the backend, and flushed once connectivity is restored.
class OfflineQueue {
  OfflineQueue._(this._database);

  final Database _database;

  static const String _incidentTable = 'pending_incidents';
  static const String _evidenceTable = 'pending_evidence';

  static Future<OfflineQueue> open({String? overridePath}) async {
    final String path = overridePath ?? p.join(await getDatabasesPath(), 'hervoice_queue.db');
    final Database database = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_incidentTable (
            client_ref TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE $_evidenceTable (
            id TEXT PRIMARY KEY,
            report_ref TEXT NOT NULL,
            file_path TEXT NOT NULL,
            file_name TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            kind TEXT NOT NULL,
            note TEXT,
            lawful_declaration INTEGER NOT NULL DEFAULT 0,
            captured_at INTEGER NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT
          )
        ''');
      },
    );
    return OfflineQueue._(database);
  }

  // --- Incidents ----------------------------------------------------------

  Future<void> enqueueIncident(PendingIncident incident) async {
    await _database.insert(
      _incidentTable,
      <String, Object?>{
        'client_ref': incident.clientRef,
        'payload': jsonEncode(incident.payload),
        'created_at': incident.createdAt.millisecondsSinceEpoch,
        'attempts': incident.attempts,
        'last_error': incident.lastError,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingIncident>> pendingIncidents() async {
    final List<Map<String, Object?>> rows = await _database.query(
      _incidentTable,
      orderBy: 'created_at ASC',
    );
    return rows.map((Map<String, Object?> row) {
      return PendingIncident(
        clientRef: row['client_ref']! as String,
        payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        attempts: (row['attempts'] as int?) ?? 0,
        lastError: row['last_error'] as String?,
      );
    }).toList();
  }

  Future<void> recordIncidentFailure(String clientRef, String error) async {
    await _database.rawUpdate(
      'UPDATE $_incidentTable SET attempts = attempts + 1, last_error = ? WHERE client_ref = ?',
      <Object?>[error, clientRef],
    );
  }

  Future<void> removeIncident(String clientRef) async {
    await _database.delete(
      _incidentTable,
      where: 'client_ref = ?',
      whereArgs: <Object?>[clientRef],
    );
  }

  // --- Evidence -----------------------------------------------------------

  Future<void> enqueueEvidence(PendingEvidence evidence) async {
    await _database.insert(
      _evidenceTable,
      <String, Object?>{
        'id': evidence.id,
        'report_ref': evidence.reportRef,
        'file_path': evidence.filePath,
        'file_name': evidence.fileName,
        'mime_type': evidence.mimeType,
        'kind': evidence.kind,
        'note': evidence.note,
        'lawful_declaration': evidence.lawfulDeclaration ? 1 : 0,
        'captured_at': evidence.capturedAt.millisecondsSinceEpoch,
        'attempts': evidence.attempts,
        'last_error': evidence.lastError,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PendingEvidence>> pendingEvidence({String? reportRef}) async {
    final List<Map<String, Object?>> rows = await _database.query(
      _evidenceTable,
      where: reportRef == null ? null : 'report_ref = ?',
      whereArgs: reportRef == null ? null : <Object?>[reportRef],
      orderBy: 'captured_at ASC',
    );
    return rows.map((Map<String, Object?> row) {
      return PendingEvidence(
        id: row['id']! as String,
        reportRef: row['report_ref']! as String,
        filePath: row['file_path']! as String,
        fileName: row['file_name']! as String,
        mimeType: row['mime_type']! as String,
        kind: row['kind']! as String,
        note: row['note'] as String?,
        lawfulDeclaration: ((row['lawful_declaration'] as int?) ?? 0) == 1,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(row['captured_at']! as int),
        attempts: (row['attempts'] as int?) ?? 0,
        lastError: row['last_error'] as String?,
      );
    }).toList();
  }

  Future<void> recordEvidenceFailure(String id, String error) async {
    await _database.rawUpdate(
      'UPDATE $_evidenceTable SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      <Object?>[error, id],
    );
  }

  Future<void> removeEvidence(String id) async {
    await _database.delete(_evidenceTable, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  // --- Summary ------------------------------------------------------------

  /// Number of items the student is still carrying on the device.
  Future<int> pendingCount() async {
    final List<Map<String, Object?>> result = await _database.rawQuery(
      'SELECT (SELECT COUNT(*) FROM $_incidentTable) AS incidents, '
      '(SELECT COUNT(*) FROM $_evidenceTable) AS evidence',
    );
    if (result.isEmpty) return 0;
    return ((result.first['incidents'] as int?) ?? 0) +
        ((result.first['evidence'] as int?) ?? 0);
  }

  Future<void> clearAll() async {
    await _database.delete(_incidentTable);
    await _database.delete(_evidenceTable);
  }

  Future<void> close() => _database.close();
}
