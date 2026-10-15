import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/admin_repository.dart';
import 'data/api_client.dart';
import 'data/hervoice_repository.dart';
import 'data/offline_queue.dart';
import 'data/preferences_store.dart';
import 'data/secure_store.dart';
import 'state/admin_controller.dart';
import 'state/auth_controller.dart';
import 'state/case_controller.dart';
import 'state/connectivity_controller.dart';
import 'state/notification_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local stores are opened before the first frame so the app never flashes an
  // empty state, and so an offline start-up is fully usable.
  final PreferencesStore preferences = await PreferencesStore.open();
  final OfflineQueue queue = await OfflineQueue.open();
  final ApiClient api = ApiClient(baseUrl: preferences.apiBaseUrl);
  final HerVoiceRepository repository = HerVoiceRepository(api: api, queue: queue);

  runApp(HerVoiceRoot(
    preferences: preferences,
    repository: repository,
    adminRepository: AdminRepository(api),
    secureStore: SecureSessionStore(),
  ));
}

/// Creates the controllers, provides them to the widget tree and restores the
/// previous session.
class HerVoiceRoot extends StatefulWidget {
  const HerVoiceRoot({
    super.key,
    required this.preferences,
    required this.repository,
    required this.adminRepository,
    required this.secureStore,
  });

  final PreferencesStore preferences;
  final HerVoiceRepository repository;
  final AdminRepository adminRepository;
  final SecureSessionStore secureStore;

  @override
  State<HerVoiceRoot> createState() => _HerVoiceRootState();
}

class _HerVoiceRootState extends State<HerVoiceRoot> {
  late final AuthController _auth;
  late final ConnectivityController _connectivity;
  late final CaseController _cases;
  late final NotificationController _notifications;
  late final AdminController _admin;

  @override
  void initState() {
    super.initState();
    _auth = AuthController(repository: widget.repository, secureStore: widget.secureStore);
    _connectivity = ConnectivityController();
    _cases = CaseController(widget.repository);
    _notifications = NotificationController(widget.repository);
    _admin = AdminController(widget.adminRepository);

    // Restore the encrypted session, then start watching wireless transport.
    unawaited(_auth.bootstrap());
    unawaited(_connectivity.start());
    unawaited(_cases.refreshPendingCount());
  }

  @override
  void dispose() {
    _auth.dispose();
    _connectivity.dispose();
    _cases.dispose();
    _notifications.dispose();
    _admin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: _auth),
        ChangeNotifierProvider<ConnectivityController>.value(value: _connectivity),
        ChangeNotifierProvider<CaseController>.value(value: _cases),
        ChangeNotifierProvider<NotificationController>.value(value: _notifications),
        ChangeNotifierProvider<AdminController>.value(value: _admin),
        Provider<PreferencesStore>.value(value: widget.preferences),
        Provider<HerVoiceRepository>.value(value: widget.repository),
      ],
      child: const HerVoiceApp(),
    );
  }
}
