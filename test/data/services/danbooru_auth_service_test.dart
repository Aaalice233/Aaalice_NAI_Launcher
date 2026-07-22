import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const legacyKey = DanbooruAuth.legacyCredentialsKey;
  const newCredentials = DanbooruCredentials(
    username: 'new-user',
    apiKey: 'new-key',
  );
  const legacyCredentials = DanbooruCredentials(
    username: 'legacy-user',
    apiKey: 'legacy-key',
  );

  String encode(DanbooruCredentials credentials) {
    return jsonEncode(credentials.toJson());
  }

  ProviderContainer createContainer(
    _FakeSecureStorage storage,
    _FakeVerifier verifier,
  ) {
    return ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        danbooruCredentialVerifierProvider.overrideWithValue(verifier),
      ],
    );
  }

  test(
    'prefers the new secure-storage credential and removes legacy data',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: encode(legacyCredentials),
      });
      final storage = _FakeSecureStorage(danbooru: encode(newCredentials));
      final verifier = _FakeVerifier();
      final container = createContainer(storage, verifier);
      addTearDown(container.dispose);

      final notifier = container.read(danbooruAuthProvider.notifier);
      await notifier.ensureInitialized();

      expect(verifier.lastCredentials?.username, 'new-user');
      expect(container.read(danbooruAuthProvider).isLoggedIn, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(legacyKey), isFalse);
    },
  );

  test(
    'migrates legacy credentials only after secure read-back succeeds',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: encode(legacyCredentials),
      });
      final storage = _FakeSecureStorage();
      final container = createContainer(storage, _FakeVerifier());
      addTearDown(container.dispose);

      await container.read(danbooruAuthProvider.notifier).ensureInitialized();

      expect(storage.danbooru, encode(legacyCredentials));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(legacyKey), isFalse);
      expect(container.read(danbooruAuthProvider).isLoggedIn, isTrue);
    },
  );

  test(
    'keeps legacy credentials and current login when migration fails',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: encode(legacyCredentials),
      });
      final storage = _FakeSecureStorage(failDanbooruSave: true);
      final container = createContainer(storage, _FakeVerifier());
      addTearDown(container.dispose);

      await container.read(danbooruAuthProvider.notifier).ensureInitialized();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(legacyKey), encode(legacyCredentials));
      expect(container.read(danbooruAuthProvider).isLoggedIn, isTrue);
    },
  );

  test(
    'recovers from a damaged new value by migrating the legacy value',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: encode(legacyCredentials),
      });
      final storage = _FakeSecureStorage(danbooru: '{broken-json');
      final verifier = _FakeVerifier();
      final container = createContainer(storage, verifier);
      addTearDown(container.dispose);

      await container.read(danbooruAuthProvider.notifier).ensureInitialized();

      expect(storage.danbooru, encode(legacyCredentials));
      expect(verifier.lastCredentials?.username, 'legacy-user');
    },
  );

  test(
    'Danbooru logout clears both Danbooru stores but not Gelbooru',
    () async {
      SharedPreferences.setMockInitialValues({
        legacyKey: encode(legacyCredentials),
      });
      final storage = _FakeSecureStorage(
        danbooru: encode(newCredentials),
        gelbooru: '{"userId":1,"apiKey":"gel-key"}',
      );
      final container = createContainer(storage, _FakeVerifier());
      addTearDown(container.dispose);
      final notifier = container.read(danbooruAuthProvider.notifier);
      await notifier.ensureInitialized();

      await notifier.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(storage.danbooru, isNull);
      expect(prefs.containsKey(legacyKey), isFalse);
      expect(storage.gelbooru, isNotNull);
    },
  );
}

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage({
    this.danbooru,
    this.gelbooru,
    this.failDanbooruSave = false,
  });

  String? danbooru;
  String? gelbooru;
  final bool failDanbooruSave;

  @override
  Future<String?> getDanbooruCredentials() async => danbooru;

  @override
  Future<void> saveDanbooruCredentials(String credentialsJson) async {
    if (failDanbooruSave) throw StateError('secure storage unavailable');
    danbooru = credentialsJson;
  }

  @override
  Future<void> deleteDanbooruCredentials() async {
    danbooru = null;
  }

  @override
  Future<String?> getGelbooruCredentials() async => gelbooru;

  @override
  Future<void> deleteGelbooruCredentials() async {
    gelbooru = null;
  }
}

class _FakeVerifier extends DanbooruCredentialVerifier {
  DanbooruCredentials? lastCredentials;

  @override
  Future<(DanbooruUser?, bool isNetworkError)> verify(
    DanbooruCredentials credentials,
  ) async {
    lastCredentials = credentials;
    return (DanbooruUser(id: 1, name: credentials.username), false);
  }
}
