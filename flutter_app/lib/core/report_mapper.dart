import 'report_models.dart';

/// Converts API details into the presentation model without network side effects.
PreviewCase reportFromJson(dynamic json) {
  final timeline = json['timeline'] as List;
  final first = timeline.isEmpty ? null : timeline.first;
  final status = switch (json['status']) {
    'submitted' => 'Submitted',
    'received' => 'Received',
    'under_review' => 'Under review',
    'action_required' => 'Action required',
    'closed' => 'Closed',
    _ => 'Unknown',
  };
  final date = DateTime.parse(
    (json['submitted_at'] ?? json['created_at']) as String,
  ).toLocal();
  return PreviewCase(
    id: json['id'] as String,
    date: date,
    status: status,
    narrative: timeline.map((e) => e['narrative'] as String).join('\n\n'),
    location: first?['location_hint'] as String? ?? '',
    subject: json['subject_staff_ref'] as String,
    course: json['course_ref'] as String? ?? '',
    occurredAt: first == null
        ? null
        : DateTime.parse(first['occurred_at'] as String).toLocal(),
    events: (json['status_history'] as List? ?? []).isEmpty
        ? [(status, 'Current status · update dates unavailable')]
        : (json['status_history'] as List).map((event) {
            final date = DateTime.parse(event['occurred_at'] as String)
                .toLocal();
            final label =
                {
                  'submitted': 'Submitted',
                  'received': 'Received',
                  'under_review': 'Under review',
                  'action_required': 'Action required',
                  'closed': 'Closed',
                }[event['status']] ??
                'Unknown';
            return (
              label,
              '${shortDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
            );
          }).toList(),
    attachments: (json['evidence'] as List? ?? [])
        .map(
          (e) =>
              Attachment(e['original_name'] as String, e['byte_size'] as int),
        )
        .toList(),
  );
}
