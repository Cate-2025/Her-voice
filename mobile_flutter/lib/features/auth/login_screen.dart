import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../data/hervoice_repository.dart';
import '../../data/preferences_store.dart';
import '../../state/auth_controller.dart';
import 'register_screen.dart';

/// Sign-in screen. The email doubles as the login identifier so no extra
/// personal information has to be collected (section 3.12 VII).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthController auth = context.read<AuthController>();
    final bool ok = await auth.login(email: _email.text.trim(), password: _password.text);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(auth.errorMessage ?? 'Sign in failed')),
    );
  }

  /// Lets the demonstrator point the app at a machine on the local network, which
  /// is needed when running on a physical phone rather than an emulator.
  Future<void> _editServerAddress() async {
    final PreferencesStore preferences = context.read<PreferencesStore>();
    final TextEditingController controller = TextEditingController(text: preferences.apiBaseUrl);

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Backend address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'An Android emulator reaches your computer at 10.0.2.2. A physical phone '
              'needs your computer\'s Wi-Fi address, for example http://192.168.0.10:4000/api',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'API base URL'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    await preferences.setApiBaseUrl(result);
    if (!mounted) return;
    context.read<HerVoiceRepository>().api.baseUrl = result;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server address set to $result')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AuthController auth = context.watch<AuthController>();
    final PreferencesStore preferences = context.read<PreferencesStore>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: HerVoiceTheme.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.record_voice_over_outlined,
                        size: 56, color: HerVoiceColors.pinkPrimary),
                    const SizedBox(height: 12),
                    const Text(
                      'HER VOICE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: HerVoiceColors.pinkPrimary,
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Empowering your safety',
                        style: TextStyle(color: HerVoiceColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Sign in securely',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              validator: (String? value) {
                                final String text = (value ?? '').trim();
                                if (text.isEmpty) return 'Enter your email';
                                if (!text.contains('@')) return 'Enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (String? value) =>
                                  (value ?? '').isEmpty ? 'Enter your password' : null,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: auth.busy ? null : _submit,
                              child: auth.busy
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Sign in'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: auth.busy
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const RegisterScreen(),
                                        ),
                                      ),
                              child: const Text('New here? Create a confidential account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Connected to ${preferences.apiBaseUrl}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: HerVoiceColors.textMuted),
                    ),
                    TextButton.icon(
                      onPressed: _editServerAddress,
                      icon: const Icon(Icons.settings_ethernet, size: 16),
                      label: const Text('Change server address', style: TextStyle(fontSize: 12)),
                    ),
                    const Text(
                      'Notifications you receive later will only say that you have a new '
                      'confidential notification. The details stay inside the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: HerVoiceColors.textMuted, height: 1.4),
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
}
