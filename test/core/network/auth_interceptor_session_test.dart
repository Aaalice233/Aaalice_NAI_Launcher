import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/system_proxy_http_overrides.dart';
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

  test('并发 401 都等待刷新，并使用新 token 重试各自的请求', () async {
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = SystemProxyHttpOverrides('DIRECT');
    addTearDown(() => HttpOverrides.global = previousOverrides);

    final retriedPaths = <String>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final subscription = server.listen((request) async {
      expect(request.headers.value('authorization'), 'Bearer $_carolToken');
      retriedPaths.add(request.uri.path);
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    addTearDown(subscription.cancel);

    final started = Completer<void>();
    final joined = Completer<void>();
    final release = Completer<void>();
    refresh.outcome = TokenRefreshOutcome.refreshed;
    refresh.whileRefreshing = () async {
      if (!started.isCompleted) started.complete();
      if (refresh.calls == 2) joined.complete();
      await release.future;
      await signIn(_carolToken);
    };

    Future<int?> request(String path) async {
      try {
        final response = await dio.get<dynamic>(
          'http://127.0.0.1:${server.port}$path',
          options: Options(headers: {'Authorization': 'Bearer $_bobToken'}),
        );
        return response.statusCode;
      } on DioException catch (error) {
        return error.response?.statusCode;
      }
    }

    final first = request('/user/subscription');
    await started.future;
    final second = request('/ai/generate-image');
    // 旧实现在刷新期间直接返回第二个 401；无需依赖延时来制造竞态。
    await Future.any([joined.future, second.then<void>((_) {})]);
    release.complete();

    expect(await Future.wait([first, second]), [200, 200]);
    expect(
      retriedPaths,
      unorderedEquals(['/user/subscription', '/ai/generate-image']),
    );
    expect(auth.logoutCodes, isEmpty);
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
