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
          'Ask your university counselling service about appointments, availability, and how they handle confidentiality before sharing details.',
        ),
        (
          Icons.school_outlined,
          'Understand the university process',
          'Learn what reporting and case review involve.',
          'A university support office can explain reporting options, who will handle a report, and what to expect. You can ask questions before deciding whether to submit.',
        ),
        (
          Icons.people_outline,
          'Bring someone with you',
          'You can ask for support at appointments.',
          'Consider asking someone you trust to accompany you or help prepare questions. Check with the service about its appointment arrangements.',
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
      const PaperCard(
        color: VoiceColors.peach,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'University contacts',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'Confirmed contact details will appear here. This preview does not list unverified phone numbers or availability.',
              style: TextStyle(fontSize: 12, height: 1.8),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'If you are in immediate danger, seek local emergency assistance. This app does not provide emergency response.',
        style: TextStyle(color: VoiceColors.muted, fontSize: 12, height: 1.8),
      ),
    ],
  );
}
