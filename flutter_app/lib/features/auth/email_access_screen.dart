import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/report_store.dart';

class EmailAccessScreen extends StatefulWidget {
  const EmailAccessScreen({
    super.key,
    required this.store,
    required this.reset,
  });
  final ReportStore store;
  final bool reset;
  @override
  State<EmailAccessScreen> createState() => _EmailAccessScreenState();
}

class _EmailAccessScreenState extends State<EmailAccessScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _code = TextEditingController(),
      _password = TextEditingController();
  bool _sent = false, _busy = false, _complete = false, _hidePassword = true;
  String? _message;
  String get _purpose => widget.reset ? 'reset' : 'register';
  Future<void> _send() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_sent) {
        await widget.store.completeEmailCode(
          _email.text.trim(),
          _purpose,
          _code.text.trim(),
          _password.text,
        );
        if (!mounted) return;
        setState(() {
          _message = widget.reset
              ? 'Password updated. Sign in with your new password.'
              : 'Email verified. You can now sign in.';
          _complete = true;
          _sent = false;
          _password.clear();
          _code.clear();
        });
      } else {
        await widget.store.requestEmailCode(_email.text.trim(), _purpose);
        if (!mounted) return;
        setState(() {
          _sent = true;
          _message = 'If this address is eligible, a code has been sent. Check your inbox. It expires in 15 minutes.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 510),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.reset
                        ? 'Recover your account.'
                        : 'Create your account.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.reset
                        ? 'Enter your account email to request a password-reset code.'
                        : 'Verify an email address you control. Email verification does not confirm university membership.',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy && !_sent && !_complete,
                    autofillHints: const [AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter an email address.',
                  ),
                  if (_sent) ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        labelText: '8-digit email code',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{8}$').hasMatch(value ?? '')
                          ? null
                          : 'Enter the 8-digit code.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hidePassword,
                      autofillHints: const [AutofillHints.newPassword],
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'New password (12–128 characters)',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: _busy
                              ? null
                              : () => setState(
                                  () => _hidePassword = !_hidePassword,
                                ),
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) =>
                          value != null &&
                              value.length >= 12 &&
                              value.length <= 128
                          ? null
                          : 'Use 12–128 characters.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_complete)
                    FilledButton(
                      onPressed: _busy ? null : _send,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : _sent
                            ? 'Verify and save password'
                            : 'Send verification code',
                      ),
                    ),
                  if (_sent)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _sent = false;
                              _code.clear();
                              _password.clear();
                            }),
                      child: const Text(
                        'Change email or start a new code request',
                      ),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _message!,
                          key: const Key('email-access-message'),
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/signin'),
                    child: const Text('Back to sign in'),
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
