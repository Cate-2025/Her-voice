import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../models/audit_entry.dart';
import '../../state/admin_controller.dart';
import '../../state/auth_controller.dart';
import '../../widgets/empty_state.dart';

/// Append-only audit trail of authorised actions (section 3.12 VI).
///
/// Administrator role only: the server refuses the route for students and
/// officers, and the Flutter screen refuses to offer it to anyone else.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadAuditLog();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminController admin = context.watch<AdminController>();
    final bool isAdmin = context.watch<AuthController>().isAdmin;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit log')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          title: 'Administrator only',
          message: 'The audit trail records who accessed which case and when. It is '
              'restricted to administrators.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: RefreshIndicator(
        onRefresh: admin.loadAuditLog,
        child: admin.audit.isEmpty
            ? ListView(
                children: <Widget>[
                  const SizedBox(height: 60),
                  EmptyState(
                    icon: Icons.history_outlined,
                    title: 'Nothing recorded yet',
                    message: admin.errorMessage ??
                        'Case views, evidence reads, status changes and pattern alerts are '
                            'recorded here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: admin.audit.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final AuditEntry entry = admin.audit[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      entry.bySystem ? Icons.settings_suggest_outlined : Icons.person_outline,
                      color: entry.bySystem
                          ? Colors.deepPurple
                          : HerVoiceColors.pinkPrimaryDark,
                    ),
                    title: Text(
                      entry.actionLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${entry.whenLabel} - ${entry.actorRole ?? 'SYSTEM'}'
                      '${entry.detail != null && entry.detail!.isNotEmpty ? '\n${entry.detail}' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    isThreeLine: entry.detail != null,
                  );
                },
              ),
      ),
    );
  }
}
