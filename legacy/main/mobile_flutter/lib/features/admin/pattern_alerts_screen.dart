import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/date_format.dart';
import '../../models/app_notification.dart';
import '../../state/admin_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';

/// Anonymous pattern detection, as authorised personnel see it (section 3.5).
///
/// The screen deliberately never names a person as guilty. It reports that
/// several independent allegations share a staff identifier and recommends a
/// review.
class PatternAlertsScreen extends StatefulWidget {
  const PatternAlertsScreen({super.key});

  @override
  State<PatternAlertsScreen> createState() => _PatternAlertsScreenState();
}

class _PatternAlertsScreenState extends State<PatternAlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminController admin = context.watch<AdminController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pattern alerts')),
      body: RefreshIndicator(
        onRefresh: admin.loadAlerts,
        child: admin.alerts.isEmpty
            ? ListView(
                children: <Widget>[
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'No pattern alerts',
                    message: admin.errorMessage ??
                        'An alert is raised when several independent allegations name the same '
                            'staff identifier. Nothing has crossed the threshold yet.',
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  if (admin.errorMessage != null)
                    ErrorBanner(message: admin.errorMessage!, onRetry: admin.loadAlerts),
                  SectionCard(
                    title: 'How this works',
                    icon: Icons.help_outline,
                    child: Text(
                      '${admin.alertNotice} Current threshold: ${admin.alertThreshold} '
                      'independent allegations involving the same staff identifier.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...admin.alerts.map((PatternAlert alert) => _AlertCard(alert: alert)),
                ],
              ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final PatternAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: alert.isHighSeverity ? Colors.deepPurple : HerVoiceColors.pinkMedium,
          width: alert.isHighSeverity ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.insights, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.staffIdentifier,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Chip(
                  label: Text(
                    alert.severity,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor:
                      alert.isHighSeverity ? Colors.deepPurple : HerVoiceColors.pinkPrimary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _metric('Allegations', '${alert.reportCount}'),
                _metric('Independent', '${alert.independentReporterCount}'),
                _metric('Similarity', alert.similarityLabel),
              ],
            ),
            if (alert.relatedCourses.isNotEmpty)
              _line(Icons.menu_book_outlined, 'Courses', alert.relatedCourses.join(', ')),
            if (alert.relatedLocations.isNotEmpty)
              _line(Icons.place_outlined, 'Locations', alert.relatedLocations.join(', ')),
            if (alert.sharedKeywords.isNotEmpty)
              _line(Icons.tag_outlined, 'Recurring terms', alert.sharedKeywords.join(', ')),
            if (alert.detectedAt != null)
              _line(
                  Icons.schedule_outlined, 'Last activity', HerVoiceDate.dayTime(alert.detectedAt)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HerVoiceColors.pinkLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${alert.notice ?? ''}\n${alert.recommendation ?? ''}',
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 10, color: HerVoiceColors.textMuted)),
        ],
      ),
    );
  }

  static Widget _line(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: HerVoiceColors.pinkPrimaryDark),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: HerVoiceColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }
}
