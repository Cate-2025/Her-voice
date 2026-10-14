import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Brand(),
                  const SizedBox(height: 64),
                  const Eyebrow('A SPACE TO BE HEARD'),
                  const SizedBox(height: 20),
                  Text(
                    'Your voice matters.\nSo does your choice.',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'A private place to document your experience, explore support, and decide what happens next.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.8,
                      color: VoiceColors.muted,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const PaperCard(
                    color: VoiceColors.lavender,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Move at your own pace.',
                          style: TextStyle(fontFamily: 'Lora', fontSize: 23),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Write a little. Take a pause. Review your words. You choose when you are ready to share.',
                          style: TextStyle(height: 1.8),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Explore the preview'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    child: const Text('Preview the sign-in screen'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Design preview · fictional data · nothing is sent',
                    style: TextStyle(fontSize: 11, color: VoiceColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  bool _hide = true;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 510),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Brand(),
                  const SizedBox(height: 50),
                  const PageHeading(
                    eyebrow: 'WELCOME BACK',
                    title: 'A space of your own.',
                    subtitle: 'Sign in to return to your records.',
                  ),
                  Form(
                    key: _form,
                    child: PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'University email',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'student@example.test',
                            ),
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'Enter a fictional email address.',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Password',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            obscureText: _hide,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: 'Use a fictional password',
                              suffixIcon: IconButton(
                                tooltip: _hide
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(() => _hide = !_hide),
                                icon: Icon(
                                  _hide
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => v != null && v.length >= 8
                                ? null
                                : 'Use at least 8 characters for the preview.',
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () {
                                if (_form.currentState!.validate()) {
                                  context.go('/home');
                                }
                              },
                              child: const Text('Preview sign-in'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Use fictional credentials. Authentication is simulated in this preview.',
                    style: TextStyle(color: VoiceColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/welcome'),
                    child: const Text('Back to welcome'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
