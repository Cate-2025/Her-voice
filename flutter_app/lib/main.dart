import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/api_client.dart';
import 'core/connected_store.dart';
import 'core/demo_store.dart';
import 'core/push_service.dart';
import 'core/vault_factory.dart';
import 'core/welcome_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('HERVOICE_DEMO');
  const base = String.fromEnvironment(
    'HERVOICE_API_BASE_URL',
    defaultValue: 'https://her-voice-e2mu.onrender.com/api/v1',
  );
  if (kReleaseMode && !demo && Uri.parse(base).scheme != 'https') {
    throw StateError('Release builds require an HTTPS HERVOICE_API_BASE_URL.');
  }
  final push = PushService();
  if (!demo) await push.initialize();
  final welcome = WelcomePreferences();
  final seenWelcome = demo || await welcome.hasSeenWelcome();
  runApp(
    HerVoiceApp(
      initialLocation: demo
          ? '/home'
          : seenWelcome
          ? '/signin'
          : '/welcome',
      onWelcomeComplete: demo ? null : welcome.markSeen,
      store: demo
          ? DemoStore()
          : ConnectedStore(
              ApiClient(base),
              push: push,
              vault: createDraftVault(),
            ),
    ),
  );
}
