import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/demo_store.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final DemoStore store;
  void _start(BuildContext context) {
    store.startDraft();
    context.go('/document');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final wide = MediaQuery.sizeOf(context).width >= 1180;
      final sections = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Your records',
            trailing: TextButton(
              onPressed: () => context.go('/records'),
              child: const Text('View all'),
            ),
          ),
          if (store.drafts.isNotEmpty)
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Continue your draft',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Take it one step at a time.',
                                style: TextStyle(
                                  color: VoiceColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Continue draft',
                          onPressed: () {
                            store.openDraft(store.drafts.first.id);
                            context.go('/document');
                          },
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: VoiceColors.muted,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Not submitted · this preview session',
                            style: TextStyle(
                              fontSize: 10,
                              color: VoiceColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          for (final item in store.cases.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.go('/cases/${item.id}'),
                child: PaperCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            item.id,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          StatusPill(item.status),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'Documented ${shortDate(item.date)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: VoiceColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'View case details',
                              style: TextStyle(
                                fontSize: 12,
                                color: VoiceColors.plum,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
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
      );
      final side = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Here for you'),
          PaperCard(
            color: VoiceColors.sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: VoiceColors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  'You don’t have to\nfigure it out alone.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Explore support options, whether or not you choose to make a report.',
                  style: TextStyle(
                    color: VoiceColors.muted,
                    fontSize: 12,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => context.go('/support'),
                  label: const Text('Find support'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const PaperCard(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: VoiceColors.plum,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Before you begin',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Writing something down doesn’t mean you have to submit it. You can pause, review, and decide in your own time.',
                  style: TextStyle(
                    fontSize: 12,
                    color: VoiceColors.muted,
                    height: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(
            eyebrow: 'A little space for you',
            title: 'Welcome to your space.',
            subtitle: 'Document what happened. Explore your options. Move at your own pace.',
          ),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: VoiceColors.lavender,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -25,
                  top: -50,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(330, 330),
                      painter: _PetalPainter(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('WHEN YOU FEEL READY'),
                      const SizedBox(height: 17),
                      Text(
                        'Your experience matters.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 410,
                        child: Text(
                          'A place to put your thoughts into words, keep a record, and choose what comes next.',
                          style: TextStyle(
                            fontSize: 13,
                            color: VoiceColors.muted,
                            height: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('new-incident'),
                        onPressed: () => _start(context),
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('Document an incident'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              for (final item in [
                (Icons.lock_outline, 'Share only when you choose'),
                (Icons.edit_outlined, 'Save and come back'),
                (Icons.favorite_border, 'Support at every step'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.$1, size: 15, color: VoiceColors.plum),
                    const SizedBox(width: 7),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 10,
                        color: VoiceColors.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 36),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: sections),
                const SizedBox(width: 28),
                Expanded(flex: 2, child: side),
              ],
            )
          else ...[
            sections,
            const SizedBox(height: 24),
            side,
          ],
        ],
      );
    },
  );
}

class _PetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VoiceColors.plum.withValues(alpha: .07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.translate(size.width * .55, size.height * .55);
    for (var i = 0; i < 7; i++) {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, -68), width: 88, height: 230),
        paint,
      );
      canvas.rotate(.8976);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
