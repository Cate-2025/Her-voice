import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/hervoice_repository.dart';
import '../../data/preferences_store.dart';
import '../../state/auth_controller.dart';
import '../../state/case_controller.dart';
import '../../state/connectivity_controller.dart';
import '../../widgets/privacy_notice.dart';
import '../../widgets/section_card.dart';

/// Account, privacy and connectivity settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: HerVoiceColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _editBaseUrl(BuildContext context, PreferencesStore preferences) async {
    final TextEditingController controller =
        TextEditingController(text: preferences.apiBaseUrl);

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Backend address'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'API base URL'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !context.mounted) return;
    await preferences.setApiBaseUrl(result);
    if (!context.mounted) return;
    context.read<HerVoiceRepository>().api.baseUrl = result;
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final ConnectivityController connectivity = context.watch<ConnectivityController>();
    final CaseController cases = context.watch<CaseController>();
    final PreferencesStore preferences = context.read<PreferencesStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SectionCard(
            title: 'Your account',
            icon: Icons.account_circle_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _line('Name', auth.user?.shortName ?? '-'),
                _line('Email', auth.user?.email ?? '-'),
                _line('Role', auth.user?.role.wire ?? '-'),
                const SizedBox(height: 8),
                const Text(
                  'HERVOICE collects only what it needs: an email address to sign in with and '
                  'whatever you choose to record about an incident.',
                  style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Connectivity',
            icon: Icons.wifi_tethering_outlined,
            subtitle: connectivity.statusLabel,
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: connectivity.isForcedOffline,
                  onChanged: connectivity.setForcedOffline,
                  title: const Text('Work offline', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    'Stop all network traffic so you can prepare a report privately. Queued '
                    'records are sent when you turn this off.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                if (cases.pendingCount > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: cases.busy ? null : () => _sync(context),
                    icon: const Icon(Icons.sync),
                    label: Text('Synchronise ${cases.pendingCount} waiting item(s)'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Backend',
            icon: Icons.settings_ethernet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _line('API base URL', preferences.apiBaseUrl),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editBaseUrl(context, preferences),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Change server address'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const SectionCard(
            title: 'How HERVOICE treats your report',
            icon: Icons.gavel_outlined,
            child: PrivacyNotice(
              text: 'A report is an allegation, not a finding. HERVOICE never states that a '
                  'person is guilty, and the pattern detector only raises an internal review '
                  'recommendation for authorised personnel.',
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: HerVoiceColors.danger),
            onPressed: () => _confirmSignOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final ConnectivityController connectivity = context.read<ConnectivityController>();
    final CaseController cases = context.read<CaseController>();
    await connectivity.setForcedOffline(false);
    final SyncOutcome outcome = await cases.synchronise();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.didNothing
            ? 'Everything has already been sent.'
            : '${outcome.synced} item(s) synchronised'
                '${outcome.failed > 0 ? ', ${outcome.failed} still waiting' : ''}.'),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final AuthController auth = context.read<AuthController>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your session token is removed from this device. Reports already sent to the '
          'institution stay on the server and you can sign back in at any time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }
}
