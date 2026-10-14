import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/demo_store.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store});
  final DemoStore store;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _form = GlobalKey<FormState>();
  int _step = 0;
  bool _picking = false;
  static const _extensions = ['jpg', 'jpeg', 'png', 'pdf', 'mp3', 'm4a'];

  Future<void> _pickDate(IncidentDraft draft) async {
    final date = await showDatePicker(
      context: context,
      initialDate: draft.occurredAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: draft.occurredAt == null
          ? const TimeOfDay(hour: 12, minute: 0)
          : TimeOfDay.fromDateTime(draft.occurredAt!),
    );
    if (time == null || !mounted) return;
    setState(
      () => draft.occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
    widget.store.changed();
  }

  Future<void> _pickFiles(IncidentDraft draft) async {
    setState(() => _picking = true);
    try {
      final files = await openFiles(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Evidence', extensions: _extensions),
        ],
      );
      if (!mounted) return;
      for (final file in files) {
        if (!_extensions.contains(file.name.split('.').last.toLowerCase()) ||
            !file.name.contains('.')) {
          showNotice(context, 'Choose a JPG, PNG, PDF, MP3, or M4A file.');
          continue;
        }
        final bytes = await file.length();
        if (!mounted) return;
        if (bytes > 10 * 1024 * 1024 || bytes == 0) {
          showNotice(context, 'Choose a non-empty file up to 10 MB.');
          continue;
        }
        if (draft.attachments.any(
          (a) => a.name == file.name && a.bytes == bytes,
        )) {
          continue;
        }
        if (draft.attachments.length >= 5) {
          showNotice(context, 'You can select up to five files.');
          break;
        }
        draft.attachments.add(Attachment(file.name, bytes));
      }
      widget.store.changed();
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'The file picker could not open. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool _valid(IncidentDraft draft) {
    if (!(_form.currentState?.validate() ?? false)) return false;
    if (draft.occurredAt == null) {
      showNotice(
        context,
        'Choose the incident date and time before continuing.',
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.store.active;
    if (draft == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Start with your words.',
            subtitle: 'You can pause at any time.',
          ),
          FilledButton(
            onPressed: () {
              widget.store.startDraft();
              setState(() {});
            },
            child: const Text('Start a draft'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/records'),
          icon: const Icon(Icons.arrow_back_rounded, size: 17),
          label: const Text('Back to my records'),
        ),
        const SizedBox(height: 18),
        const PageHeading(
          eyebrow: 'YOUR PACE, YOUR CHOICE',
          title: 'Document an incident.',
          subtitle: 'Start with what you feel ready to share. You can return to this later.',
        ),
        Wrap(
          spacing: 18,
          runSpacing: 12,
          children: [
            for (var i = 0; i < 3; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: i <= _step
                        ? VoiceColors.plum
                        : VoiceColors.line,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        color: i <= _step ? Colors.white : VoiceColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    ['Incident', 'Evidence', 'Review'][i],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: i <= _step ? VoiceColors.plum : VoiceColors.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 26),
        if (_step == 0)
          Form(
            key: _form,
            child: PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('Tell us what happened'),
                  const Text(
                    'Your own words are enough. You don’t need to have everything figured out.',
                    style: TextStyle(color: VoiceColors.muted),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    'What happened?',
                    TextFormField(
                      key: const Key('narrative-field'),
                      initialValue: draft.narrative,
                      minLines: 5,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        hintText: 'Write what you remember, in your own words…',
                      ),
                      onChanged: (v) => draft.narrative = v,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Add a description before reviewing.'
                          : null,
                      maxLength: 10000,
                    ),
                  ),
                  _field(
                    'Person involved',
                    TextFormField(
                      key: const Key('subject-field'),
                      initialValue: draft.subject,
                      decoration: const InputDecoration(
                        hintText: 'Name or staff reference',
                      ),
                      onChanged: (v) => draft.subject = v,
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'Add a name or reference for this preview.'
                          : null,
                      maxLength: 128,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'When did it happen?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('date-picker'),
                    onPressed: () => _pickDate(draft),
                    icon: const Icon(Icons.calendar_today_outlined, size: 17),
                    label: Text(
                      draft.occurredAt == null
                          ? 'Choose date and time'
                          : '${shortDate(draft.occurredAt!)} · ${TimeOfDay.fromDateTime(draft.occurredAt!).format(context)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Uses this device’s local time zone.',
                    style: TextStyle(fontSize: 10, color: VoiceColors.muted),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    'Where did it happen?  (optional)',
                    TextFormField(
                      initialValue: draft.location,
                      decoration: const InputDecoration(
                        hintText: 'A place or setting',
                      ),
                      onChanged: (v) => draft.location = v,
                      maxLength: 255,
                    ),
                  ),
                  _field(
                    'Course or unit  (optional)',
                    TextFormField(
                      initialValue: draft.course,
                      decoration: const InputDecoration(
                        hintText: 'Course or unit name',
                      ),
                      onChanged: (v) => draft.course = v,
                      maxLength: 128,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_step == 1)
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Add evidence, if you choose'),
                const Text(
                  'You can continue without a file. Only include information you feel comfortable sharing.',
                  style: TextStyle(color: VoiceColors.muted),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: VoiceColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: VoiceColors.line),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 36,
                        color: VoiceColors.plum,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Photos, documents, or audio',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'JPG, PNG, PDF, MP3, M4A · up to 10 MB each',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: VoiceColors.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _picking ? null : () => _pickFiles(draft),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          _picking ? 'Opening picker…' : 'Choose files',
                        ),
                      ),
                    ],
                  ),
                ),
                for (final file in draft.attachments)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const IconTile(
                          Icons.insert_drive_file_outlined,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${file.sizeLabel} · Selected for preview',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: VoiceColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${file.name}',
                          onPressed: () {
                            setState(() => draft.attachments.remove(file));
                            widget.store.changed();
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                const Text(
                  'In this preview, only file names and sizes are retained for the session. Files are not uploaded.',
                  style: TextStyle(fontSize: 11, color: VoiceColors.muted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              key: const Key('save-draft'),
              onPressed: () {
                widget.store.changed();
                context.go('/records');
                showNotice(context, 'Draft kept for this preview session.');
              },
              child: const Text('Save draft & leave'),
            ),
            if (_step == 1)
              OutlinedButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Back'),
              ),
            FilledButton(
              key: const Key('editor-next'),
              onPressed: _picking
                  ? null
                  : () {
                      if (_step == 0 && _valid(draft)) {
                        setState(() => _step = 1);
                        widget.store.changed();
                      } else if (_step == 1) {
                        widget.store.changed();
                        context.go('/review');
                      }
                    },
              child: Text(
                _step == 0 ? 'Continue to evidence' : 'Review report',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Nothing is sent while you explore this preview.',
          style: TextStyle(color: VoiceColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _field(String label, Widget field) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 10),
        field,
      ],
    ),
  );
}
