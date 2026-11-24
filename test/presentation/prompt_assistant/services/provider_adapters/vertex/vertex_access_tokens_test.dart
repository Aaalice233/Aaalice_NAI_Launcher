import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_access_tokens.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_credential.dart';

import 'vertex_test_support.dart';

void main() {
  late DateTime now;
  late VertexAccessTokens tokens;

  setUp(() {
    now = DateTime.utc(2026, 11, 23, 8);
    tokens = VertexAccessTokens(clock: () => now);
  });

  Dio dioWith(FakeGoogleServer server) {
    final dio = Dio()..httpClientAdapter = server;
    addTearDown(dio.close);
    return dio;
  }

  VertexOAuthCredential serviceAccount() =>
      VertexCredential.parse(serviceAccountJson()) as VertexOAuthCredential;

  test('服务账号用签名断言换取令牌，并在有效期内复用', () async {
    final server = FakeGoogleServer((_) => tokenResponse());
    final dio = dioWith(server);

    expect(await tokens.accessToken(dio, serviceAccount()), 'access-1');
    expect(await tokens.accessToken(dio, serviceAccount()), 'access-1');

    final request = server.tokenRequests.single;
    expect(request.uri, Uri.parse('https://oauth2.googleapis.com/token'));
    expect(
      request.options.contentType,
      startsWith(Headers.formUrlEncodedContentType),
    );
    expect(
      request.form['grant_type'],
      'urn:ietf:params:oauth:grant-type:jwt-bearer',
    );
    expect(verifyRs256(request.form['assertion']!), isTrue);
    expect(decodeJwtPart(request.form['assertion']!, 1)['scope'], VertexAccessTokens.scope);
  });

  test('临近过期提前刷新', () async {
    var issued = 0;
    final server = FakeGoogleServer(
      (_) => tokenResponse(token: 'access-${++issued}'),
    );
    final dio = dioWith(server);

    expect(await tokens.accessToken(dio, serviceAccount()), 'access-1');
    now = now.add(const Duration(minutes: 54));
    expect(await tokens.accessToken(dio, serviceAccount()), 'access-1');
    now = now.add(const Duration(minutes: 1, seconds: 1));
    expect(await tokens.accessToken(dio, serviceAccount()), 'access-2');
    expect(server.tokenRequests, hasLength(2));
  });

  test('并发请求共用一次换取', () async {
    final release = Completer<void>();
    final server = FakeGoogleServer((_) async {
      await release.future;
      return tokenResponse();
    });
    final dio = dioWith(server);

    final first = tokens.accessToken(dio, serviceAccount());
    final second = tokens.accessToken(dio, serviceAccount());
    await pumpEventQueue();
    release.complete();

    expect(await Future.wait([first, second]), ['access-1', 'access-1']);
    expect(server.tokenRequests, hasLength(1));
  });

  test('gcloud 用户凭据走 refresh_token 授权', () async {
    final server = FakeGoogleServer((_) => tokenResponse(token: 'user-token'));
    final credential =
        VertexCredential.parse(authorizedUserJson()) as VertexOAuthCredential;

    expect(await tokens.accessToken(dioWith(server), credential), 'user-token');
    expect(server.tokenRequests.single.form, {
      'grant_type': 'refresh_token',
      'client_id': 'client-id.apps.googleusercontent.com',
      'client_secret': 'client-secret-value',
      'refresh_token': 'refresh-token-value',
    });
  });

  test('invalidate 后重新换取', () async {
    var issued = 0;
    final server = FakeGoogleServer(
      (_) => tokenResponse(token: 'access-${++issued}'),
    );
    final dio = dioWith(server);

    await tokens.accessToken(dio, serviceAccount());
    tokens.invalidate(serviceAccount());
    expect(await tokens.accessToken(dio, serviceAccount()), 'access-2');
  });

  test('4xx 转成不可重试的鉴权错误，只带 OAuth 错误码与说明', () async {
    final server = FakeGoogleServer(
      (_) => FakeResponse.json({
        'error': 'invalid_grant',
        'error_description': 'Invalid JWT Signature.',
      }, status: 400),
    );
    final credential =
        VertexCredential.parse(authorizedUserJson()) as VertexOAuthCredential;

    await expectLater(
      tokens.accessToken(dioWith(server), credential),
      throwsA(
        isA<VertexAuthException>()
            .having(
              (e) => e.toString(),
              'message',
              'Vertex AI authentication failed: HTTP 400: '
                  'invalid_grant: Invalid JWT Signature.',
            )
            .having(
              (e) => e.toString(),
              'no secrets',
              isNot(contains('refresh-token-value')),
            ),
      ),
    );
  });

  test('令牌端点的 429 保留原始异常和 Retry-After', () async {
    final options = RequestOptions(path: 'https://oauth2.googleapis.com/token');
    final error = DioException.badResponse(
      statusCode: 429,
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['17'],
        }),
      ),
    );
    final dio = dioWith(FakeGoogleServer((_) => throw error));

    await expectLater(
      tokens.accessToken(dio, serviceAccount()),
      throwsA(same(error)),
    );
    expect(error.response!.headers.value('retry-after'), '17');
  });

  test('5xx 原样抛出 DioException，失败后不留缓存', () async {
    var fail = true;
    final server = FakeGoogleServer(
      (_) => fail
          ? FakeResponse.json({'error': 'backendError'}, status: 503)
          : tokenResponse(),
    );
    final dio = dioWith(server);

    await expectLater(
      tokens.accessToken(dio, serviceAccount()),
      throwsA(isA<DioException>()),
    );
    fail = false;
    expect(await tokens.accessToken(dio, serviceAccount()), 'access-1');
  });

  test('响应缺 access_token 时报错', () async {
    final server = FakeGoogleServer((_) => FakeResponse.json({'foo': 1}));
    await expectLater(
      tokens.accessToken(dioWith(server), serviceAccount()),
      throwsA(isA<VertexAuthException>()),
    );
  });
}
