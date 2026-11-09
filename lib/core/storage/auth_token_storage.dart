import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal secure key/value contract so token migration can be unit-tested
/// without invoking native secure-storage channels.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureKeyValueStore implements SecureKeyValueStore {
  PlatformSecureKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Secure storage for the bearer token, with one-time migration from the old
/// SharedPreferences key. The legacy copy is removed only after secure writes
/// succeed, so a failed migration does not silently lose the current session.
class AuthTokenStorage {
  AuthTokenStorage({
    SecureKeyValueStore? secureStore,
    Future<SharedPreferences> Function()? preferencesLoader,
  })  : _secureStore = secureStore ?? PlatformSecureKeyValueStore(),
        _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static final AuthTokenStorage instance = AuthTokenStorage();
  static const String tokenKey = 'auth_token';

  final SecureKeyValueStore _secureStore;
  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<void> writeToken(String token) async {
    if (token.trim().isEmpty) {
      throw ArgumentError.value(token, 'token', 'Must not be empty.');
    }

    await _secureStore.write(tokenKey, token);
    final preferences = await _preferencesLoader();
    await preferences.remove(tokenKey);
  }

  Future<String?> readToken() async {
    final secureToken = await _secureStore.read(tokenKey);
    final preferences = await _preferencesLoader();

    if (secureToken != null && secureToken.isNotEmpty) {
      if (preferences.containsKey(tokenKey)) {
        await preferences.remove(tokenKey);
      }
      return secureToken;
    }

    final legacyToken = preferences.getString(tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) {
      if (legacyToken != null) await preferences.remove(tokenKey);
      return null;
    }

    await _secureStore.write(tokenKey, legacyToken);
    await preferences.remove(tokenKey);
    return legacyToken;
  }

  Future<void> deleteToken() async {
    try {
      await _secureStore.delete(tokenKey);
    } finally {
      final preferences = await _preferencesLoader();
      await preferences.remove(tokenKey);
    }
  }
}
