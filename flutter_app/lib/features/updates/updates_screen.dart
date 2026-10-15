import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/demo_store.dart';

class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key, required this.store});
  final ReportStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => store.isConnected
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                title: 'Your updates.',
                subtitle: 'Refresh to check for new case updates.',
              ),
              if (store.updates.isEmpty) const Text('No updates yet.'),
              for (final update in store.updates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PaperCard(
                    color: update.read ? Colors.white : VoiceColors.lavender,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(update.body),
                        Text(shortDate(update.date)),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () => context.go('/records'),
                              child: const Text('View my records'),
                            ),
                            if (!update.read)
                              TextButton(
                                onPressed: () => store.readUpdate(update.id),
                                child: const Text('Mark as read'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeading(
                eyebrow: 'A QUIET CHECK-IN',
                title: 'Your updates.',
                subtitle: 'Notifications keep details private. Open a case to see more.',
              ),
              PaperCard(
                color: store.updateRead ? Colors.white : VoiceColors.lavender,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const IconTile(Icons.notifications_none_rounded),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'You have a new confidential update.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (!store.updateRead)
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: VoiceColors.plum,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fictional example · 9 Oct 2026',
                      style: TextStyle(color: VoiceColors.muted, fontSize: 11),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      children: [
                        FilledButton(
                          onPressed: () {
                            store.markRead();
                            context.go('/cases/HV-DEMO-024');
                          },
                          child: const Text('Open case'),
                        ),
                        if (!store.updateRead)
                          TextButton(
                            onPressed: store.markRead,
                            child: const Text('Mark as read'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'No incident descriptions or names appear in notification previews.',
                style: TextStyle(color: VoiceColors.muted, fontSize: 12),
              ),
            ],
          ),
  );
}
