import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/hervoice_repository.dart';
import '../../models/support_resource.dart';
import '../../state/connectivity_controller.dart';
import '../../widgets/empty_state.dart';

/// Emergency and quick-support function (section 3.8).
///
/// This is an additional communication channel. It deliberately does not present
/// itself as a replacement for emergency services or campus security, and says
/// so on the screen.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  EmergencyDirectory? _directory;
  String? _error;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final EmergencyDirectory directory =
          await context.read<HerVoiceRepository>().emergencyDirectory();
      if (mounted) setState(() => _directory = directory);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestSupport(String channel) async {
    final String? reason = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _QuickSupportDialog(channel: channel),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    setState(() => _sending = true);
    try {
      await context.read<HerVoiceRepository>().requestQuickSupport(
            reason: reason.trim(),
            channel: channel,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authorised personnel have been alerted. Stay somewhere safe.'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send the request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectivityController connectivity = context.watch<ConnectivityController>();
    final List<EmergencyContact> contacts = _directory?.contacts ?? <EmergencyContact>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick support'),
        backgroundColor: HerVoiceColors.danger,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: <Widget>[
                Card(
                  color: const Color(0xFFFFEBEE),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Row(
                          children: <Widget>[
                            Icon(Icons.info_outline, color: HerVoiceColors.danger),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'HERVOICE does not replace emergency services',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: HerVoiceColors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _directory?.disclaimer ??
                              'In immediate danger, contact campus security or the national '
                                  'emergency number directly.',
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!connectivity.isOnline)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'You are offline. Quick-support requests need a connection, so use the '
                      'phone numbers below.',
                      style: TextStyle(fontSize: 12, color: HerVoiceColors.warning),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: HerVoiceColors.danger),
                  onPressed: _sending ? null : () => _requestSupport('IN_APP'),
                  icon: _sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Alert authorised personnel in HERVOICE'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _sending ? null : () => _requestSupport('SMS_FALLBACK'),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Use the low-data SMS fallback'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Direct contacts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_error != null) ErrorBanner(message: _error!, onRetry: _load),
                ...contacts.map((EmergencyContact contact) => _ContactCard(contact: contact)),
                if (contacts.isEmpty && _error == null)
                  const EmptyState(
                    icon: Icons.phone_in_talk_outlined,
                    title: 'No contacts loaded',
                    message: 'Connect to the HERVOICE server to load the contact list.',
                  ),
              ],
            ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          contact.isSms ? Icons.sms_outlined : Icons.call_outlined,
          color: HerVoiceColors.danger,
        ),
        title: Text(contact.label, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          '${contact.contact}\n${contact.note ?? ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Copy number',
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: contact.contact));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Number copied')),
            );
          },
        ),
      ),
    );
  }
}

/// Short-form request. The SMS fallback channel only carries a brief, vague
/// alert, so the dialog asks for one sentence.
class _QuickSupportDialog extends StatefulWidget {
  const _QuickSupportDialog({required this.channel});

  final String channel;

  @override
  State<_QuickSupportDialog> createState() => _QuickSupportDialogState();
}

class _QuickSupportDialogState extends State<_QuickSupportDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request immediate support'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _reason,
            autofocus: true,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'What is happening?',
              hintText: 'One sentence is enough',
            ),
          ),
          if (widget.channel == 'SMS_FALLBACK')
            const Text(
              'The SMS fallback sends a short, deliberately vague alert that does not contain '
              'this text.',
              style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: HerVoiceColors.danger),
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}
