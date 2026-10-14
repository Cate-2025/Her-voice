import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../models/enums.dart';
import '../../models/evidence_item.dart';
import '../../models/incident_report.dart';
import '../../models/timeline_event.dart';
import '../../state/admin_controller.dart';
import '../../state/auth_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

/// Case management for authorised personnel (architecture 7.2).
///
/// Reading a case, reading its evidence, changing its status, assigning it and
/// messaging the reporter are all audited server-side.
class AdminCaseScreen extends StatefulWidget {
  const AdminCaseScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<AdminCaseScreen> createState() => _AdminCaseScreenState();
}

class _AdminCaseScreenState extends State<AdminCaseScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().openCase(widget.caseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminController admin = context.watch<AdminController>();
    final IncidentReport? item = admin.selected;

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Case')),
        body: admin.busy
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    admin.errorMessage ?? 'This case could not be opened.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HerVoiceColors.textMuted),
                  ),
                ),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.reference),
        actions: <Widget>[
          IconButton(
            onPressed: () => admin.openCase(item.id),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: <Widget>[
          if (admin.errorMessage != null)
            ErrorBanner(message: admin.errorMessage!, onRetry: admin.clearError),
          SectionCard(
            title: 'Case',
            icon: Icons.fact_check_outlined,
            trailing: CaseStatusChip(status: item.status),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _row('Reporter', item.reporterPseudonym ?? 'not disclosed'),
                _row('Pathway', item.reportingType.label),
                _row('Person involved', item.person),
                _row('Course', item.course),
                _row('Location', item.location),
                _row('Incident date', HerVoiceDate.dayTime(item.incidentOccurredAt)),
                _row('Submitted', HerVoiceDate.dayTime(item.submittedAt)),
                _row('Assigned', item.assignedOfficerId == null ? 'Not yet' : 'Yes'),
                if (item.patternFlagged)
                  _row('Pattern', 'Flagged for review (not a finding)'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Allegation as written',
            icon: Icons.format_quote_outlined,
            child: Text(item.description, style: const TextStyle(fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 8),
          _EvidenceSection(item: item),
          const SizedBox(height: 8),
          _TimelineSection(item: item),
          const SizedBox(height: 8),
          _StatusSection(item: item, enabled: !admin.busy),
          const SizedBox(height: 8),
          _MessageSection(item: item, enabled: !admin.busy),
          if (context.watch<AuthController>().isAdmin) ...<Widget>[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: admin.busy
                  ? null
                  : () async {
                      final bool ok =
                          await context.read<AdminController>().assignToMe(item.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ok ? 'Case assigned to you' : 'Could not assign')),
                      );
                    },
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Assign this case to me'),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: HerVoiceColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Evidence list. Merely opening this section is already recorded server-side as
/// an evidence access event.
class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.item});

  final IncidentReport item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Preserved evidence (${item.evidence.length})',
      subtitle: 'Access to this section is recorded in the audit log.',
      icon: Icons.vpn_key_outlined,
      child: item.evidence.isEmpty
          ? const Text(
              'No evidence was preserved with this report. A report without evidence is '
              'still valid and must be handled on its own terms.',
              style: TextStyle(fontSize: 12, height: 1.4),
            )
          : Column(
              children: item.evidence
                  .map(
                    (EvidenceItem evidence) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined,
                          color: HerVoiceColors.pinkPrimaryDark),
                      title: Text(evidence.originalName,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${evidence.kind.label} - ${evidence.sizeLabel}\n'
                        'sha256 ${evidence.fingerprint}\n'
                        'Captured ${HerVoiceDate.timeline(evidence.capturedAt)}'
                        '${evidence.lawfulDeclaration ? ' - lawful-use declared' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      isThreeLine: true,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.item});

  final IncidentReport item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Incident timeline',
      icon: Icons.timeline_outlined,
      child: item.timeline.isEmpty
          ? const Text('No entries yet.', style: TextStyle(fontSize: 12))
          : Column(
              children: item.timeline
                  .map(
                    (TimelineEvent event) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
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
                          Text(
                            event.title,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          if (event.detail != null)
                            Text(event.detail!,
                                style: const TextStyle(fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

/// Status updates. The student receives a deliberately vague notification and is
/// told the detail only after authenticating (section 3.6).
class _StatusSection extends StatefulWidget {
  const _StatusSection({required this.item, required this.enabled});

  final IncidentReport item;
  final bool enabled;

  @override
  State<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends State<_StatusSection> {
  CaseStatus _status = CaseStatus.underReview;
  final TextEditingController _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.item.status == CaseStatus.draft
        ? CaseStatus.underReview
        : widget.item.status;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final String? note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final bool ok = await context
        .read<AdminController>()
        .updateStatus(widget.item.id, _status, note: note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Status updated. The student has been notified.'
            : 'The status could not be updated.'),
      ),
    );
    if (ok) _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Update case status',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<CaseStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'New status'),
            items: CaseStatus.flow
                .where((CaseStatus status) => status != CaseStatus.draft)
                .map((CaseStatus status) => DropdownMenuItem<CaseStatus>(
                      value: status,
                      child: Text(status.label),
                    ))
                .toList(),
            onChanged: (CaseStatus? value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note for the record (optional)',
              helperText: 'Stored in the case history, not sent to the student verbatim',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.enabled ? _apply : null,
            child: const Text('Save status'),
          ),
        ],
      ),
    );
  }
}

/// Secure message to the reporter. The notification the student receives is
/// generic; the wording itself only exists inside the application.
class _MessageSection extends StatefulWidget {
  const _MessageSection({required this.item, required this.enabled});

  final IncidentReport item;
  final bool enabled;

  @override
  State<_MessageSection> createState() => _MessageSectionState();
}

class _MessageSectionState extends State<_MessageSection> {
  final TextEditingController _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    final bool ok = await context
        .read<AdminController>()
        .sendSecureMessage(widget.item.id, _message.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Secure message delivered' : 'The message could not be sent')),
    );
    if (ok) _message.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item.reportingType == ReportingType.anonymous) {
      return const SectionCard(
        title: 'Message the reporter',
        icon: Icons.mail_outline,
        child: Text(
          'This report is anonymous, so the platform has no address to send a message to. '
          'Reach the reporter through the institutional channels in the support directory '
          'instead.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      );
    }

    return SectionCard(
      title: 'Send a secure message',
      subtitle: 'The student is told only that a secure message is waiting.',
      icon: Icons.mail_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'For example: a counsellor can accompany you to the next meeting',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.enabled ? _send : null,
            child: const Text('Send securely'),
          ),
        ],
      ),
    );
  }
}

