import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../models/enums.dart';
import '../../models/evidence_item.dart';
import '../../models/incident_report.dart';
import '../../models/timeline_event.dart';
import '../../state/case_controller.dart';
import '../../widgets/privacy_notice.dart';
import '../../widgets/section_card.dart';
import '../evidence/evidence_vault_screen.dart';

/// Case detail: status tracker, incident timeline, evidence vault and the
/// actions a student can still take (section 3.1 C and 3.3).
class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CaseController>().openCase(widget.caseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.watch<CaseController>();
    final IncidentReport? report = cases.selected;

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case')),
        body: cases.busy
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Text(
                  cases.errorMessage ?? 'This case could not be loaded.',
                  style: const TextStyle(color: HerVoiceColors.textMuted),
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(report.reference),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => cases.openCase(widget.caseId),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => cases.openCase(widget.caseId),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: <Widget>[
            _StatusTracker(status: report.status),
            const SizedBox(height: 8),
            _SummaryCard(report: report),
            const SizedBox(height: 8),
            _DescriptionCard(report: report),
            const SizedBox(height: 8),
            _EvidenceSection(report: report),
            const SizedBox(height: 8),
            _TimelineSection(events: report.timeline),
            const SizedBox(height: 8),
            _ActionsSection(report: report),
          ],
        ),
      ),
    );
  }
}

/// Visual progress through the case lifecycle so the student can see where a
/// complaint currently sits without phoning the office.
class _StatusTracker extends StatelessWidget {
  const _StatusTracker({required this.status});

  final CaseStatus status;

  @override
  Widget build(BuildContext context) {
    final int current = status.stepIndex;
    return SectionCard(
      title: 'Case status',
      icon: Icons.timeline_outlined,
      trailing: CaseStatusChip(status: status),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: CaseStatus.flow.isEmpty ? 0 : (current + 1) / CaseStatus.flow.length,
              minHeight: 8,
              backgroundColor: HerVoiceColors.pinkLight,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(CaseStatus.flow.length, (int index) {
              final CaseStatus step = CaseStatus.flow[index];
              final bool done = index <= current;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: done ? HerVoiceColors.pinkPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: done ? HerVoiceColors.pinkPrimary : HerVoiceColors.pinkMedium,
                  ),
                ),
                child: Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: done ? Colors.white : HerVoiceColors.textMuted,
                    fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Incident record',
      icon: Icons.fact_check_outlined,
      trailing: ReportingTypeChip(type: report.reportingType),
      child: Column(
        children: <Widget>[
          _row(Icons.person_outline, 'Person involved', report.person),
          _row(Icons.menu_book_outlined, 'Course or unit', report.course),
          _row(Icons.place_outlined, 'Location', report.location),
          _row(Icons.event_outlined, 'Incident date', HerVoiceDate.dayTime(report.incidentOccurredAt)),
          _row(Icons.schedule_outlined, 'Submitted', HerVoiceDate.dayTime(report.submittedAt)),
          if (report.witnesses != null)
            _row(Icons.groups_outlined, 'Witnesses', report.witnesses!),
          if (report.coordinateLabel != null)
            _row(Icons.my_location, 'Coordinates', report.coordinateLabel!),
          if (report.syncedFromOffline)
            _row(Icons.cloud_sync_outlined, 'Captured', 'Recorded offline, then synchronised'),
          if (report.reporterPseudonym != null)
            _row(Icons.person_search_outlined, 'Reporter', report.reporterPseudonym!),
        ],
      ),
    );
  }

  static Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: HerVoiceColors.pinkPrimaryDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: HerVoiceColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'What was reported',
      icon: Icons.format_quote_outlined,
      child: Text(
        report.description,
        style: const TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

/// Evidence Vault for this case (section 3.1 B).
class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.report});

  final IncidentReport report;

  @override
  Widget build(BuildContext context) {
    final List<EvidenceItem> items = report.evidence;

    return SectionCard(
      title: 'Evidence vault',
      subtitle: 'Evidence is kept with this incident and is only visible to you and '
          'authorised personnel.',
      icon: Icons.vpn_key_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No evidence attached yet. A report without evidence can still be recorded, '
                'but if you have messages, screenshots, emails or photographs, preserving '
                'them now helps.',
                style: TextStyle(fontSize: 12, color: HerVoiceColors.textMuted, height: 1.4),
              ),
            )
          else
            ...items.map((EvidenceItem item) => _EvidenceRow(item: item, reportId: report.id)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EvidenceVaultScreen(caseId: report.id),
              ),
            ),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(items.isEmpty ? 'Add supporting evidence' : 'Manage evidence'),
          ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.item, required this.reportId});

  final EvidenceItem item;
  final String reportId;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        item.pendingSync ? Icons.cloud_upload_outlined : Icons.description_outlined,
        color: HerVoiceColors.pinkPrimaryDark,
      ),
      title: Text(item.originalName, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '${item.kind.label} - ${item.sizeLabel} - sha256 ${item.fingerprint}\n'
        'Captured ${HerVoiceDate.timeline(item.capturedAt)}'
        '${item.pendingSync ? ' - waiting to upload' : ''}',
        style: const TextStyle(fontSize: 11),
      ),
      isThreeLine: true,
      trailing: item.pendingSync
          ? null
          : IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline, color: HerVoiceColors.danger),
              onPressed: () => context.read<CaseController>().removeEvidence(reportId, item.id),
            ),
    );
  }
}

