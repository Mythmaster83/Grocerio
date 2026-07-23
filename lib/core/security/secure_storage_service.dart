import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrapper around platform secure storage (Keychain on iOS, EncryptedSharedPreferences
/// on Android) for anything more sensitive than a UI preference:
/// - future auth tokens
/// - refresh tokens
/// - any user-entered credential
///
/// Do NOT put the Pexels API key here — that's a compile-time app secret,
/// not a per-user runtime secret; it belongs in EnvConfig. This service is
/// for values that are created/rotated during the app's runtime lifecycle.
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> deleteAll() => _storage.deleteAll();
}
