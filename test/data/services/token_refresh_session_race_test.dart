import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/token_refresh_service.dart';

const _staleJwt = 'stale.jwt.alice';
const _refreshedJwt = 'refreshed.jwt.alice';
const _bobToken = 'session.jwt.bob';

final _alice = SavedAccount(
  id: 'alice',
  email: 'alice@example.invalid',
  createdAt: DateTime.utc(2026),
  accountType: AccountType.credentials,
);

void main() {
  late SecureStorageService storage;
  late _PendingLoginApi api;
  late _AccountSlots slots;
  late ProviderContainer container;

  Future<void> signIn(String token, String email) => storage.saveAuth(
    accessToken: token,
    expiry: DateTime.now().add(const Duration(days: 1)),
    email: email,
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
    // 内存缓存是静态的，跨用例共享
    await storage.clearAll();
    await signIn(_staleJwt, _alice.email);
    await storage.saveAccountAccessKey(_alice.id, 'alice-access-key');

    api = _PendingLoginApi();
    slots = _AccountSlots({_alice.id: _staleJwt});
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        naiAuthApiServiceProvider.overrideWithValue(api),
        authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
        accountManagerNotifierProvider.overrideWith(() => slots),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await storage.clearAll();
  });

  TokenRefreshService refreshService() =>
      container.read(tokenRefreshServiceProvider.notifier);

  Future<Future<TokenRefreshOutcome>> startRefreshAndWaitForRequest() async {
    final refresh = refreshService().refreshCurrentToken();
    await pumpEventQueue();
    expect(api.calls, 1, reason: 'refresh must be waiting on the network');
    return refresh;
  }

  test('刷新请求在途时退出登录，迟到的刷新结果不能恢复全局会话 Token', () async {
    final refresh = await startRefreshAndWaitForRequest();

    await container.read(authNotifierProvider.notifier).logout();
    expect(await storage.getAccessToken(), isNull);

    api.pending.complete({'accessToken': _refreshedJwt});

    expect(await refresh, TokenRefreshOutcome.sessionChanged);
    expect(await storage.getAccessToken(), isNull);
    expect(slots.tokens[_alice.id], _refreshedJwt);
  });

  test('刷新请求在途时切换到其他账号，迟到的刷新结果不能覆盖新会话 Token', () async {
    final refresh = await startRefreshAndWaitForRequest();

    await signIn(_bobToken, 'bob@example.invalid');
    api.pending.complete({'accessToken': _refreshedJwt});

    expect(await refresh, TokenRefreshOutcome.sessionChanged);
    expect(await storage.getAccessToken(), _bobToken);
  });

  test('会话未变时刷新结果写入全局会话', () async {
    final refresh = await startRefreshAndWaitForRequest();

    api.pending.complete({'accessToken': _refreshedJwt});

    expect(await refresh, TokenRefreshOutcome.refreshed);
    expect(await storage.getAccessToken(), _refreshedJwt);
    expect(slots.tokens[_alice.id], _refreshedJwt);
  });

  test('并发刷新共享同一次请求，后到的调用方不会被判为失败', () async {
    final first = await startRefreshAndWaitForRequest();
    final second = refreshService().refreshCurrentToken();
    await pumpEventQueue();

    api.pending.complete({'accessToken': _refreshedJwt});

    expect(await first, TokenRefreshOutcome.refreshed);
    expect(await second, TokenRefreshOutcome.refreshed);
    expect(api.calls, 1);
  });

  test('为非当前会话的账号刷新时只更新该账号，不顶掉当前会话', () async {
    await signIn(_bobToken, 'bob@example.invalid');
    api.pending.complete({'accessToken': _refreshedJwt});

    final token = await refreshService().refreshTokenForAccount(_alice.id);

    expect(token, _refreshedJwt);
    expect(slots.tokens[_alice.id], _refreshedJwt);
    expect(await storage.getAccessToken(), _bobToken);
  });
}

class _PendingLoginApi extends NAIAuthApiService {
  _PendingLoginApi() : super(Dio());

  final pending = Completer<Map<String, dynamic>>();
  var calls = 0;

  @override
  Future<Map<String, dynamic>> loginWithKey(
    String accessKey, {
    NaiApiEndpointConfig endpoint = NaiApiEndpointConfig.official,
  }) {
    calls++;
    return pending.future;
  }
}

class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.authenticated, accountId: _alice.id);
}

class _AccountSlots extends AccountManagerNotifier {
  _AccountSlots(this.tokens);

  final Map<String, String> tokens;

  @override
  AccountManagerState build() => AccountManagerState(accounts: [_alice]);

  @override
  Future<String?> getAccountToken(String accountId) async => tokens[accountId];

  @override
  Future<void> updateAccountToken(String accountId, String newToken) async {
    tokens[accountId] = newToken;
  }
}
