import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's email + app passcode in the OS-backed secure store
/// (Android Keystore / iOS Keychain). Nothing is ever written to plain
/// files or sent anywhere other than directly to the IMAP server.
///
/// Reads are defensive on purpose. The ciphertext lives in app storage but
/// the key that decrypts it lives in the Keystore, and the two can come
/// apart: a restore from an Android backup brings the ciphertext back
/// without the key (Keystore material is deliberately never backed up),
/// and an OS upgrade or reinstall can invalidate the key under existing
/// data. Every read then throws. That used to happen during startup,
/// before the first frame — which looks like nothing but a black screen,
/// and survives reinstalling — so an unreadable value is now treated as
/// "nothing stored" and cleared, leaving the user to simply connect
/// again.
class CredentialsService {
  static const _emailKey = 'imap_email';
  static const _passcodeKey = 'imap_app_passcode';

  final _storage = const FlutterSecureStorage();

  Future<void> save({required String email, required String appPasscode}) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passcodeKey, value: appPasscode);
  }

  Future<String?> readEmail() => _read(_emailKey);

  Future<String?> readAppPasscode() => _read(_passcodeKey);

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
    await _deleteQuietly(_emailKey);
    await _deleteQuietly(_passcodeKey);
  }

  /// Reads one value, treating an undecryptable entry as absent.
  ///
  /// Catches broadly rather than just [PlatformException]: the underlying
  /// failure surfaces differently across OEM Keystore implementations
  /// (BadPaddingException, KeyStoreException, UserNotAuthenticated among
  /// them), and all of them mean the same thing here — the value cannot
  /// be recovered, so keeping it only guarantees the next read fails too.
  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (error) {
      debugPrint('CredentialsService: dropping unreadable "\$key" (\$error)');
      await _deleteQuietly(key);
      return null;
    }
  }

  /// Deleting can fail for the same reasons reading can, and there is
  /// nothing useful to do about it — throwing here would defeat the point.
  Future<void> _deleteQuietly(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // Ignored deliberately.
    }
  }
}
