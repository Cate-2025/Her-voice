import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/incident_report.dart';
import '../../state/auth_controller.dart';
import '../../state/case_controller.dart';
import '../../state/connectivity_controller.dart';
import '../../widgets/section_card.dart';
import '../report/report_form_screen.dart';
import '../support/emergency_screen.dart';

/// Landing screen. It answers the three questions a student has when she opens
/// the app: what is my situation, what can I do right now, and are my records
/// safe on this device?
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final CaseController cases = context.watch<CaseController>();
    final ConnectivityController connectivity = context.watch<ConnectivityController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.isStaff ? 'HERVOICE Institution' : 'HERVOICE'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              cases.loadCases();
              cases.refreshPendingCount();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await cases.loadCases();
          await cases.refreshPendingCount();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _Greeting(name: auth.user?.shortName ?? 'there', isStaff: auth.isStaff),
            const SizedBox(height: 12),
            _StatusCard(
              online: connectivity.isOnline,
              statusLabel: connectivity.statusLabel,
              pendingCount: cases.pendingCount,
              patternAlerts: cases.patternAlertNotice,
            ),
            const SizedBox(height: 12),
            const _EmergencyAction(),
            const SizedBox(height: 8),
            const _QuickActions(),
            const SizedBox(height: 8),
            const _RecentCases(),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.isStaff});

  final String name;
  final bool isStaff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isStaff ? 'Good to see you, $name' : 'You are not alone, $name',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          isStaff
              ? 'Reports received through HERVOICE appear here for authorised review.'
              : 'You can document what happened, keep what evidence you have, and decide '
                  'how you want to report it.',
          style: const TextStyle(color: HerVoiceColors.textMuted, height: 1.4),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.online,
    required this.statusLabel,
    required this.pendingCount,
    required this.patternAlerts,
  });

  final bool online;
  final String statusLabel;
  final int pendingCount;
  final int patternAlerts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              online ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: online ? HerVoiceColors.success : Colors.orange.shade800,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(statusLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    pendingCount == 0
                        ? 'Nothing is waiting on this device.'
                        : '$pendingCount item(s) stored on this device, ready to send.',
                    style: const TextStyle(fontSize: 12, color: HerVoiceColors.textMuted),
                  ),
                  if (patternAlerts > 0) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'Authorised personnel have been alerted to a possible recurring pattern '
                      'involving this person. That is not a finding of guilt.',
                      style: TextStyle(fontSize: 12, color: Colors.deepPurple),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyAction extends StatelessWidget {
  const _EmergencyAction();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFEBEE),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.emergency_outlined, color: HerVoiceColors.danger, size: 28),
        title: const Text(
          'I need support right now',
          style: TextStyle(fontWeight: FontWeight.w700, color: HerVoiceColors.danger),
        ),
        subtitle: const Text(
          'Quick access to campus security, the safeguarding officer and medical support.',
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: HerVoiceColors.danger),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EmergencyScreen()),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'What you can do',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: <Widget>[
            _ActionTile(
              icon: Icons.edit_note_outlined,
              label: 'Record an incident',
              detail: 'Document what happened',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportFormScreen()),
              ),
            ),
            const _ActionTile(
              icon: Icons.folder_shared_outlined,
              label: 'My cases',
              detail: 'Track progress without visiting an office',
            ),
            const _ActionTile(
              icon: Icons.vpn_key_outlined,
              label: 'Evidence vault',
              detail: 'Preserve messages, photos and files',
            ),
            const _ActionTile(
              icon: Icons.psychology_alt_outlined,
              label: 'Support & resources',
              detail: 'Counselling, security and guidance',
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: HerVoiceColors.pinkPrimary, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: HerVoiceColors.textMuted, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentCases extends StatelessWidget {
  const _RecentCases();

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.watch<CaseController>();
    final List<CaseSummary> recent = cases.cases.take(3).toList();

    if (cases.loading && recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (recent.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              Icon(Icons.inbox_outlined, size: 40, color: HerVoiceColors.pinkMedium),
              SizedBox(height: 8),
              Text(
                'You have not recorded any incidents yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'When something happens, record it while it is fresh. You choose whether to '
                'save it as a draft or submit it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: HerVoiceColors.textMuted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Your recent cases',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...recent.map(
          (CaseSummary item) => Card(
            child: ListTile(
              title: Text(
                item.reference,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${item.person}\n${item.course} - ${item.location}',
                style: const TextStyle(fontSize: 12),
              ),
              isThreeLine: true,
              trailing: CaseStatusChip(status: item.status, compact: true),
            ),
          ),
        ),
      ],
    );
  }
}
