import 'report_store.dart';
export 'report_store.dart';

/// Fictional data is created only when preview mode is explicitly selected.
class DemoStore extends ReportStore {
  DemoStore() : super(isConnected: false) {
    drafts.addAll([
      IncidentDraft(
        id: 'draft-example',
        subject: 'Fictional staff member',
        narrative: 'A fictional incident to explore the draft editor. You can edit or delete this example.',
        location: 'Example campus building',
        occurredAt: DateTime(2026, 10, 9, 14, 30),
      ),
    ]);
    cases.addAll([
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
        events: [
          ('Submitted', '22 Sep · 14:20'),
          ('Received', '23 Sep · 09:30'),
        ],
      ),
    ]);
    active = drafts.firstOrNull;
  }
  int _next = 1;
  @override
  Future<PreviewCase> submit() async => submitPreview();
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
}
