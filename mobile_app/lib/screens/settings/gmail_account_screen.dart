import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../services/background_sync_service.dart';
import '../../services/credentials_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';

/// The Gmail mailbox transactions are read from: address, app password,
/// and the connection state.
class GmailAccountScreen extends StatefulWidget {
  const GmailAccountScreen({super.key});

  @override
  State<GmailAccountScreen> createState() => _GmailAccountScreenState();
}

class _GmailAccountScreenState extends State<GmailAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _credentialsService = CredentialsService();

  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final email = await _credentialsService.readEmail();
      final passcode = await _credentialsService.readAppPasscode();
      if (!mounted) return;
      setState(() {
        _emailController.text = email ?? '';
        _passcodeController.text = passcode ?? '';
        _connected = (email ?? '').isNotEmpty && (passcode ?? '').isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _credentialsService.save(
      email: _emailController.text,
      appPasscode: _passcodeController.text,
    );
    // Now that there's something worth syncing in the background, ask for
    // notification permission and schedule the periodic sync. Best-effort
    // — a failure here (e.g. WorkManager unavailable) shouldn't block
    // saving your credentials.
    try {
      await NotificationService.instance.requestPermission();
      await BackgroundSyncService.register();
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _connected = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gmail Account')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _connected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.linkBreak,
                              size: 20,
                              color: _connected ? AppColors.success : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _connected ? 'Connected' : 'Not connected',
                              style: AppTextStyles.sectionTitle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email address'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passcodeController,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'App password',
                            helperText: '16-character Gmail App Password',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? PhosphorIconsRegular.eye
                                  : PhosphorIconsRegular.eyeSlash),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'App password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Stored on this device only, and used solely to connect to '
                      'imap.gmail.com.',
                      style: AppTextStyles.supporting,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
