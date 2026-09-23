import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/credentials_service.dart';
import '../services/database_service.dart';
import '../services/google_sheets_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    _loadGoogleAccount();
  }

  Future<void> _load() async {
    final email = await _credentialsService.readEmail();
    final passcode = await _credentialsService.readAppPasscode();
    setState(() {
      _emailController.text = email ?? '';
      _passcodeController.text = passcode ?? '';
      _loading = false;
    });
  }

  Future<void> _loadGoogleAccount() async {
    final account = await _sheetsService.signInSilently();
    if (!mounted) return;
    setState(() => _googleAccount = account);
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
      await _sheetsService.appendTransactions(unsynced);
      final ids = unsynced.where((t) => t.id != null).map((t) => t.id!).toList();
      await _db.markSynced(ids);
      setState(() => _syncMessage = 'Synced ${unsynced.length} transaction(s) to Google Sheet.');
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
      const SnackBar(content: Text('Saved. You can now fetch transactions from Home.')),
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
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter your Gmail address and app passcode. '
                      'These are stored only on this device (Android Keystore) '
                      'and used solely to connect directly to imap.gmail.com.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
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
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePasscode ? Icons.visibility : Icons.visibility_off),
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
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                    const Divider(height: 48),
                    Text(
                      'Google Sheets backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app itself always keeps your full transaction history '
                      'on this device. Connecting Google is optional — it only lets '
                      'you push a backup copy to a Google Sheet whenever you tap Sync. '
                      'Nothing is synced automatically.',
                      style: TextStyle(color: Colors.black54),
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
                          Expanded(child: Text('Connected as ${_googleAccount!.email}')),
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
                    if (_sheetsError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_sheetsError!, style: const TextStyle(color: Colors.red)),
                      ),
                    if (_syncMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_syncMessage!, style: const TextStyle(color: Colors.green)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
