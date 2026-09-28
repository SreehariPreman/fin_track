import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's email + app passcode in the OS-backed secure store
/// (Android Keystore / iOS Keychain). Nothing is ever written to plain
/// files or sent anywhere other than directly to the IMAP server.
class CredentialsService {
  static const _emailKey = 'imap_email';
  static const _passcodeKey = 'imap_app_passcode';
  static const _nameKey = 'display_name';

  final _storage = const FlutterSecureStorage();

  Future<void> save({required String email, required String appPasscode}) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passcodeKey, value: appPasscode);
  }

  Future<String?> readEmail() => _storage.read(key: _emailKey);

  Future<String?> readAppPasscode() => _storage.read(key: _passcodeKey);

  /// The name shown in the Home screen greeting — entered once in
  /// Settings, stored the same way as everything else here (on-device
  /// only).
  Future<void> saveName(String name) => _storage.write(key: _nameKey, value: name.trim());

  Future<String?> readName() => _storage.read(key: _nameKey);

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
