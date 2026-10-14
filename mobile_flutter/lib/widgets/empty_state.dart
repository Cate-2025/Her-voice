import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Consistent placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 52, color: HerVoiceColors.pinkMedium),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HerVoiceColors.textMuted, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline error with a retry action.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: HerVoiceColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13, color: HerVoiceColors.danger)),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Banner explaining that work is being stored on the device.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.pendingCount,
    required this.statusLabel,
    this.onSync,
    this.syncing = false,
  });

  final int pendingCount;
  final String statusLabel;
  final VoidCallback? onSync;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border(bottom: BorderSide(color: Colors.amber.shade200)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_outlined, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendingCount == 0
                  ? statusLabel
                  : '$statusLabel - $pendingCount item(s) waiting on this device',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
          if (onSync != null)
            TextButton(
              onPressed: syncing ? null : onSync,
              child: Text(syncing ? 'Syncing...' : 'Sync now'),
            ),
        ],
      ),
    );
  }
}
