import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_format.dart';
import '../../models/incident_report.dart';
import '../../state/auth_controller.dart';
import '../../state/case_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_card.dart';
import 'case_detail_screen.dart';
import 'report_form_screen.dart';

/// Case-status tracking without physically visiting an office (section 2.2 IV).
class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CaseController>().loadCases(showSpinner: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.watch<CaseController>();
    final AuthController auth = context.watch<AuthController>();
    final List<CaseSummary> submitted = cases.submitted;
    final List<CaseSummary> drafts = cases.drafts;

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.isStaff ? 'All cases' : 'My cases'),
        actions: <Widget>[
          IconButton(onPressed: () => cases.loadCases(), icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: auth.isStaff
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ReportFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New report'),
            ),
      body: cases.loading && cases.cases.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await cases.loadCases(showSpinner: false);
                await cases.refreshPendingCount();
              },
              child: cases.cases.isEmpty
                  ? ListView(
                      children: const <Widget>[
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.folder_open_outlined,
                          title: 'No cases yet',
                          message: 'Record an incident and choose whether to save it as a '
                              'draft or submit it. You decide when.',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: <Widget>[
                        if (cases.errorMessage != null)
                          ErrorBanner(
                            message: cases.errorMessage!,
                            onRetry: () => cases.loadCases(),
                          ),
                        if (cases.pendingCount > 0) ...<Widget>[
                          const _PendingQueueNotice(),
                          const SizedBox(height: 8),
                        ],
                        if (submitted.isNotEmpty) ...<Widget>[
                          const Text(
                            'Submitted',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ...submitted.map(_caseTile),
                        ],
                        if (drafts.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 16),
                          const Text(
                            'Drafts on the server',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          ...drafts.map(_caseTile),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _caseTile(CaseSummary item) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => CaseDetailScreen(caseId: item.id)),
        ),
        title: Row(
          children: <Widget>[
            Text(item.reference, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            ReportingTypeChip(type: item.reportingType),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 2),
            Text('${item.person} - ${item.course}'),
            Text(
              '${item.location} - '
              '${HerVoiceDate.relative(item.submittedAt ?? item.incidentOccurredAt)}',
            ),
            if (item.evidenceCount > 0)
              Text(
                '${item.evidenceCount} evidence item(s), ${item.timelineCount} timeline entry(ies)',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: CaseStatusChip(status: item.status, compact: true),
      ),
    );
  }
}

class _PendingQueueNotice extends StatelessWidget {
  const _PendingQueueNotice();

  @override
  Widget build(BuildContext context) {
    final CaseController cases = context.read<CaseController>();
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.schedule_send_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${cases.pendingCount} item(s) recorded on this device have not reached the '
                'institution yet. Use "Sync now" in the banner at the top of the screen.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
