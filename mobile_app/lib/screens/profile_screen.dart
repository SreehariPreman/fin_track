import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/google_sheets_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passcodeController = TextEditingController();
  final _credentialsService = CredentialsService();
  final _sheetsService = GoogleSheetsService();
  final _db = DatabaseService.instance;

  bool _obscurePasscode = true;
  bool _loading = true;
  bool _saving = false;

  GoogleSignInAccount? _googleAccount;
  bool _connectingGoogle = false;
  bool _syncing = false;
  String? _sheetsError;
  String? _syncMessage;
  String? _spreadsheetUrl;

  @override
  void initState() {
    super.initState();
    _load();
    _loadGoogleAccount();
    _loadSpreadsheetUrl();
  }

  Future<void> _load() async {
    try {
      final email = await _credentialsService.readEmail();
      final passcode = await _credentialsService.readAppPasscode();
      if (!mounted) return;
      setState(() {
        _emailController.text = email ?? '';
        _passcodeController.text = passcode ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadGoogleAccount() async {
    try {
      final account = await _sheetsService.signInSilently();
      if (!mounted) return;
      setState(() => _googleAccount = account);
    } catch (_) {
      // Not signed in / plugin unavailable — leave the connect button showing.
    }
  }

  Future<void> _loadSpreadsheetUrl() async {
    try {
      final url = await _sheetsService.getStoredSpreadsheetUrl();
      if (!mounted) return;
      setState(() => _spreadsheetUrl = url);
    } catch (_) {
      // No spreadsheet yet, or plugin unavailable — leave the link hidden.
    }
  }

  Future<void> _openSpreadsheet() async {
    final url = _spreadsheetUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      setState(() => _sheetsError = 'Could not open the spreadsheet link.');
    }
  }

  Future<void> _connectGoogle() async {
    setState(() {
      _connectingGoogle = true;
      _sheetsError = null;
    });
    try {
      final account = await _sheetsService.signIn();
      setState(() => _googleAccount = account);
    } catch (e) {
      setState(() => _sheetsError = 'Could not connect Google account: $e');
    } finally {
      setState(() => _connectingGoogle = false);
    }
  }

  Future<void> _disconnectGoogle() async {
    await _sheetsService.signOut();
    setState(() => _googleAccount = null);
  }

  Future<void> _syncToSheet() async {
    setState(() {
      _syncing = true;
      _sheetsError = null;
      _syncMessage = null;
    });
    try {
      final unsynced = await _db.getUnsyncedTransactions();
      if (unsynced.isEmpty) {
        setState(() => _syncMessage = 'Already up to date — nothing new to sync.');
        return;
      }
      final url = await _sheetsService.appendTransactions(unsynced);
      final ids = unsynced.where((t) => t.id != null).map((t) => t.id!).toList();
      await _db.markSynced(ids);
      setState(() {
        _syncMessage = 'Synced ${unsynced.length} transaction(s) to Google Sheet.';
        _spreadsheetUrl = url;
      });
    } catch (e) {
      setState(() => _sheetsError = 'Sync failed: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await _credentialsService.save(
      email: _emailController.text,
      appPasscode: _passcodeController.text,
    );
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved. You can now fetch transactions from Sync.')),
    );
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
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Gmail connection', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your Gmail address and app passcode. These are '
                            'stored only on this device (Android Keystore) and used '
                            'solely to connect directly to imap.gmail.com.',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const SizedBox(height: 20),
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
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passcodeController,
                            obscureText: _obscurePasscode,
                            decoration: InputDecoration(
                              labelText: 'App passcode',
                              helperText: 'Gmail App Password (16 characters), not your normal password',
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePasscode ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscurePasscode = !_obscurePasscode),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'App passcode is required';
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
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Google Sheets backup', style: AppTextStyles.sectionTitle),
                          const SizedBox(height: 6),
                          Text(
                            'The app itself always keeps your full transaction history '
                            'on this device. Connecting Google is optional — it only lets '
                            'you push a backup copy to a Google Sheet whenever you tap Sync. '
                            'Nothing is synced automatically.',
                            style: AppTextStyles.bodySecondary,
                          ),
                          const SizedBox(height: 16),
                          if (_googleAccount == null)
                            OutlinedButton.icon(
                              onPressed: _connectingGoogle ? null : _connectGoogle,
                              icon: _connectingGoogle
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Connect Google account'),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Connected as ${_googleAccount!.email}',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _disconnectGoogle,
                                  child: const Text('Disconnect'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _syncing ? null : _syncToSheet,
                              icon: _syncing
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(_syncing ? 'Syncing...' : 'Sync to Google Sheet'),
                            ),
                          ],
                          if (_spreadsheetUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton.icon(
                                onPressed: _openSpreadsheet,
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('Open Google Sheet'),
                              ),
                            ),
                          if (_sheetsError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _sheetsError!,
                                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
                              ),
                            ),
                          if (_syncMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _syncMessage!,
                                style: AppTextStyles.bodySecondary.copyWith(color: AppColors.success),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
