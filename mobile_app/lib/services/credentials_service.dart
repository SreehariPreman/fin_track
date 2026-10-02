import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's email + app passcode in the OS-backed secure store
/// (Android Keystore / iOS Keychain). Nothing is ever written to plain
/// files or sent anywhere other than directly to the IMAP server.
class CredentialsService {
  static const _emailKey = 'imap_email';
  static const _passcodeKey = 'imap_app_passcode';

  final _storage = const FlutterSecureStorage();

  Future<void> save({required String email, required String appPasscode}) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passcodeKey, value: appPasscode);
  }

  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<String?> readAppPasscode() => _storage.read(key: _passcodeKey);

  /// The name shown in the Home screen greeting, derived from the local
  /// part of the connected address (`priya.s@gmail.com` -> "Priya S")
  /// rather than asked for separately — one less thing to fill in, and it
  /// can't go stale against the account actually in use. Null until an
  /// address has been saved.
  Future<String?> readDisplayName() async => displayNameFromEmail(await readEmail());

  /// The derivation itself, pure so it can be tested without touching the
  /// keystore. Returns null for anything that yields no letters at all
  /// (e.g. `12345@gmail.com`) — better a generic greeting than "12345".
  static String? displayNameFromEmail(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    final local = email.trim().split('@').first;
    final words = local
        .split(RegExp(r'[._\-+]+'))
        .map((word) => word.replaceAll(RegExp(r'[0-9]'), ''))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .toList();
    return words.isEmpty ? null : words.join(' ');
  }

  Future<bool> hasCredentials() async {
    final email = await readEmail();
    final passcode = await readAppPasscode();
    return (email != null && email.isNotEmpty) &&
        (passcode != null && passcode.isNotEmpty);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passcodeKey);
  }
}
