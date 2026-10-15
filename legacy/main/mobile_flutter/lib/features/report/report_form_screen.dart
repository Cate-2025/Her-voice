import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../data/hervoice_repository.dart';
import '../../models/enums.dart';
import '../../models/incident_report.dart';
import '../../state/case_controller.dart';
import '../../state/connectivity_controller.dart';
import '../../widgets/privacy_notice.dart';
import 'case_list_screen.dart';

/// Incident capture form (section 3.1 A) and reporting-pathway choice
/// (section 3.4).
///
/// The student is never forced to decide everything at once: she can save a
/// draft, add evidence, record follow-ups, and only submit when she is ready.
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _course = TextEditingController();
  final TextEditingController _person = TextEditingController();
  final TextEditingController _witnesses = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  ReportingType _reportingType = ReportingType.confidential;

  @override
  void dispose() {
    _description.dispose();
    _location.dispose();
    _course.dispose();
    _person.dispose();
    _witnesses.dispose();
    super.dispose();
  }

  IncidentDraft _buildDraft() => IncidentDraft(
        person: _person.text.trim(),
        course: _course.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
        witnesses: _witnesses.text.trim().isEmpty ? null : _witnesses.text.trim(),
        reportingType: _reportingType,
        incidentOccurredAt: _occurredAt,
      );

  Future<void> _pickDateTime() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _occurredAt.isAfter(now) ? now : _occurredAt,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null) return;
    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// Saves the record. When the device is offline the repository writes it to the
  /// local queue and the student is told exactly that (sections 3.7 and 7.3).
  Future<void> _save({required bool asDraft}) async {
    if (!_formKey.currentState!.validate()) return;

    final CaseController cases = context.read<CaseController>();
    final ConnectivityController connectivity = context.read<ConnectivityController>();

    try {
      final SubmitOutcome outcome = await cases.createIncident(
        _buildDraft(),
        saveAsDraft: asDraft,
        forceOffline: !connectivity.isOnline,
      );
      if (!mounted) return;

      await cases.loadCases(showSpinner: false);
      if (!mounted) return;

      if (outcome.queuedOffline) {
        _showDone(
          title: 'Saved on this device',
          message: 'Your record is stored securely on your phone and will be sent '
              'automatically when you have a connection again.',
          icon: Icons.save_outlined,
        );
        return;
      }

      if (asDraft) {
        _showDone(
          title: 'Draft saved',
          message: 'You can attach evidence, add follow-up incidents and submit it later.',
          icon: Icons.edit_note_outlined,
        );
        return;
      }

      _showDone(
        title: 'Report submitted',
        message: outcome.reference == null
            ? 'The institution has received your report.'
            : 'Your case reference is ${outcome.reference}. Keep it for your records. '
                '${AppConfig.allegationDisclaimer}',
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the record: $error')),
      );
    }
  }

  void _showDone({required String title, required String message, required IconData icon}) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: Icon(icon, size: 40, color: HerVoiceColors.success),
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: <Widget>[
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const CaseListScreen()),
              );
            },
            child: const Text('View my cases'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.watch<CaseController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Record an incident')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: <Widget>[
            const AllegationNotice(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                alignLabelWithHint: true,
                hintText: 'Describe what you allege in your own words, as close to the '
                    'time as you can.',
              ),
              validator: (String? value) {
                if ((value ?? '').trim().length < 20) {
                  return 'Please describe what happened in a little more detail';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const Icon(Icons.event_outlined),
                title: const Text('When did it happen?'),
                subtitle: Text(HerVoiceDate.dayTime(_occurredAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickDateTime,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Where did it happen?',
                prefixIcon: Icon(Icons.place_outlined),
                hintText: 'For example: Block C, Room 12, or the library car park',
              ),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the location' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _course,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Course or unit involved',
                prefixIcon: Icon(Icons.menu_book_outlined),
                hintText: 'For example: BSE 3106 Mobile Networks and Computing',
              ),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the course or unit' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _person,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Person involved',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Lecturer, teaching assistant or discussant',
              ),
              validator: (String? value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the name of the person involved' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _witnesses,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Witnesses (optional)',
                prefixIcon: Icon(Icons.groups_outlined),
                hintText: 'Only if you are comfortable naming them',
              ),
            ),
            const SizedBox(height: 18),
            _PathwaySelector(
              selected: _reportingType,
              onChanged: (ReportingType value) => setState(() => _reportingType = value),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: cases.busy ? null : () => _save(asDraft: true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save as a draft for later'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: cases.busy ? null : () => _save(asDraft: false),
              icon: cases.busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                cases.busy ? 'Sending...' : 'Submit ${_reportingType.label.toLowerCase()}',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can attach evidence and record follow-up incidents from the case screen '
              'after saving. Submitting a report is not a finding of misconduct.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the student choose how much to disclose (section 3.4). Each option
/// explains the consequence in plain language, because the choice is hard to
/// reverse once an officer starts acting on the report.
class _PathwaySelector extends StatelessWidget {
  const _PathwaySelector({required this.selected, required this.onChanged});

  final ReportingType selected;
  final ValueChanged<ReportingType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'How do you want to report?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'You can still track the case after submitting it.',
              style: TextStyle(fontSize: 12, color: HerVoiceColors.textMuted),
            ),
            const SizedBox(height: 12),
            ...ReportingType.values.map(
              (ReportingType type) => _PathwayOption(
                type: type,
                selected: type == selected,
                onTap: () => onChanged(type),
              ),
            ),
            if (selected == ReportingType.anonymous)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Anonymous reports help reveal recurring patterns, but they limit the '
                  'institution\'s ability to investigate your individual case or contact you '
                  'about it.',
                  style: TextStyle(fontSize: 12, color: HerVoiceColors.warning, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A reporting-pathway option.
///
/// This is a hand-rolled selectable tile rather than a `RadioListTile` because
/// the choice carries a long explanation and an explicit privacy consequence,
/// and because the built-in radio has been deprecated in current Flutter in
/// favour of `RadioGroup`.
class _PathwayOption extends StatelessWidget {
  const _PathwayOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ReportingType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? HerVoiceColors.pinkLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? HerVoiceColors.pinkPrimary : HerVoiceColors.pinkMedium,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? HerVoiceColors.pinkPrimary : HerVoiceColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    type.label,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    type.explanation,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

