import '../core/date_format.dart';
import 'enums.dart';

/// One entry on the incident timeline (section 3.3).
///
/// The timeline exists so that a student does not have to remember and
/// repeatedly explain every event, and so that an institution sees a structured
/// chronological record rather than a single narrative.
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.at,
    this.detail,
    this.actorRole,
  });

  final String id;
  final TimelineEventKind kind;
  final String title;
  final String? detail;
  final DateTime? at;
  final String? actorRole;

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id']?.toString() ?? '',
      kind: TimelineEventKind.fromWire(json['kind']),
      title: json['title']?.toString() ?? 'Timeline event',
      detail: json['detail']?.toString(),
      at: HerVoiceDate.parse(json['at']),
      actorRole: json['actorRole']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.wire,
        'title': title,
        'detail': detail,
        'at': at?.toUtc().toIso8601String(),
      };

  /// e.g. "12 September, 4:30 PM"
  String get whenLabel => HerVoiceDate.timeline(at);

  /// True when the entry came from institutional personnel rather than the
  /// student, which is highlighted differently on the timeline.
  bool get fromInstitution => actorRole != null && actorRole != 'STUDENT' && actorRole != 'SYSTEM';
}
