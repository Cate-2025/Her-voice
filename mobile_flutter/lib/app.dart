import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'state/auth_controller.dart';

/// Root application widget. Routing is driven purely by the session state, so a
/// signed-out student can never reach a case screen by accident.
class HerVoiceApp extends StatelessWidget {
  const HerVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HERVOICE',
      debugShowCheckedModeBanner: false,
      theme: HerVoiceTheme.light(),
      home: const _LandingGate(),
    );
  }
}

class _LandingGate extends StatelessWidget {
  const _LandingGate();

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();

    switch (auth.status) {
      case AuthStatus.checking:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('HERVOICE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Empowering your safety', style: TextStyle(color: HerVoiceColors.textMuted)),
              ],
            ),
          ),
        );
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        return const AppShell();
    }
  }
}