/// The incident timeline of section 3.3. Entries from institutional personnel
/// are highlighted so a secure message is not mistaken for her own note.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.events});

  final List<TimelineEvent> events;

  static IconData iconFor(TimelineEventKind kind) {
    switch (kind) {
      case TimelineEventKind.incidentRecorded:
        return Icons.edit_note_outlined;
      case TimelineEventKind.evidenceAdded:
        return Icons.vpn_key_outlined;
      case TimelineEventKind.followUp:
        return Icons.add_alarm_outlined;
      case TimelineEventKind.reportSubmitted:
        return Icons.send_outlined;
      case TimelineEventKind.statusChanged:
        return Icons.flag_outlined;
      case TimelineEventKind.officerMessage:
        return Icons.mail_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const SectionCard(
        title: 'Incident timeline',
        icon: Icons.timeline_outlined,
        child: Text(
          'Your timeline is empty. Entries appear here as you record incidents, attach '
          'evidence and the institution updates a case.',
          style: TextStyle(fontSize: 12, color: HerVoiceColors.textMuted, height: 1.4),
        ),
      );
    }

    return SectionCard(
      title: 'Incident timeline',
      subtitle: '${events.length} entry(ies), oldest first.',
      icon: Icons.timeline_outlined,
      child: Column(
        children: events
            .map(
              (TimelineEvent event) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: event.fromInstitution
                              ? Colors.blue.shade50
                              : HerVoiceColors.pinkLight,
                          child: Icon(
                            iconFor(event.kind),
                            size: 16,
                            color: event.fromInstitution
                                ? Colors.blue.shade800
                                : HerVoiceColors.pinkPrimaryDark,
                          ),
                        ),
                        Container(width: 1.5, height: 28, color: HerVoiceColors.pinkMedium),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            event.whenLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: HerVoiceColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            event.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (event.detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                event.detail!,
                                style: const TextStyle(fontSize: 12, height: 1.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Actions the student can still take. Recording a follow-up keeps the timeline
/// alive without creating a new case, which is what section 3.1 A intends.
class _ActionsSection extends StatefulWidget {
  const _ActionsSection({required this.report});

  final IncidentReport report;

  @override
  State<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<_ActionsSection> {
  Future<void> _addFollowUp() async {
    final TextEditingController title = TextEditingController();
    final TextEditingController detail = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Record a follow-up incident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'For example: approached again after the lecture',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detail,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Anything else worth noting'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Add to timeline'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<CaseController>().addFollowUp(
          widget.report.id,
          title: title.text.trim().isEmpty ? 'Follow-up incident' : title.text.trim(),
          detail: detail.text.trim().isEmpty ? null : detail.text.trim(),
        );
    title.dispose();
    detail.dispose();
  }

  Future<void> _submitDraft() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Submit this report?'),
        content: const Text(
          'Once submitted, the institution receives your record through the pathway you '
          'chose. You can still add follow-up incidents and evidence afterwards.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<CaseController>().submitDraft(widget.report.id);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDraft = widget.report.status == CaseStatus.draft;
    return SectionCard(
      title: 'What you can do now',
      icon: Icons.help_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (isDraft) ...<Widget>[
            FilledButton.icon(
              onPressed: _submitDraft,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Submit this report'),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: _addFollowUp,
            icon: const Icon(Icons.add_alarm_outlined),
            label: const Text('Record a follow-up incident'),
          ),
          const SizedBox(height: 12),
          const PrivacyNotice(
            text: 'Authorised personnel are notified that you have a new confidential '
                'notification. Nothing about the case appears on your lock screen.',
          ),
        ],
      ),
    );
  }
}
