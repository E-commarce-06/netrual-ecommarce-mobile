import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cartxis_app/core/storage/auth_token_storage.dart';

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  bool failWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure write failed');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemorySecureStore secureStore;
  late AuthTokenStorage tokenStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStore = _MemorySecureStore();
    tokenStorage = AuthTokenStorage(secureStore: secureStore);
  });

  test('migrates a legacy preferences token to secure storage once', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(AuthTokenStorage.tokenKey, 'legacy-token');

    expect(await tokenStorage.readToken(), 'legacy-token');
    expect(secureStore.values[AuthTokenStorage.tokenKey], 'legacy-token');
    expect(preferences.containsKey(AuthTokenStorage.tokenKey), isFalse);
  });

  test('keeps the secure token and removes a stale legacy copy', () async {
    final preferences = await SharedPreferences.getInstance();
    secureStore.values[AuthTokenStorage.tokenKey] = 'secure-token';
    await preferences.setString(AuthTokenStorage.tokenKey, 'stale-token');

    expect(await tokenStorage.readToken(), 'secure-token');
    expect(preferences.containsKey(AuthTokenStorage.tokenKey), isFalse);
  });

  test(
    'does not delete the legacy token when secure migration fails',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(AuthTokenStorage.tokenKey, 'legacy-token');
      secureStore.failWrites = true;

      await expectLater(tokenStorage.readToken(), throwsStateError);
      expect(preferences.getString(AuthTokenStorage.tokenKey), 'legacy-token');
    },
  );

  test(
    'writes and deletes tokens through secure storage and clears legacy data',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(AuthTokenStorage.tokenKey, 'old-token');

      await tokenStorage.writeToken('new-token');
      expect(secureStore.values[AuthTokenStorage.tokenKey], 'new-token');
      expect(preferences.containsKey(AuthTokenStorage.tokenKey), isFalse);

      await tokenStorage.deleteToken();
      expect(
          secureStore.values.containsKey(AuthTokenStorage.tokenKey), isFalse);
      expect(preferences.containsKey(AuthTokenStorage.tokenKey), isFalse);
    },
  );
}
