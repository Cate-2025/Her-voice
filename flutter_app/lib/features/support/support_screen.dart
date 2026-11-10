import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/components.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading(
        eyebrow: 'YOU DON’T HAVE TO DO THIS ALONE',
        title: 'Support, on your terms.',
        subtitle: 'You can seek support without making a report.',
      ),
      PaperCard(
        color: VoiceColors.sage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              color: VoiceColors.green,
              size: 28,
            ),
            const SizedBox(height: 18),
            Text(
              'Start with someone you trust.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            const Text(
              'A trusted friend, family member, or counsellor can help you think through what feels right for you. You decide how much to share.',
              style: TextStyle(height: 1.8),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const SectionTitle('Explore your options'),
      for (final item in [
        (
          Icons.chat_bubble_outline,
          'Talk to a counsellor',
          'A space to talk and get emotional support.',
          'Makerere Counselling and Guidance Centre is opposite Mary Stuart Hall. Call +256 772 558022 or +256 702 558022 to ask about appointments and confidentiality.',
        ),
        (
          Icons.school_outlined,
          'Understand the university process',
          'Learn what reporting and case review involve.',
          'Makerere accepts informal and formal complaints. A formal complaint is written and signed, with your contact details, the complaint date and incident details. Complaints go through the Gender Mainstreaming Directorate for investigation and referral to the appropriate disciplinary body. Ask the Directorate how to begin.',
        ),
        (
          Icons.people_outline,
          'Bring someone with you',
          'You can ask for support at appointments.',
          'Makerere’s policy allows a friend or colleague to accompany you to a hearing. Ask the office about support at other appointments.',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PaperCard(
            padding: const EdgeInsets.all(8),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(item.$1, color: VoiceColors.plum),
              title: Text(
                item.$2,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  item.$3,
                  style: const TextStyle(
                    fontSize: 11,
                    color: VoiceColors.muted,
                  ),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Text(
                    item.$4,
                    style: const TextStyle(fontSize: 13, height: 1.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 14),
      const SectionTitle('Makerere support contacts'),
      for (final contact in const [
        (
          'Counselling and Guidance Centre',
          '+256 772 558022 · +256 702 558022\nOpposite Mary Stuart Hall. Ask about appointments and confidentiality.',
        ),
        (
          'Gender Mainstreaming Directorate',
          'Safeguarding hotline: +256 755 797130\nFor advice about sexual harassment and reporting options.',
        ),
        (
          'Safeguarding and Inclusivity',
          'safeguardingliaison@mak.ac.ug\nMakerere’s official online reporting service: https://safespace.mak.ac.ug/',
        ),
        (
          'Dean of Students',
          'Senate Building, Room 208. You can ask about student support and reporting options.',
        ),
        (
          'Health and urgent assistance',
          'University Hospital: opposite the Main Gate.\nMakerere University Police: +256 782 151656, near the Eastern Gate.\nUganda Police: 999 or 112 on mobile.',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contact.$1,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SelectableText(
                contact.$2,
                style: const TextStyle(fontSize: 13, height: 1.8),
              ),
            ],
          ),
        ),
      const ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('Confidentiality and formal reporting'),
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Text(
              'MakSafeSpace offers anonymous or confidential reporting. The published sexual-harassment policy requires identity disclosure to the respondent during a formal investigation. Ask the Directorate how this applies before proceeding. HERVOICE does not automatically forward reports to MakSafeSpace.',
              style: TextStyle(fontSize: 13, height: 1.8),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const SelectableText(
        'Contact sources: https://mak.ac.ug/get-touch and Makerere School of Medicine’s safeguarding guidance. Checked 10 November 2026.\nReporting policy: https://policies.mak.ac.ug/policy/policy-regulations-sexual-harassment-prevention',
        style: TextStyle(color: VoiceColors.muted, fontSize: 12, height: 1.8),
      ),
      const SizedBox(height: 24),
      const Text(
        'If you are in immediate danger, seek local emergency assistance. This app does not provide emergency response.',
        style: TextStyle(color: VoiceColors.muted, fontSize: 12, height: 1.8),
      ),
    ],
  );
}
