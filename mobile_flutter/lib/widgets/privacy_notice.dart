import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The allegation-versus-finding statement from section 3.2.
///
/// It is shown wherever a student enters information about a named person, so
/// that the app never reads as though it has already decided that misconduct
/// occurred.
class AllegationNotice extends StatelessWidget {
  const AllegationNotice({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: HerVoiceColors.pinkLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HerVoiceColors.pinkMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 18, color: HerVoiceColors.pinkPrimaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? defaultAllegationNotice,
              style: TextStyle(
                fontSize: compact ? 12 : 13,
                height: 1.4,
                color: HerVoiceColors.pinkPrimaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Default wording, kept here so every screen shows the same statement.
const String defaultAllegationNotice =
    'HERVOICE records and submits allegations. It does not determine whether misconduct '
    'occurred, and a report is not a finding of guilt. Only the authorised institutional '
    'investigation process can make that determination.';

/// Explains that lock-screen text is deliberately vague (section 3.6).
class PrivacyNotice extends StatelessWidget {
  const PrivacyNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HerVoiceColors.pinkMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 18, color: HerVoiceColors.pinkPrimaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4, color: HerVoiceColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
