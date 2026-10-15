import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/components.dart';
import '../../core/demo_store.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.store});
  final ReportStore store;
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
                    child: Text(
                      store.isConnected
                          ? 'Sign in to the prototype'
                          : 'Explore the preview',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    child: Text(
                      store.isConnected
                          ? 'Sign in'
                          : 'Preview the sign-in screen',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    store.isConnected
                        ? 'Connected prototype · use fictional incident details for testing'
                        : 'Design preview · fictional data · nothing is sent',
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
  const SignInScreen({super.key, required this.store});
  final ReportStore store;
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  bool _hide = true;
  bool _busy = false;
  String _email = '', _password = '';
  String? _error;

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.login(_email, _password);
      if (mounted && widget.store.authenticated) context.go('/home');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                            onChanged: (value) => _email = value,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'student@example.test',
                            ),
                            validator: (v) => v != null && v.contains('@')
                                ? null
                                : 'Enter an email address.',
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Password',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            onChanged: (value) => _password = value,
                            enabled: !_busy,
                            obscureText: _hide,
                            enableSuggestions: false,
                            autocorrect: false,
                            decoration: InputDecoration(
                              hintText: 'Account password',
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
                                : 'Use at least 8 characters.',
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _signIn,
                              child: Text(
                                _busy
                                    ? 'Signing in…'
                                    : widget.store.isConnected
                                    ? 'Sign in'
                                    : 'Preview sign-in',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Text(_error!, key: const Key('signin-error')),
                  Text(
                    widget.store.isConnected
                        ? 'Use your seeded student account. Reports are sent to the configured prototype server; use fictional details only.'
                        : 'Use fictional credentials. Authentication is simulated in this preview.',
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
