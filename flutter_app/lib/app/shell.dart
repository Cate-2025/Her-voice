import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/components.dart';
import 'theme.dart';

const destinations = <(String, String, IconData)>[
  ('/home', 'Home', Icons.grid_view_rounded),
  ('/records', 'My records', Icons.folder_outlined),
  ('/updates', 'Updates', Icons.notifications_none_rounded),
  ('/support', 'Support', Icons.favorite_border_rounded),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = destinations.indexWhere((d) => d.$1 == path);
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              backgroundColor: Colors.white,
              indicatorColor: VoiceColors.lavender,
              selectedIndex: selected < 0 ? 1 : selected,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].$1),
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(icon: Icon(d.$3), label: d.$2),
                  )
                  .toList(),
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Container(
                width: 244,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(right: BorderSide(color: VoiceColors.line)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 36, 22, 26),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Brand(),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'A SPACE TO BE HEARD',
                                  style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: 1.8,
                                    color: VoiceColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                for (final destination in destinations)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Material(
                                      color: path == destination.$1
                                          ? VoiceColors.lavender
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        leading: Icon(
                                          destination.$3,
                                          size: 21,
                                          color: path == destination.$1
                                              ? VoiceColors.plum
                                              : VoiceColors.muted,
                                        ),
                                        title: Text(
                                          destination.$2,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: path == destination.$1
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: path == destination.$1
                                                ? VoiceColors.plum
                                                : VoiceColors.muted,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                        onTap: () => context.go(destination.$1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (MediaQuery.sizeOf(context).height >= 760 &&
                                    MediaQuery.textScalerOf(context)
                                            .scale(14) <=
                                        19)
                                  PaperCard(
                                    color: VoiceColors.paper,
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.spa_outlined,
                                          color: VoiceColors.plum,
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          'Your voice.\nYour pace.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall,
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'You choose when you are ready to share.',
                                          style: TextStyle(
                                            color: VoiceColors.muted,
                                            fontSize: 12,
                                            height: 1.7,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 24),
                                const Text(
                                  'DESIGN PREVIEW · FICTIONAL DATA',
                                  style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: .8,
                                    color: VoiceColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 42 : 20,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: VoiceColors.line),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (!wide)
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Brand(),
                            ),
                          )
                        else
                          const Expanded(
                            child: Text(
                              'Your private space',
                              style: TextStyle(
                                color: VoiceColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: VoiceColors.peach,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PREVIEW',
                            style: TextStyle(
                              fontSize: 8,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        PopupMenuButton<String>(
                          tooltip: 'Account and preview information',
                          icon: const CircleAvatar(
                            radius: 18,
                            backgroundColor: VoiceColors.lavender,
                            child: Icon(
                              Icons.person_outline,
                              size: 20,
                              color: VoiceColors.plum,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'welcome') context.go('/welcome');
                            if (value == 'privacy') {
                              showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('About this preview'),
                                  content: const Text(
                                    'These records are fictional. Drafts and selected file names are kept only for this session. Nothing is sent to the university. Please use fictional information while exploring.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Got it'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'privacy',
                              child: Text('About this preview'),
                            ),
                            const PopupMenuItem(
                              value: 'welcome',
                              child: Text('Welcome screen'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('page-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1160),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 42 : 22,
                              wide ? 36 : 28,
                              wide ? 42 : 22,
                              40,
                            ),
                            child: child,
                          ),
                        ),
                      ),
                    ),
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
