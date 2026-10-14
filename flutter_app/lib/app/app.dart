import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/demo_store.dart';
import '../features/auth/welcome_screen.dart';
import '../features/home/home_screen.dart';
import '../features/records/records_screen.dart';
import '../features/reports/editor_screen.dart';
import '../features/reports/review_screen.dart';
import '../features/support/support_screen.dart';
import '../features/updates/updates_screen.dart';
import 'shell.dart';
import 'theme.dart';

class HerVoiceApp extends StatefulWidget {
  const HerVoiceApp({super.key, this.store, this.initialLocation = '/home'});
  final DemoStore? store;
  final String initialLocation;
  @override
  State<HerVoiceApp> createState() => _HerVoiceAppState();
}

class _HerVoiceAppState extends State<HerVoiceApp> {
  late final DemoStore _store = widget.store ?? DemoStore();
  late final GoRouter _router = GoRouter(
    initialLocation: widget.initialLocation,
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => HomeScreen(store: _store),
          ),
          GoRoute(
            path: '/records',
            builder: (_, _) => RecordsScreen(store: _store),
          ),
          GoRoute(
            path: '/updates',
            builder: (_, _) => UpdatesScreen(store: _store),
          ),
          GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
          GoRoute(
            path: '/document',
            builder: (_, _) => EditorScreen(store: _store),
          ),
          GoRoute(
            path: '/review',
            builder: (_, _) => ReviewScreen(store: _store),
          ),
          GoRoute(
            path: '/cases/:id',
            builder: (_, state) => CaseDetailScreen(
              store: _store,
              id: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/confirmation/:id',
            builder: (_, state) =>
                _store.caseById(state.pathParameters['id']!) == null
                ? CaseDetailScreen(
                    store: _store,
                    id: state.pathParameters['id']!,
                  )
                : ConfirmationScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/home'),
          child: const Text('Return to home'),
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _router.dispose();
    if (widget.store == null) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'HERVOICE · Design preview',
    debugShowCheckedModeBanner: false,
    theme: voiceTheme(),
    routerConfig: _router,
  );
}
