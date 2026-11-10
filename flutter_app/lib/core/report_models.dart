class Attachment {
  const Attachment(
    this.name,
    this.bytes, {
    this.id,
    this.contentType,
    this.sha256,
  });
  final String? id, contentType, sha256;
  final String name;
  final int bytes;
  String get sizeLabel => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class IncidentDraft {
  IncidentDraft({
    required this.id,
    this.subject = '',
    this.course = '',
    this.location = '',
    this.narrative = '',
    this.occurredAt,
    List<Attachment>? attachments,
  }) : attachments = attachments ?? [];
  final String id;
  String subject;
  String course;
  String location;
  String narrative;
  DateTime? occurredAt;
  final List<Attachment> attachments;
  bool get canSubmit =>
      narrative.trim().isNotEmpty &&
      subject.trim().length >= 2 &&
      occurredAt != null;

  String get title => subject.trim().isEmpty
      ? 'Untitled incident'
      : 'Incident involving ${subject.trim()}';
}

class PreviewCase {
  const PreviewCase({
    required this.id,
    required this.date,
    required this.status,
    required this.narrative,
    required this.location,
    required this.events,
    this.subject = '',
    this.course = '',
    this.occurredAt,
    this.attachments = const [],
  });
  final String id;
  final DateTime date;
  String get title => 'Report · ${shortDate(date)}';
  String get submittedLabel =>
      'Submitted at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final String status;
  final String narrative;
  final String location;
  final List<(String, String)> events;
  final String subject, course;
  final DateTime? occurredAt;
  final List<Attachment> attachments;
}

class CaseUpdate {
  const CaseUpdate(this.id, this.body, this.date, this.read);
  final String id, body;
  final DateTime date;
  final bool read;
}

String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
