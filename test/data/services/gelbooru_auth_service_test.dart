import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/gelbooru_api_service.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_credentials.dart';
import 'package:nai_launcher/data/services/gelbooru_auth_service.dart';

void main() {
  const existingCredentials = GelbooruCredentials(
    userId: 100,
    apiKey: 'existing-key',
  );

  String encode(GelbooruCredentials credentials) {
    return jsonEncode(credentials.toJson());
  }

  ProviderContainer createContainer(
    _FakeSecureStorage storage,
    _FakeGelbooruApiService api,
  ) {
    return ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        gelbooruApiServiceProvider.overrideWithValue(api),
      ],
    );
  }

  test('rejects non-positive User IDs before issuing a request', () async {
    final storage = _FakeSecureStorage();
    final api = _FakeGelbooruApiService();
    final container = createContainer(storage, api);
    addTearDown(container.dispose);
    final notifier = container.read(gelbooruAuthProvider.notifier);
    await notifier.ensureInitialized();

    final success = await notifier.configure('0', 'key');

    expect(success, isFalse);
    expect(api.verified, isEmpty);
    expect(storage.gelbooru, isNull);
    expect(
      container.read(gelbooruAuthProvider).error,
      GelbooruAuthError.invalidInput,
    );
  });

  test('persists credentials only after successful verification', () async {
    final storage = _FakeSecureStorage();
    final api = _FakeGelbooruApiService();
    final container = createContainer(storage, api);
    addTearDown(container.dispose);
    final notifier = container.read(gelbooruAuthProvider.notifier);
    await notifier.ensureInitialized();

    final success = await notifier.configure('24680', 'new-key');

    expect(success, isTrue);
    expect(api.verified.single.userId, 24680);
    expect(storage.gelbooru, contains('new-key'));
    expect(container.read(gelbooruAuthProvider).isAuthenticated, isTrue);
  });

  test('marks 401 or 403 credentials invalid without saving them', () async {
    final storage = _FakeSecureStorage();
    final api = _FakeGelbooruApiService(
      error: const GelbooruApiException(
        GelbooruApiErrorType.invalidCredentials,
        statusCode: 403,
      ),
    );
    final container = createContainer(storage, api);
    addTearDown(container.dispose);
    final notifier = container.read(gelbooruAuthProvider.notifier);
    await notifier.ensureInitialized();

    final success = await notifier.configure('24680', 'rejected-key');

    expect(success, isFalse);
    expect(storage.gelbooru, isNull);
    expect(
      container.read(gelbooruAuthProvider).status,
      GelbooruAuthStatus.invalid,
    );
  });

  for (final errorType in [
    GelbooruApiErrorType.rateLimited,
    GelbooruApiErrorType.timeout,
    GelbooruApiErrorType.server,
    GelbooruApiErrorType.cancelled,
  ]) {
    test('$errorType keeps the previously saved credential active', () async {
      final encoded = encode(existingCredentials);
      final storage = _FakeSecureStorage(gelbooru: encoded);
      final api = _FakeGelbooruApiService(
        error: GelbooruApiException(errorType),
      );
      final container = createContainer(storage, api);
      addTearDown(container.dispose);
      final notifier = container.read(gelbooruAuthProvider.notifier);
      await notifier.ensureInitialized();

      final success = await notifier.configure('200', 'replacement-key');

      expect(success, isFalse);
      expect(storage.gelbooru, encoded);
      final state = container.read(gelbooruAuthProvider);
      expect(state.credentials?.userId, existingCredentials.userId);
      expect(state.isAuthenticated, isTrue);
    });
  }

  test('Gelbooru logout does not delete Danbooru credentials', () async {
    final storage = _FakeSecureStorage(
      gelbooru: encode(existingCredentials),
      danbooru: '{"username":"dan","apiKey":"dan-key"}',
    );
    final container = createContainer(storage, _FakeGelbooruApiService());
    addTearDown(container.dispose);
    final notifier = container.read(gelbooruAuthProvider.notifier);
    await notifier.ensureInitialized();

    await notifier.logout();

    expect(storage.gelbooru, isNull);
    expect(storage.danbooru, isNotNull);
    expect(
      container.read(gelbooruAuthProvider).status,
      GelbooruAuthStatus.unconfigured,
    );
  });
}

class _FakeSecureStorage extends SecureStorageService {
  _FakeSecureStorage({this.gelbooru, this.danbooru});

  String? gelbooru;
  String? danbooru;

  @override
  Future<String?> getGelbooruCredentials() async => gelbooru;

  @override
  Future<void> saveGelbooruCredentials(String credentialsJson) async {
    gelbooru = credentialsJson;
  }

  @override
  Future<void> deleteGelbooruCredentials() async {
    gelbooru = null;
  }

  @override
  Future<String?> getDanbooruCredentials() async => danbooru;
}

class _FakeGelbooruApiService extends GelbooruApiService {
  _FakeGelbooruApiService({this.error}) : super(Dio());

  final GelbooruApiException? error;
  final List<GelbooruCredentials> verified = [];

  @override
  Future<void> verifyCredentials(GelbooruCredentials credentials) async {
    verified.add(credentials);
    if (error != null) throw error!;
  }
}
