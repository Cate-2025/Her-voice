import '../models/app_notification.dart';
import '../models/audit_entry.dart';
import '../models/enums.dart';
import '../models/incident_report.dart';
import 'api_client.dart';

/// Institutional-side API calls (section 7.2, "Authorized Admin Dashboard").
///
/// Every method here requires an officer or administrator account; the server
/// enforces that and writes an audit entry for the action.
class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<AdminDashboard> dashboard() async {
    final dynamic response = await _api.getJson('/admin/dashboard');
    return AdminDashboard.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<List<CaseSummary>> cases({
    CaseStatus? status,
    ReportingType? reportingType,
    bool flaggedOnly = false,
  }) async {
    final dynamic response = await _api.getJson('/admin/cases', query: <String, dynamic>{
      if (status != null) 'status': status.wire,
      if (reportingType != null) 'reportingType': reportingType.wire,
      if (flaggedOnly) 'flaggedOnly': 'true',
    });
    return ((response as Map)['cases'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(CaseSummary.fromJson)
        .toList();
  }

  /// Institutional view of a case: reporter identity is already stripped by the
  /// server for anonymous reports.
  Future<IncidentReport> caseDetail(String caseId) async {
    final dynamic response = await _api.getJson('/admin/cases/$caseId');
    return IncidentReport.fromJson(Map<String, dynamic>.from((response as Map)['case'] as Map));
  }

  Future<IncidentReport> updateStatus(String caseId, CaseStatus status, {String? note}) async {
    final dynamic response = await _api.patchJson('/admin/cases/$caseId/status', <String, dynamic>{
      'status': status.wire,
      'note': note,
    });
    return IncidentReport.fromJson(Map<String, dynamic>.from((response as Map)['case'] as Map));
  }

  Future<IncidentReport> assignCase(String caseId) async {
    final dynamic response = await _api.postJson('/admin/cases/$caseId/assign', null);
    return IncidentReport.fromJson(Map<String, dynamic>.from((response as Map)['case'] as Map));
  }

  /// Sends a secure message. The student only receives a generic notification;
  /// the text itself stays inside the application.
  Future<IncidentReport> sendSecureMessage(String caseId, String message) async {
    final dynamic response = await _api.postJson('/admin/cases/$caseId/message', <String, dynamic>{
      'message': message,
    });
    return IncidentReport.fromJson(Map<String, dynamic>.from((response as Map)['case'] as Map));
  }

  Future<({int threshold, String notice, List<PatternAlert> alerts})> patternAlerts() async {
    final dynamic response = await _api.getJson('/admin/pattern-alerts');
    final Map<String, dynamic> json = Map<String, dynamic>.from(response as Map);
    return (
      threshold: (json['threshold'] as num?)?.toInt() ?? 3,
      notice: json['notice']?.toString() ?? '',
      alerts: ((json['alerts'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PatternAlert.fromJson)
          .toList(),
    );
  }

  Future<List<AuditEntry>> auditLog({int limit = 100}) async {
    final dynamic response = await _api.getJson('/admin/audit-log', query: <String, dynamic>{
      'limit': limit,
    });
    return ((response as Map)['entries'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(AuditEntry.fromJson)
        .toList();
  }
}
