import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/report_store.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.store});
  final ReportStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          eyebrow: 'ONLY AS MUCH AS YOU CHOOSE',
          title: 'Your words, kept together.',
          subtitle: 'Pick up a draft or follow a submitted case.',
          action: FilledButton.icon(
            onPressed: () {
              store.startDraft();
              context.go('/document');
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Document an incident'),
          ),
        ),
        const SectionTitle('Drafts'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            store.durableDrafts
                ? 'Drafts and pending submissions are encrypted on this device. Sign in to the same account to continue.'
                : 'Drafts are kept only while this app session remains open.',
            style: const TextStyle(color: VoiceColors.muted, fontSize: 13),
          ),
        ),
        if (store.drafts.isEmpty)
          const PaperCard(
            child: Row(
              children: [
                IconTile(Icons.edit_note_rounded),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No drafts right now. Start whenever you feel ready.',
                  ),
                ),
              ],
            ),
          ),
        for (final draft in store.drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PaperCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconTile(
                        Icons.edit_note_rounded,
                        color: VoiceColors.peach,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          draft.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete draft',
                        onPressed: store.draftPending(draft.id)
                            ? null
                            : () async {
                                final remove = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete this draft?'),
                                    content: const Text(
                                      'This deletes the draft and its saved evidence from this device. You cannot undo this.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Keep draft'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete draft'),
                                      ),
                                    ],
                                  ),
                                );
                                if (remove == true) store.deleteDraft(draft.id);
                              },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: VoiceColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    draft.narrative.isEmpty
                        ? 'Your draft is ready when you are.'
                        : draft.narrative,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: VoiceColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      store.openDraft(draft.id);
                      context.go(
                        store.draftPending(draft.id) ? '/review' : '/document',
                      );
                    },
                    label: Text(
                      store.draftPending(draft.id)
                          ? 'Review saved submission'
                          : 'Continue draft',
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        const SectionTitle('Submitted cases'),
        if (store.cases.isEmpty) const Text('No submitted cases yet.'),
        for (final item in store.cases)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.go('/cases/${item.id}'),
              child: PaperCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        StatusPill(item.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${item.submittedLabel}${store.isConnected ? '' : ' · Fictional case'}',
                      style: const TextStyle(
                        color: VoiceColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'View details & progress',
                            style: TextStyle(
                              color: VoiceColors.plum,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: VoiceColors.plum,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class CaseDetailScreen extends StatelessWidget {
  const CaseDetailScreen({super.key, required this.store, required this.id});
  final ReportStore store;
  final String id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final item = store.caseById(id);
    if (item == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            title: 'Case not available.',
            subtitle: 'This case is not available in this session. Refresh your records or sign in again.',
          ),
          OutlinedButton(
            onPressed: () => context.go('/records'),
            child: const Text('Back to my records'),
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
          label: const Text('My records'),
        ),
        const SizedBox(height: 18),
        PageHeading(
          eyebrow: store.isConnected ? 'SUBMITTED CASE' : 'FICTIONAL CASE',
          title: item.title,
          subtitle: item.submittedLabel,
        ),
        StatusPill(item.status),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Case reference', style: TextStyle(fontSize: 12)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(item.id),
            ),
          ],
        ),
        const SizedBox(height: 26),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Case progress'),
              for (var i = 0; i < item.events.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: i == item.events.length - 1
                            ? VoiceColors.plum
                            : VoiceColors.sage,
                        child: Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: i == item.events.length - 1
                              ? Colors.white
                              : VoiceColors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.events[i].$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.events[i].$2,
                              style: const TextStyle(
                                color: VoiceColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Your account of the incident'),
              Text(
                item.narrative,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (item.subject.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Eyebrow('PERSON INVOLVED'),
                const SizedBox(height: 8),
                Text(item.subject),
              ],
              if (item.occurredAt != null) ...[
                const SizedBox(height: 24),
                const Eyebrow('INCIDENT DATE'),
                const SizedBox(height: 8),
                Text(
                  '${shortDate(item.occurredAt!)} · ${TimeOfDay.fromDateTime(item.occurredAt!).format(context)}',
                ),
              ],
              if (item.course.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Eyebrow('COURSE OR UNIT'),
                const SizedBox(height: 8),
                Text(item.course),
              ],
              if (item.location.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Eyebrow('LOCATION'),
                const SizedBox(height: 8),
                Text(item.location),
              ],
            ],
          ),
        ),
        if (item.attachments.isNotEmpty) ...[
          const SizedBox(height: 18),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(
                  store.isConnected ? 'Report evidence' : 'Selected evidence',
                ),
                for (final file in item.attachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('${file.name} · ${file.sizeLabel}'),
                  ),
                Text(
                  store.isConnected
                      ? 'These are the evidence files listed on your submitted report.'
                      : 'Preview metadata only. No files were uploaded.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: VoiceColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const PaperCard(
          color: VoiceColors.sage,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_border_rounded, color: VoiceColors.green),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'You can explore support options at any point, regardless of your case status.',
                  style: TextStyle(fontSize: 12, height: 1.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => context.go('/support'),
          child: const Text('Explore support'),
        ),
      ],
    );
  }
}
