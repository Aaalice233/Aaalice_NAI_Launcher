import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/services/token_refresh_service.dart';
import 'package:nai_launcher/presentation/providers/account_manager_provider.dart';

void main() {
  test('refreshes current credentials JWT through the image user host', () async {
    final harness = _RefreshHarness.create();
    addTearDown(harness.dispose);

    final refreshed = await harness.container
        .read(tokenRefreshServiceProvider.notifier)
        .refreshCurrentToken();

    expect(refreshed, isTrue);
    expect(harness.storage.savedAccessToken, _RefreshHarness.newToken);
    expect(harness.storage.savedEmail, harness.account.email);
    expect(harness.storage.savedExpiry, isNotNull);
    expect(
      harness.storage.savedExpiry!.isAfter(
        DateTime.now().add(const Duration(days: 29)),
      ),
      isTrue,
    );
    expect(harness.accountManager.accountToken, _RefreshHarness.newToken);
    expect(harness.adapter.requests, hasLength(1));
    expect(
      harness.adapter.requests.single.uri.toString(),
      '${ApiConstants.imageBaseUrl}${ApiConstants.loginEndpoint}',
    );
    expect(
      harness.adapter.requests.single.data,
      {'key': _RefreshHarness.accessKey},
    );
  });

  test('refreshes a selected credentials account and returns its new JWT', () async {
    final harness = _RefreshHarness.create();
    addTearDown(harness.dispose);

    final token = await harness.container
        .read(tokenRefreshServiceProvider.notifier)
        .refreshTokenForAccount(harness.account.id);

    expect(token, _RefreshHarness.newToken);
    expect(harness.storage.savedAccessToken, _RefreshHarness.newToken);
    expect(harness.accountManager.accountToken, _RefreshHarness.newToken);
    expect(harness.adapter.requests, hasLength(1));
  });
}

class _RefreshHarness {
  _RefreshHarness({
    required this.account,
    required this.storage,
    required this.accountManager,
    required this.adapter,
    required this.dio,
    required this.container,
  });

  static const oldToken = 'old.jwt.signature';
  static const newToken = 'new.jwt.signature';
  static const accessKey = 'stored-access-key';

  final SavedAccount account;
  final _FakeSecureStorageService storage;
  final _FakeAccountManagerNotifier accountManager;
  final _LoginDioAdapter adapter;
  final Dio dio;
  final ProviderContainer container;

  factory _RefreshHarness.create() {
    final account = SavedAccount(
      id: 'credentials-account',
      email: 'fixture@example.invalid',
      nickname: 'Test Account',
      createdAt: DateTime.utc(2026),
      accountType: AccountType.credentials,
    );
    final storage = _FakeSecureStorageService(
      currentToken: oldToken,
      accessKeys: {account.id: accessKey},
    );
    final accountManager = _FakeAccountManagerNotifier(
      account: account,
      accountToken: oldToken,
    );
    final adapter = _LoginDioAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final apiService = NAIAuthApiService(dio);
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        accountManagerNotifierProvider.overrideWith(() => accountManager),
        naiAuthApiServiceProvider.overrideWithValue(apiService),
      ],
    );

    return _RefreshHarness(
      account: account,
      storage: storage,
      accountManager: accountManager,
      adapter: adapter,
      dio: dio,
      container: container,
    );
  }

  void dispose() {
    container.dispose();
    dio.close(force: true);
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService({
    required this.currentToken,
    required this.accessKeys,
  });

  String? currentToken;
  final Map<String, String> accessKeys;
  String? savedAccessToken;
  DateTime? savedExpiry;
  String? savedEmail;

  @override
  Future<String?> getAccessToken() async => currentToken;

  @override
  Future<String?> getAccountAccessKey(String accountId) async =>
      accessKeys[accountId];

  @override
  Future<void> saveAuth({
    required String accessToken,
    required DateTime expiry,
    required String email,
  }) async {
    savedAccessToken = accessToken;
    savedExpiry = expiry;
    savedEmail = email;
    currentToken = accessToken;
  }
}

class _FakeAccountManagerNotifier extends AccountManagerNotifier {
  _FakeAccountManagerNotifier({
    required this.account,
    required this.accountToken,
  });

  final SavedAccount account;
  String? accountToken;

  @override
  AccountManagerState build() => AccountManagerState(accounts: [account]);

  @override
  Future<String?> getAccountToken(String accountId) async =>
      accountId == account.id ? accountToken : null;

  @override
  Future<void> updateAccountToken(String accountId, String newToken) async {
    if (accountId == account.id) {
      accountToken = newToken;
    }
  }
}

class _LoginDioAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'accessToken': _RefreshHarness.newToken}),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
