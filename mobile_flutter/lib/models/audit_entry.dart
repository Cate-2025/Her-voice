import '../core/date_format.dart';

/// One line of the administrative audit trail (section 3.12 VI).
///
/// Every authorised action that touches a case, an evidence item or the pattern
/// detector is recorded so that access can be reviewed after the fact.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.at,
    this.actorId,
    this.actorRole,
    this.targetType,
    this.targetId,
    this.detail,
  });

  final String id;
  final String action;
  final DateTime? at;
  final String? actorId;
  final String? actorRole;
  final String? targetType;
  final String? targetId;
  final String? detail;

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id']?.toString() ?? '',
      action: json['action']?.toString() ?? 'UNKNOWN',
      at: HerVoiceDate.parse(json['at']),
      actorId: json['actorId']?.toString(),
      actorRole: json['actorRole']?.toString(),
      targetType: json['targetType']?.toString(),
      targetId: json['targetId']?.toString(),
      detail: json['detail']?.toString(),
    );
  }

  String get whenLabel => HerVoiceDate.dayTime(at);

  /// Readable form of the machine action code.
  String get actionLabel {
    return action
        .split('_')
        .map((String word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  bool get bySystem => actorRole == 'SYSTEM' || actorRole == null;
}
