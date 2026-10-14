import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/enums.dart';

/// Card with a bold title and optional trailing widget, used to group every
/// section of the app so screens stay visually consistent.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 20, color: HerVoiceColors.pinkPrimaryDark),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: HerVoiceColors.textDark,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: HerVoiceColors.textMuted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Rounded chip showing a case status with a colour that reflects progress.
class CaseStatusChip extends StatelessWidget {
  const CaseStatusChip({super.key, required this.status, this.compact = false});

  final CaseStatus status;
  final bool compact;

  Color get _background {
    switch (status) {
      case CaseStatus.draft:
        return const Color(0xFFECEFF1);
      case CaseStatus.submitted:
        return HerVoiceColors.pinkLight;
      case CaseStatus.underReview:
        return const Color(0xFFFFF3E0);
      case CaseStatus.investigating:
        return const Color(0xFFE3F2FD);
      case CaseStatus.actionTaken:
        return const Color(0xFFE8F5E9);
      case CaseStatus.referred:
        return const Color(0xFFEDE7F6);
      case CaseStatus.closed:
        return const Color(0xFFECEFF1);
    }
  }

  Color get _foreground {
    switch (status) {
      case CaseStatus.draft:
        return HerVoiceColors.textMuted;
      case CaseStatus.submitted:
        return HerVoiceColors.pinkPrimaryDark;
      case CaseStatus.underReview:
        return HerVoiceColors.warning;
      case CaseStatus.investigating:
        return const Color(0xFF1565C0);
      case CaseStatus.actionTaken:
        return HerVoiceColors.success;
      case CaseStatus.referred:
        return const Color(0xFF4527A0);
      case CaseStatus.closed:
        return HerVoiceColors.textDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 3 : 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _foreground,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Chip describing the reporting pathway a case was filed through.
class ReportingTypeChip extends StatelessWidget {
  const ReportingTypeChip({super.key, required this.type});

  final ReportingType type;

  IconData get _icon {
    switch (type) {
      case ReportingType.identified:
        return Icons.badge_outlined;
      case ReportingType.confidential:
        return Icons.lock_outline;
      case ReportingType.anonymous:
        return Icons.visibility_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HerVoiceColors.pinkMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_icon, size: 13, color: HerVoiceColors.pinkPrimaryDark),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: const TextStyle(
              fontSize: 11,
              color: HerVoiceColors.pinkPrimaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
