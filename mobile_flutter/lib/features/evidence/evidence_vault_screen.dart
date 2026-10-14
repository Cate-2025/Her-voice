import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../data/hervoice_repository.dart';
import '../../models/enums.dart';
import '../../models/evidence_item.dart';
import '../../models/incident_report.dart';
import '../../state/case_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/privacy_notice.dart';

/// Evidence Vault (sections 3.1 B and 3.2).
///
/// Anything the student attaches is stored with the incident and, once the
/// institution holds it, becomes restricted: only the student and authorised
/// personnel can read it, and every institutional read is written to the audit
/// log.
class EvidenceVaultScreen extends StatefulWidget {
  const EvidenceVaultScreen({super.key, required this.caseId});

  final String caseId;

  @override
  State<EvidenceVaultScreen> createState() => _EvidenceVaultScreenState();
}

class _EvidenceVaultScreenState extends State<EvidenceVaultScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.watch<CaseController>();
    final IncidentReport? report =
        cases.selected != null && cases.selected!.id == widget.caseId ? cases.selected : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Evidence vault')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: report == null ? null : _showCaptureOptions,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add evidence'),
      ),
      body: report == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: <Widget>[
                const AllegationNotice(
                  compact: true,
                  message: 'Only attach material you are allowed to possess and share. '
                      'Recordings must be captured and used only where this is lawful and '
                      'permitted by institutional policy.',
                ),
                const SizedBox(height: 12),
                if (report.evidence.isEmpty)
                  const EmptyState(
                    icon: Icons.vpn_key_outlined,
                    title: 'No evidence attached',
                    message: 'Add screenshots of messages, emails, photographs, documents or a '
                        'permitted recording. You can report without evidence, but preserving '
                        'what you already have helps.',
                  )
                else
                  ...report.evidence.map(
                    (EvidenceItem item) => _EvidenceCard(item: item, caseId: report.id),
                  ),
              ],
            ),
    );
  }

  static IconData _iconFor(EvidenceKind kind) {
    switch (kind) {
      case EvidenceKind.screenshot:
        return Icons.screenshot_outlined;
      case EvidenceKind.photograph:
        return Icons.image_outlined;
      case EvidenceKind.email:
        return Icons.mail_outline;
      case EvidenceKind.document:
        return Icons.description_outlined;
      case EvidenceKind.audio:
        return Icons.mic_none_outlined;
      case EvidenceKind.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  /// Offers the four capture routes listed in section 3.2: screenshots and
  /// messages, photographs, documents, and permitted recordings.
  Future<void> _showCaptureOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.screenshot_outlined),
              title: const Text('Screenshot of a message'),
              subtitle: const Text('Pick a screenshot from your gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _captureImage(ImageSource.gallery, EvidenceKind.screenshot);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photograph'),
              subtitle: const Text('For example a notice, a document or an injury'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _captureImage(ImageSource.camera, EvidenceKind.photograph);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Choose a file'),
              subtitle: const Text('Emails, PDFs, documents or an audio file'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _captureFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined),
              title: const Text('Attach a permitted recording'),
              subtitle: const Text('Only where the recording was lawful to make and to share'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _captureFile(onlyAudio: true);
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'A report without evidence can still be recorded. Evidence helps, but it is '
                'never a requirement, and never a risk to your case if you do not have any.',
                style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage(ImageSource source, EvidenceKind kind) async {
    try {
      final XFile? file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null || !mounted) return;
      final int size = await File(file.path).length();
      if (size > AppConfig.maxEvidenceBytes) {
        _warn('That image is larger than the 10 MB prototype limit.');
        return;
      }
      await _confirmAndAttach(
        EvidenceUpload(
          path: file.path,
          fileName: file.name,
          mimeType: 'image/jpeg',
          kind: kind,
        ),
      );
    } catch (error) {
      if (mounted) _warn('Could not open the camera or gallery: $error');
    }
  }

  Future<void> _captureFile({bool onlyAudio = false}) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: onlyAudio ? FileType.audio : FileType.any,
        withData: false,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      final PlatformFile file = result.files.first;
      if (file.path == null) {
        _warn('That file could not be read from this device.');
        return;
      }
      if (file.size > AppConfig.maxEvidenceBytes) {
        _warn('That file is larger than the 10 MB prototype limit.');
        return;
      }

      await _confirmAndAttach(
        EvidenceUpload(
          path: file.path!,
          fileName: file.name,
          mimeType: file.extension == null ? 'application/octet-stream' : 'application/${file.extension}',
          kind: _inferKind(file.name),
        ),
      );
    } catch (error) {
      if (mounted) _warn('Could not open the file picker: $error');
    }
  }

  static EvidenceKind _inferKind(String fileName) {
    final String name = fileName.toLowerCase();
    if (name.endsWith('.eml') || name.endsWith('.msg')) return EvidenceKind.email;
    if (name.endsWith('.pdf') || name.endsWith('.doc') || name.endsWith('.docx') || name.endsWith('.txt')) {
      return EvidenceKind.document;
    }
    if (name.endsWith('.amr') || name.endsWith('.m4a') || name.endsWith('.mp3') || name.endsWith('.aac') || name.endsWith('.wav')) {
      return EvidenceKind.audio;
    }
    if (name.contains('screenshot') || name.contains('shot')) return EvidenceKind.screenshot;
    if (name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg')) return EvidenceKind.photograph;
    return EvidenceKind.other;
  }

  /// Final step before upload: classify the item, add a note, and - for audio -
  /// make the student confirm the recording was lawful to make and to share
  /// (the risk table in section 9).
  Future<void> _confirmAndAttach(EvidenceUpload upload) async {
    final TextEditingController note = TextEditingController();
    EvidenceKind kind = upload.kind;
    bool lawful = false;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: const Text('Attach this as evidence?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(upload.fileName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text(
                  'Stored with this incident only. SHA-256 is recorded so a later copy can be '
                  'compared against the original.',
                  style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<EvidenceKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Type of evidence'),
                  items: EvidenceKind.values
                      .map((EvidenceKind value) => DropdownMenuItem<EvidenceKind>(
                            value: value,
                            child: Text(value.label),
                          ))
                      .toList(),
                  onChanged: (EvidenceKind? value) {
                    if (value != null) setDialogState(() => kind = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    hintText: 'How and when was this captured?',
                  ),
                ),
                if (kind.requiresLawfulDeclaration) ...<Widget>[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: lawful,
                    onChanged: (bool? value) => setDialogState(() => lawful = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I confirm this recording was captured lawfully and that sharing it with '
                      'the university is permitted by institutional policy.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: kind.requiresLawfulDeclaration && !lawful
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Attach'),
            ),
          ],
        ),
      ),
    );

    final String? noteText = note.text.trim().isEmpty ? null : note.text.trim();
    note.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await context.read<CaseController>().attachEvidence(
            widget.caseId,
            EvidenceUpload(
              path: upload.path,
              fileName: upload.fileName,
              mimeType: upload.mimeType,
              kind: kind,
              note: noteText,
              lawfulDeclaration: lawful,
            ),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${upload.fileName} attached to the incident timeline.')),
      );
    } catch (error) {
      if (mounted) _warn('Could not attach the evidence: $error');
    }
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.item, required this.caseId});

  final EvidenceItem item;
  final String caseId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          _EvidenceVaultScreenState._iconFor(item.kind),
          color: HerVoiceColors.pinkPrimaryDark,
        ),
        title: Text(item.originalName, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${item.kind.label} - ${item.sizeLabel}\n'
          'sha256 ${item.fingerprint}\n'
          'Captured ${HerVoiceDate.timeline(item.capturedAt)}'
          '${item.pendingSync ? '\nWaiting to upload' : ''}',
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: true,
        trailing: item.pendingSync
            ? null
            : IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, color: HerVoiceColors.danger),
                onPressed: () =>
                    context.read<CaseController>().removeEvidence(caseId, item.id),
              ),
      ),
    );
  }
}
