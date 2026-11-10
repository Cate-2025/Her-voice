import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/report_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final ReportStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 1180;
      final records = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Your records',
            trailing: TextButton(
              onPressed: () => context.go('/records'),
              child: const Text('View all'),
            ),
          ),
          if (store.drafts.isEmpty && store.cases.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'No records yet. Your drafts and submitted reports will appear here.',
                style: TextStyle(color: VoiceColors.muted),
              ),
            ),
          if (store.drafts.isNotEmpty) ...[
            PaperCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.draftPending(store.drafts.first.id)
                        ? 'Continue your submission'
                        : 'Continue your draft',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    store.draftPending(store.drafts.first.id)
                        ? 'Check the saved submission and retry to confirm its status.'
                        : store.durableDrafts
                        ? 'Not submitted · encrypted on this device'
                        : 'Not submitted · kept for this app session',
                    style: const TextStyle(color: VoiceColors.muted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      store.openDraft(store.drafts.first.id);
                      context.go(
                        store.draftPending(store.drafts.first.id)
                            ? '/review'
                            : '/document',
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      store.draftPending(store.drafts.first.id)
                          ? 'Review saved submission'
                          : 'Continue draft',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final item in store.cases.take(2)) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/cases/${item.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          StatusPill(item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.submittedLabel,
                        style: const TextStyle(color: VoiceColors.muted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'View case details →',
                        style: TextStyle(color: VoiceColors.plum),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      );
      final support = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Support options'),
          const Text(
            'Explore support options, whether or not you choose to make a report.',
            style: TextStyle(color: VoiceColors.muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => context.go('/support'),
            label: const Text('Find support'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            iconAlignment: IconAlignment.end,
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            title: 'Your dashboard',
            subtitle: 'Keep a record, follow your reports or find support.',
            action: FilledButton.icon(
              key: const Key('new-incident'),
              onPressed: () {
                store.startDraft();
                context.go('/document');
              },
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Document an incident'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 28),
            child: Text(
              'You can save a draft and decide later. Nothing is submitted until you review and confirm.',
              style: TextStyle(color: VoiceColors.muted),
            ),
          ),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: records),
                const SizedBox(width: 40),
                Expanded(flex: 2, child: support),
              ],
            )
          else ...[
            records,
            const SizedBox(height: 32),
            support,
          ],
        ],
      );
    },
  );
}
