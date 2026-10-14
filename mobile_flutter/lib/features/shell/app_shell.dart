import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/hervoice_repository.dart';
import '../../state/auth_controller.dart';
import '../../state/case_controller.dart';
import '../../state/connectivity_controller.dart';
import '../../state/notification_controller.dart';
import '../../widgets/empty_state.dart';
import '../admin/admin_dashboard_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../report/case_list_screen.dart';
import '../settings/settings_screen.dart';
import '../support/support_resources_screen.dart';

class _ShellTab {
  const _ShellTab({required this.label, required this.icon, required this.activeIcon});

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Main navigation shell. Students and institutional personnel get different
/// tabs; the backend enforces the same split independently of the UI.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _initialised = false;

  static const List<_ShellTab> _studentTabs = <_ShellTab>[
    _ShellTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _ShellTab(label: 'Cases', icon: Icons.folder_outlined, activeIcon: Icons.folder),
    _ShellTab(label: 'Support', icon: Icons.support_agent_outlined, activeIcon: Icons.support_agent),
    _ShellTab(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
    _ShellTab(label: 'More', icon: Icons.tune_outlined, activeIcon: Icons.tune),
  ];

  static const List<_ShellTab> _staffTabs = <_ShellTab>[
    _ShellTab(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _ShellTab(label: 'Cases', icon: Icons.folder_outlined, activeIcon: Icons.folder),
    _ShellTab(label: 'Alerts', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
    _ShellTab(
        label: 'Institution',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard),
    _ShellTab(label: 'More', icon: Icons.tune_outlined, activeIcon: Icons.tune),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;

    // Warm the caches once so the first tab renders with data where possible.
    final ConnectivityController connectivity = context.read<ConnectivityController>();
    if (connectivity.isOnline) {
      context.read<CaseController>().loadCases(showSpinner: false);
      context.read<NotificationController>().load();
    }
  }

  List<Widget> _screensFor(List<_ShellTab> tabs) {
    return tabs.map((_ShellTab tab) {
      switch (tab.label) {
        case 'Home':
          return const HomeScreen();
        case 'Cases':
          return const CaseListScreen();
        case 'Support':
          return const SupportResourcesScreen();
        case 'Alerts':
          return const NotificationsScreen();
        case 'Institution':
          return const AdminDashboardScreen();
        default:
          return const SettingsScreen();
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final bool isStaff = auth.isStaff;
    final List<_ShellTab> tabs = isStaff ? _staffTabs : _studentTabs;
    final int index = _index.clamp(0, tabs.length - 1);

    final ConnectivityController connectivity = context.watch<ConnectivityController>();
    final CaseController cases = context.watch<CaseController>();

    return Scaffold(
      body: Column(
        children: <Widget>[
          if (!connectivity.isOnline)
            OfflineBanner(
              pendingCount: cases.pendingCount,
              statusLabel: connectivity.statusLabel,
              syncing: cases.busy,
              onSync: connectivity.hasTransport ? _sync : null,
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: _screensFor(tabs),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (int value) {
          setState(() => _index = value);
          if (value == 3 && !isStaff) context.read<NotificationController>().load();
        },
        destinations: tabs
            .map((_ShellTab tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.activeIcon),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }

  Future<void> _sync() async {
    final CaseController cases = context.read<CaseController>();
    final ConnectivityController connectivity = context.read<ConnectivityController>();
    await connectivity.setForcedOffline(false);
    final SyncOutcome outcome = await cases.synchronise();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.didNothing
            ? 'Everything on this device has already been sent.'
            : '${outcome.synced} item(s) synchronised'
                '${outcome.failed > 0 ? ', ${outcome.failed} still waiting' : ''}.'),
      ),
    );
  }
}
