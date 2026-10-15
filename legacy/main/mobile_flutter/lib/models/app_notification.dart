import '../core/date_format.dart';
import 'incident_report.dart';

/// A secure notification (section 3.6).
///
/// [title] is intentionally generic so that nothing sensitive appears on a lock
/// screen. [body] is also neutral; the detailed case information is only
/// reachable after the student authenticates inside the application.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.read,
    this.caseId,
    this.caseReference,
    this.channel,
    this.createdAt,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final bool read;
  final String? caseId;
  final String? caseReference;
  final String? channel;
  final DateTime? createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'SYSTEM',
      title: json['title']?.toString() ?? 'HERVOICE notification.',
      body: json['body']?.toString() ?? '',
      read: json['read'] == true,
      caseId: json['caseId']?.toString(),
      caseReference: json['caseReference']?.toString(),
      channel: json['channel']?.toString(),
      createdAt: HerVoiceDate.parse(json['createdAt']),
    );
  }

  /// True when the fallback SMS channel was used because no push token is
  /// registered for the device.
  bool get usedSmsFallback => channel == 'SMS_FALLBACK';

  String get whenLabel => HerVoiceDate.timeline(createdAt);
}

/// Internal pattern alert for authorised personnel (section 3.5).
///
/// The alert never states that a member of staff is guilty; it only reports that
/// several independent allegations share a staff identifier.
class PatternAlert {
  const PatternAlert({
    required this.staffIdentifier,
    required this.reportCount,
    required this.independentReporterCount,
    required this.behaviourSimilarity,
    required this.severity,
    this.sharedKeywords = const <String>[],
    this.relatedCourses = const <String>[],
    this.relatedLocations = const <String>[],
    this.recommendation,
    this.notice,
    this.detectedAt,
  });

  final String staffIdentifier;
  final int reportCount;
  final int independentReporterCount;
  final double behaviourSimilarity;
  final String severity;
  final List<String> sharedKeywords;
  final List<String> relatedCourses;
  final List<String> relatedLocations;
  final String? recommendation;
  final String? notice;
  final DateTime? detectedAt;

  factory PatternAlert.fromJson(Map<String, dynamic> json) {
    List<String> readStringList(Object? value) {
      if (value is! List) return <String>[];
      return value.map((dynamic item) => item.toString()).toList();
    }

    return PatternAlert(
      staffIdentifier: json['staffIdentifier']?.toString() ?? 'Unknown identifier',
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      independentReporterCount: (json['independentReporterCount'] as num?)?.toInt() ?? 0,
      behaviourSimilarity: (json['behaviourSimilarity'] as num?)?.toDouble() ?? 0,
      severity: json['severity']?.toString() ?? 'MODERATE',
      sharedKeywords: readStringList(json['sharedKeywords']),
      relatedCourses: readStringList(json['relatedCourses']),
      relatedLocations: readStringList(json['relatedLocations']),
      recommendation: json['recommendation']?.toString(),
      notice: json['notice']?.toString(),
      detectedAt: HerVoiceDate.parse(json['detectedAt']),
    );
  }

  bool get isHighSeverity => severity == 'HIGH';

  /// Similarity rendered as a percentage for the dashboard.
  String get similarityLabel => '${(behaviourSimilarity * 100).round()}%';
}

/// Aggregated counts for the institutional dashboard (section 7.2).
class AdminDashboard {
  const AdminDashboard({
    required this.totalReportsReceived,
    required this.drafts,
    required this.evidenceItems,
    required this.quickSupportRequests,
    required this.byStatus,
    required this.byReportingType,
    required this.alerts,
    required this.cases,
    this.notice,
  });

  final int totalReportsReceived;
  final int drafts;
  final int evidenceItems;
  final int quickSupportRequests;
  final Map<String, int> byStatus;
  final Map<String, int> byReportingType;
  final List<PatternAlert> alerts;
  final List<CaseSummary> cases;
  final String? notice;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    Map<String, int> readCounts(Object? value) {
      if (value is! Map) return <String, int>{};
      return value.map(
        (Object? key, Object? count) => MapEntry(
          key.toString(),
          count is num ? count.toInt() : int.tryParse(count.toString()) ?? 0,
        ),
      );
    }

    return AdminDashboard(
      totalReportsReceived: (json['totalReportsReceived'] as num?)?.toInt() ?? 0,
      drafts: (json['drafts'] as num?)?.toInt() ?? 0,
      evidenceItems: (json['evidenceItems'] as num?)?.toInt() ?? 0,
      quickSupportRequests: (json['quickSupportRequests'] as num?)?.toInt() ?? 0,
      byStatus: readCounts(json['byStatus']),
      byReportingType: readCounts(json['byReportingType']),
      alerts: ((json['activePatternAlerts'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(PatternAlert.fromJson)
          .toList(),
      cases: ((json['cases'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CaseSummary.fromJson)
          .toList(),
      notice: json['notice']?.toString(),
    );
  }
}
