import 'package:flutter/foundation.dart';

class Attachment {
  const Attachment(this.name, this.bytes);
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
  final String status;
  final String narrative;
  final String location;
  final List<(String, String)> events;
  final String subject, course;
  final DateTime? occurredAt;
  final List<Attachment> attachments;
}

/// Explicit fictional preview state. No credentials, persistence, or API fallback.
class ReportStore extends ChangeNotifier {
  ReportStore({this.isConnected = false}) {
    if (isConnected) {
      drafts.clear();
      cases.clear();
    }
    active = drafts.firstOrNull;
  }
  final bool isConnected;
  bool get authenticated => !isConnected;
  bool get loading => false;
  String? get error => null;
  List<CaseUpdate> get updates => const [];
  Future<void> login(String email, String password) async {}
  void signOut() {}
  Future<void> refresh() async {}
  Future<void> readUpdate(String id) async {}
  Future<PreviewCase> submit() async => submitPreview();
  bool get submissionPending => false;
  bool draftPending(String id) => false;

  final drafts = <IncidentDraft>[
    IncidentDraft(
      id: 'draft-example',
      subject: 'Fictional staff member',
      narrative: 'A fictional incident to explore the draft editor. You can edit or delete this example.',
      location: 'Example campus building',
      occurredAt: DateTime(2026, 10, 9, 14, 30),
    ),
  ];
  final cases = <PreviewCase>[
    PreviewCase(
      id: 'HV-DEMO-024',
      date: DateTime(2026, 10, 7),
      status: 'Under review',
      narrative: 'This fictional case demonstrates how a submitted incident is presented. It does not represent a real person or event.',
      location: 'Example campus building',
      events: [
        ('Submitted', '7 Oct · 10:15'),
        ('Received', '8 Oct · 09:00'),
        ('Under review', '9 Oct · 11:40'),
      ],
    ),
    PreviewCase(
      id: 'HV-DEMO-018',
      date: DateTime(2026, 9, 22),
      status: 'Received',
      narrative: 'A second fictional report for exploring case tracking.',
      location: 'Example lecture room',
      events: [('Submitted', '22 Sep · 14:20'), ('Received', '23 Sep · 09:30')],
    ),
  ];
  bool updateRead = false;
  int _next = 1;
  IncidentDraft? active;

  IncidentDraft startDraft() {
    final draft = IncidentDraft(id: 'draft-${_next++}');
    drafts.insert(0, draft);
    active = draft;
    notifyListeners();
    return draft;
  }

  void openDraft(String id) {
    active = drafts.where((d) => d.id == id).firstOrNull;
    notifyListeners();
  }

  void changed() => notifyListeners();
  void deleteDraft(String id) {
    drafts.removeWhere((d) => d.id == id);
    if (active?.id == id) active = null;
    notifyListeners();
  }

  void markRead() {
    updateRead = true;
    notifyListeners();
  }

  PreviewCase submitPreview() {
    if (isConnected) throw StateError('Use connected submission.');
    final draft = active;
    if (draft == null || !draft.canSubmit || !drafts.contains(draft)) {
      throw StateError('Open a complete draft before submitting.');
    }
    final report = PreviewCase(
      id: 'HV-DEMO-${100 + _next++}',
      date: DateTime.now(),
      status: 'Submitted',
      narrative: draft.narrative,
      location: draft.location,
      subject: draft.subject,
      course: draft.course,
      occurredAt: draft.occurredAt,
      attachments: List.unmodifiable(draft.attachments),
      events: [('Submitted', 'Just now · preview only')],
    );
    cases.insert(0, report);
    drafts.remove(draft);
    active = null;
    notifyListeners();
    return report;
  }

  PreviewCase? caseById(String id) =>
      cases.where((c) => c.id == id).firstOrNull;
}

class DemoStore extends ReportStore {}

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
