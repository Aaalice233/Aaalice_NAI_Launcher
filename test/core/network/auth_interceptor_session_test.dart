import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/services/auth_error_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/token_refresh_service.dart';

const _aliceToken = 'expired.jwt.alice';
const _bobToken = 'session.jwt.bob';
const _carolToken = 'session.jwt.carol';

final _authInterceptorProvider = Provider<AuthInterceptor>(AuthInterceptor.new);

void main() {
  late SecureStorageService storage;
  late _RecordingAuthNotifier auth;
  late _ScriptedRefreshService refresh;
  late ProviderContainer container;
  late Dio dio;

  Future<void> signIn(String token) => storage.saveAuth(
    accessToken: token,
    expiry: DateTime.now().add(const Duration(days: 1)),
    email: 'user@example.invalid',
  );

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
    // 内存缓存是静态的，跨用例共享
    await storage.clearAll();
    await signIn(_bobToken);

    auth = _RecordingAuthNotifier();
    refresh = _ScriptedRefreshService();
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        authNotifierProvider.overrideWith(() => auth),
        tokenRefreshServiceProvider.overrideWith(() => refresh),
      ],
    );
    dio = Dio()
      ..httpClientAdapter = _UnauthorizedAdapter()
      ..interceptors.add(container.read(_authInterceptorProvider));
  });

  tearDown(() async {
    dio.close(force: true);
    container.dispose();
    await storage.clearAll();
  });

  Future<void> expectUnauthorized(String sentToken) {
    return expectLater(
      dio.get<void>(
        'https://api.example.invalid/user/subscription',
        options: Options(headers: {'Authorization': 'Bearer $sentToken'}),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
  }

  test('旧会话请求迟到的 401 不刷新、不登出当前会话', () async {
    await expectUnauthorized(_aliceToken);

    expect(refresh.calls, 0);
    expect(auth.logoutCodes, isEmpty);
    expect(await storage.getAccessToken(), _bobToken);
  });

  test('刷新期间会话已变更时透传 401，不再登出', () async {
    refresh.outcome = TokenRefreshOutcome.sessionChanged;

    await expectUnauthorized(_bobToken);

    expect(refresh.calls, 1);
    expect(auth.logoutCodes, isEmpty);
  });

  test('当前会话刷新失败时仍按原行为登出', () async {
    refresh.outcome = TokenRefreshOutcome.failed;

    await expectUnauthorized(_bobToken);

    expect(refresh.calls, 1);
    expect(auth.logoutCodes, [AuthErrorCode.authFailed]);
  });

  test('刷新失败但等待期间已切换账号时，不登出新会话', () async {
    refresh.outcome = TokenRefreshOutcome.failed;
    refresh.whileRefreshing = () => signIn(_carolToken);

    await expectUnauthorized(_bobToken);

    expect(refresh.calls, 1);
    expect(auth.logoutCodes, isEmpty);
    expect(await storage.getAccessToken(), _carolToken);
  });
}

class _RecordingAuthNotifier extends AuthNotifier {
  final logoutCodes = <AuthErrorCode?>[];

  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.authenticated, accountId: 'bob');

  @override
  Future<void> logout({AuthErrorCode? errorCode, int? httpStatusCode}) async {
    logoutCodes.add(errorCode);
  }
}

class _ScriptedRefreshService extends TokenRefreshService {
  TokenRefreshOutcome outcome = TokenRefreshOutcome.failed;
  Future<void> Function()? whileRefreshing;
  var calls = 0;

  @override
  Future<TokenRefreshOutcome> refreshCurrentToken() async {
    calls++;
    await whileRefreshing?.call();
    return outcome;
  }
}

class _UnauthorizedAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"message":"unauthorized"}', 401);
  }

  @override
  void close({bool force = false}) {}
}
