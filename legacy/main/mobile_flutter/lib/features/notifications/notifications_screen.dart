import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/app_notification.dart';
import '../../state/notification_controller.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/privacy_notice.dart';
import '../report/case_detail_screen.dart';

/// Secure notifications (section 3.6).
///
/// Notification text is intentionally vague. Opening one and authenticating is
/// what reveals the detail, so a glance at the phone never exposes a case.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotificationController controller = context.watch<NotificationController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (controller.unreadCount > 0)
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: controller.loading && controller.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: controller.load,
              child: controller.items.isEmpty
                  ? ListView(
                      children: const <Widget>[
                        SizedBox(height: 60),
                        EmptyState(
                          icon: Icons.notifications_none,
                          title: 'No notifications',
                          message: 'When an authorised officer updates one of your cases, you '
                              'will be told that you have a new confidential notification.',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: <Widget>[
                        const PrivacyNotice(text: AppConfig.notificationPrivacyNotice),
                        const SizedBox(height: 12),
                        if (controller.errorMessage != null)
                          ErrorBanner(
                            message: controller.errorMessage!,
                            onRetry: controller.load,
                          ),
                        ...controller.items.map(
                          (AppNotification item) => _NotificationCard(
                            notification: item,
                            onTap: () => _open(item),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Future<void> _open(AppNotification item) async {
    await context.read<NotificationController>().markRead(item.id);
    if (!mounted) return;
    if (item.caseId == null || item.caseId!.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CaseDetailScreen(caseId: item.caseId!)),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: notification.read ? Colors.white : HerVoiceColors.pinkLight,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          notification.category == 'SECURE_MESSAGE'
              ? Icons.mail_outline
              : Icons.shield_outlined,
          color: HerVoiceColors.pinkPrimaryDark,
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${notification.body}\n\n${notification.whenLabel}'
          '${notification.usedSmsFallback ? ' - sent by SMS fallback' : ''}',
          style: const TextStyle(fontSize: 12, height: 1.4),
        ),
        isThreeLine: true,
        trailing: notification.read
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: HerVoiceColors.pinkPrimary,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
