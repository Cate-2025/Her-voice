import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/app_notification.dart';
import '../../models/incident_report.dart';
import '../../state/admin_controller.dart';
import '../../state/auth_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'admin_case_screen.dart';
import 'audit_log_screen.dart';
import 'pattern_alerts_screen.dart';

/// Institutional dashboard (architecture 7.2).
///
/// Identity columns for anonymous reports are removed by the server, so this
/// screen can show a report without ever being able to attribute it.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminController admin = context.watch<AdminController>();
    final AdminDashboard? dashboard = admin.dashboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institution'),
        actions: <Widget>[
          IconButton(onPressed: admin.loadDashboard, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: admin.loading && dashboard == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: admin.loadDashboard,
              child: dashboard == null
                  ? ListView(
                      children: <Widget>[
                        const SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.lock_outline,
                          title: 'Dashboard unavailable',
                          message: admin.errorMessage ??
                              'Only safeguarding officers and administrators can open this '
                                  'screen, and it needs a connection to the server.',
                        ),
                      ],
                    )
                  : _buildDashboard(context, admin, dashboard),
            ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    AdminController admin,
    AdminDashboard dashboard,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        if (admin.errorMessage != null)
          ErrorBanner(message: admin.errorMessage!, onRetry: admin.loadDashboard),
        SectionCard(
          title: 'At a glance',
          icon: Icons.insights_outlined,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _Stat(label: 'Reports received', value: dashboard.totalReportsReceived),
              _Stat(label: 'Evidence items', value: dashboard.evidenceItems),
              _Stat(label: 'Pattern alerts', value: dashboard.alerts.length),
              _Stat(label: 'Quick support', value: dashboard.quickSupportRequests),
              _Stat(
                label: 'Identified',
                value: dashboard.byReportingType['IDENTIFIED'] ?? 0,
              ),
              _Stat(
                label: 'Confidential',
                value: dashboard.byReportingType['CONFIDENTIAL'] ?? 0,
              ),
              _Stat(
                label: 'Anonymous',
                value: dashboard.byReportingType['ANONYMOUS'] ?? 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (dashboard.alerts.isNotEmpty) ...<Widget>[
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PatternAlertsScreen()),
            ),
            icon: const Icon(Icons.insights_outlined),
            label: Text('View ${dashboard.alerts.length} pattern alert(s)'),
          ),
          const SizedBox(height: 8),
        ],
        const SectionCard(
          title: 'Standing notice',
          icon: Icons.gavel_outlined,
          child: Text(
            'Everything in this dashboard is an allegation. HERVOICE does not determine '
            'misconduct, and no conclusion about any individual should be drawn from a count '
            'of reports. Decisions rest with the authorised institutional process.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          title: 'Cases (${dashboard.cases.length})',
          icon: Icons.folder_outlined,
          child: Column(
            children: dashboard.cases.isEmpty
                ? const <Widget>[
                    Text(
                      'No cases have been received yet.',
                      style: TextStyle(fontSize: 12, color: HerVoiceColors.textMuted),
                    ),
                  ]
                : dashboard.cases.map((CaseSummary item) => _CaseRow(item: item)).toList(),
          ),
        ),
        if (context.read<AuthController>().isAdmin) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AuditLogScreen()),
            ),
            icon: const Icon(Icons.history_outlined),
            label: const Text('Open audit log'),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 3,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HerVoiceColors.pinkLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: HerVoiceColors.textMuted, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.item});

  final CaseSummary item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => AdminCaseScreen(caseId: item.id)),
      ),
      title: Row(
        children: <Widget>[
          Text(item.reference, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          ReportingTypeChip(type: item.reportingType),
          if (item.patternFlagged) ...<Widget>[
            const SizedBox(width: 6),
            const Icon(Icons.insights, size: 16, color: Colors.deepPurple),
          ],
        ],
      ),
      subtitle: Text(
        '${item.person} - ${item.course}\n${item.location} - '
        '${item.evidenceCount} evidence item(s)',
        style: const TextStyle(fontSize: 11),
      ),
      isThreeLine: true,
      trailing: CaseStatusChip(status: item.status, compact: true),
    );
  }
}
