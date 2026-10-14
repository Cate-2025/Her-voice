import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/demo_store.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store});
  final DemoStore store;
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _confirmed = false;
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final draft = widget.store.active;
    if (draft == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'No report to review.',
            subtitle: 'Start a draft or open one from your records.',
          ),
          FilledButton(
            onPressed: () => context.go('/records'),
            child: const Text('My records'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          eyebrow: 'ONE LAST LOOK',
          title: 'Make sure it feels right.',
          subtitle: 'Review your words and details. You can still go back and make changes.',
        ),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                'Your incident',
                trailing: TextButton(
                  onPressed: _busy ? null : () => context.go('/document'),
                  child: const Text('Edit'),
                ),
              ),
              const Eyebrow('WHAT HAPPENED'),
              const SizedBox(height: 12),
              Text(
                draft.narrative,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 18),
              _detail('Person involved', draft.subject),
              _detail(
                'When',
                draft.occurredAt == null
                    ? 'Not provided'
                    : '${shortDate(draft.occurredAt!)} · ${TimeOfDay.fromDateTime(draft.occurredAt!).format(context)}',
              ),
              _detail(
                'Location',
                draft.location.isEmpty ? 'Not provided' : draft.location,
              ),
              if (draft.course.isNotEmpty)
                _detail('Course or unit', draft.course),
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 20),
              Text(
                'Evidence · ${draft.attachments.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (draft.attachments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No files selected. That is okay.',
                    style: TextStyle(color: VoiceColors.muted),
                  ),
                ),
              for (final file in draft.attachments)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '${file.name} · ${file.sizeLabel}',
                    style: const TextStyle(color: VoiceColors.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const PaperCard(
          color: VoiceColors.sage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 19, color: VoiceColors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You decide what to share',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'In the connected app, submitting will share your report with authorised university personnel. A report records your account of an incident; it is not a finding of misconduct.',
                style: TextStyle(fontSize: 12, height: 1.8),
              ),
            ],
          ),
        ),
        if (!draft.canSubmit) ...[
          const SizedBox(height: 16),
          const Text(
            'Complete the description, person involved, and incident date and time before submitting. Choose Keep editing to return to your draft.',
            style: TextStyle(color: VoiceColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _confirmed,
          onChanged: _busy
              ? null
              : (v) => setState(() => _confirmed = v ?? false),
          title: const Text(
            'I understand this is a fictional preview. No report or file will be sent.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : () => context.go('/document'),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              key: const Key('preview-submit'),
              onPressed: !_confirmed || _busy || !draft.canSubmit
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 650),
                      );
                      if (!mounted) return;
                      final report = widget.store.submitPreview();
                      if (context.mounted) {
                        context.go('/confirmation/${report.id}');
                      }
                    },
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Try demo submission'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: VoiceColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: VoiceColors.sage,
            child: Icon(
              Icons.check_rounded,
              color: VoiceColors.green,
              size: 32,
            ),
          ),
          const SizedBox(height: 28),
          const Eyebrow('DEMO JOURNEY COMPLETE'),
          const SizedBox(height: 15),
          Text(
            'You’ve taken a step.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your fictional report now appears in My records.\nNothing was sent to the university.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VoiceColors.muted, height: 1.8),
          ),
          const SizedBox(height: 24),
          Text(
            id,
            style: const TextStyle(
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.go('/cases/$id'),
            child: const Text('View preview case'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Back to home'),
          ),
        ],
      ),
    ),
  );
}
