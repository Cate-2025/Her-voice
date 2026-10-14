import '../core/date_format.dart';
import 'enums.dart';
import 'evidence_item.dart';
import 'timeline_event.dart';

/// A status transition recorded by an authorised officer.
class StatusTransition {
  const StatusTransition({required this.status, this.at, this.byRole, this.note});

  final CaseStatus status;
  final DateTime? at;
  final String? byRole;
  final String? note;

  factory StatusTransition.fromJson(Map<String, dynamic> json) {
    return StatusTransition(
      status: CaseStatus.fromWire(json['status']),
      at: HerVoiceDate.parse(json['at']),
      byRole: json['byRole']?.toString(),
      note: json['note']?.toString(),
    );
  }
}

/// Compact case representation used by the student case list and the
/// institutional dashboard.
class CaseSummary {
  const CaseSummary({
    required this.id,
    required this.reference,
    required this.person,
    required this.course,
    required this.location,
    required this.reportingType,
    required this.status,
    this.incidentOccurredAt,
    this.submittedAt,
    this.evidenceCount = 0,
    this.timelineCount = 0,
    this.patternFlagged = false,
  });

  final String id;
  final String reference;
  final String person;
  final String course;
  final String location;
  final ReportingType reportingType;
  final CaseStatus status;
  final DateTime? incidentOccurredAt;
  final DateTime? submittedAt;
  final int evidenceCount;
  final int timelineCount;
  final bool patternFlagged;

  factory CaseSummary.fromJson(Map<String, dynamic> json) {
    return CaseSummary(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? 'unassigned',
      person: json['person']?.toString() ?? 'Not specified',
      course: json['course']?.toString() ?? 'Not specified',
      location: json['location']?.toString() ?? 'Not specified',
      reportingType: ReportingType.fromWire(json['reportingType']),
      status: CaseStatus.fromWire(json['status']),
      incidentOccurredAt: HerVoiceDate.parse(json['incidentOccurredAt']),
      submittedAt: HerVoiceDate.parse(json['submittedAt']),
      evidenceCount: (json['evidenceCount'] as num?)?.toInt() ?? 0,
      timelineCount: (json['timelineCount'] as num?)?.toInt() ?? 0,
      patternFlagged: json['patternFlagged'] == true,
    );
  }

  bool get isDraft => status == CaseStatus.draft;
}

/// Full incident record. A single object serves both the student view and the
/// institutional view; the server strips identity columns for the institutional
/// copy so that anonymous reports stay anonymous.
class IncidentReport {
  const IncidentReport({
    required this.id,
    required this.reference,
    required this.person,
    required this.course,
    required this.location,
    required this.description,
    required this.reportingType,
    required this.status,
    this.witnesses,
    this.locationLabel,
    this.latitude,
    this.longitude,
    this.incidentOccurredAt,
    this.submittedAt,
    this.createdAt,
    this.patternFlagged = false,
    this.syncedFromOffline = false,
    this.isAnonymous = false,
    this.reporterPseudonym,
    this.assignedOfficerId,
    this.evidence = const <EvidenceItem>[],
    this.timeline = const <TimelineEvent>[],
    this.statusHistory = const <StatusTransition>[],
  });

  final String id;
  final String reference;
  final String person;
  final String course;
  final String location;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final String description;
  final String? witnesses;
  final ReportingType reportingType;
  final CaseStatus status;
  final DateTime? incidentOccurredAt;
  final DateTime? submittedAt;
  final DateTime? createdAt;
  final bool patternFlagged;
  final bool syncedFromOffline;
  final bool isAnonymous;
  final String? reporterPseudonym;
  final String? assignedOfficerId;
  final List<EvidenceItem> evidence;
  final List<TimelineEvent> timeline;
  final List<StatusTransition> statusHistory;

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    return IncidentReport(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? 'unassigned',
      person: json['person']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      locationLabel: json['locationLabel']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      witnesses: json['witnesses']?.toString(),
      reportingType: ReportingType.fromWire(json['reportingType']),
      status: CaseStatus.fromWire(json['status']),
      incidentOccurredAt: HerVoiceDate.parse(json['incidentOccurredAt']),
      submittedAt: HerVoiceDate.parse(json['submittedAt']),
      createdAt: HerVoiceDate.parse(json['createdAt']),
      patternFlagged: json['patternFlagged'] == true,
      syncedFromOffline: json['syncedFromOffline'] == true,
      isAnonymous: json['isAnonymous'] == true,
      reporterPseudonym: json['reporterPseudonym']?.toString(),
      assignedOfficerId: json['assignedOfficerId']?.toString(),
      evidence: ((json['evidence'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(EvidenceItem.fromJson)
          .toList(),
      timeline: ((json['timeline'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(TimelineEvent.fromJson)
          .toList(),
      statusHistory: ((json['statusHistory'] as List<dynamic>?) ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(StatusTransition.fromJson)
          .toList(),
    );
  }

  /// Geographic fix captured with the incident, where the student consented to
  /// sharing it (section 3.11, GPS).
  String? get coordinateLabel {
    if (latitude == null || longitude == null) return null;
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  CaseSummary get summary => CaseSummary(
        id: id,
        reference: reference,
        person: person,
        course: course,
        location: location,
        reportingType: reportingType,
        status: status,
        incidentOccurredAt: incidentOccurredAt,
        submittedAt: submittedAt,
        evidenceCount: evidence.length,
        timelineCount: timeline.length,
        patternFlagged: patternFlagged,
      );
}

/// Payload used when a student creates an incident, whether she is online or
/// working from the offline queue (section 7.3).
class IncidentDraft {
  const IncidentDraft({
    required this.person,
    required this.course,
    required this.location,
    required this.description,
    required this.reportingType,
    required this.incidentOccurredAt,
    this.witnesses,
    this.locationLabel,
    this.latitude,
    this.longitude,
  });

  final String person;
  final String course;
  final String location;
  final String? locationLabel;
  final double? latitude;
  final double? longitude;
  final String description;
  final String? witnesses;
  final ReportingType reportingType;
  final DateTime incidentOccurredAt;

  Map<String, dynamic> toJson({
    String? clientRef,
    bool asDraft = false,
    bool syncedFromOffline = false,
  }) {
    return <String, dynamic>{
      'person': person,
      'course': course,
      'location': location,
      'locationLabel': locationLabel,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'witnesses': witnesses,
      'reportingType': reportingType.wire,
      'incidentOccurredAt': incidentOccurredAt.toUtc().toIso8601String(),
      'status': asDraft ? CaseStatus.draft.wire : CaseStatus.submitted.wire,
      if (clientRef != null) 'clientRef': clientRef,
      if (syncedFromOffline) 'syncedFromOffline': true,
    };
  }

  /// Rehydrates a draft that was serialised into the local queue.
  factory IncidentDraft.fromQueueJson(Map<String, dynamic> json) {
    return IncidentDraft(
      person: json['person']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      locationLabel: json['locationLabel']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      witnesses: json['witnesses']?.toString(),
      reportingType: ReportingType.fromWire(json['reportingType']),
      incidentOccurredAt:
          HerVoiceDate.parse(json['incidentOccurredAt']) ?? DateTime.now(),
    );
  }
}
