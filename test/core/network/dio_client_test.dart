import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/proxy_settings_provider.dart';
import 'package:nai_launcher/core/network/system_proxy_http_overrides.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';

import '../../helpers/log_capture.dart';
import '../../helpers/memory_local_storage.dart';

class _MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

class _CountingRequestOptions extends RequestOptions {
  _CountingRequestOptions()
    : super(path: '/user/login', queryParameters: {'probe': 'local-fixture'});

  int uriReads = 0;

  @override
  Uri get uri {
    uriReads++;
    return super.uri;
  }
}

class _ProxyAddressNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setAddress(String? value) {
    state = value;
  }
}

void main() {
  final proxyAddress = NotifierProvider<_ProxyAddressNotifier, String?>(
    _ProxyAddressNotifier.new,
  );
  late ProviderContainer container;
  late HttpOverrides? previousOverrides;
  final clients = <Dio>[];

  setUp(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = SystemProxyHttpOverrides('DIRECT');
    container = ProviderContainer(
      overrides: [
        currentProxyAddressProvider.overrideWith(
          (ref) => ref.watch(proxyAddress),
        ),
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
    );
  });

  tearDown(() {
    for (final client in clients) {
      client.close(force: true);
    }
    clients.clear();
    container.dispose();
    HttpOverrides.global = previousOverrides;
  });

  Dio readClient() {
    final client = container.read(dioClientProvider);
    clients.add(client);
    return client;
  }

  test('无代理也使用 HTTP/1.1，并自动解压 gzip JSON 响应', () async {
    final client = readClient();
    expect(client.httpClientAdapter, isA<IOHttpClientAdapter>());
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final subscription = server.listen((request) async {
      expect(request.protocolVersion, '1.1');
      request.response.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.add(gzip.encode(utf8.encode('{"ok":true}')));
      await request.response.close();
    });
    addTearDown(subscription.cancel);

    final response = await client.get<dynamic>(
      'http://127.0.0.1:${server.port}/user/subscription',
      options: Options(headers: {'Authorization': 'Bearer local-fixture'}),
    );

    expect(response.data, {'ok': true});
  });

  test('超时警告的 URL 行不包含提示词查询串', () async {
    final interceptorProvider = Provider<ErrorInterceptor>(ErrorInterceptor.new);
    final interceptor = container.read(interceptorProvider);
    const secretPrompt = '不应出现在日志中的秘密提示词';
    final error = DioException(
      requestOptions: RequestOptions(
        baseUrl: 'http://127.0.0.1:8188',
        path: '/ai/generate-image/tags',
        queryParameters: {'prompt': secretPrompt},
      ),
      type: DioExceptionType.receiveTimeout,
    );

    final logs = await captureLogs(
      () => interceptor.onError(error, _MockErrorInterceptorHandler()),
    );
    final urlLine = logs
        .join('\n')
        .split('\n')
        .singleWhere((line) => line.startsWith('URL: '));

    expect(urlLine, 'URL: http://127.0.0.1:8188/ai/generate-image/tags');
    expect(urlLine, isNot(contains(secretPrompt)));
    expect(urlLine, isNot(contains('?')));
  });

  test('关闭调试日志时认证拦截器不求值请求 URI', () {
    AppLogger.debugSetMinimumLevelForTesting(Level.warning);
    addTearDown(() => AppLogger.debugSetMinimumLevelForTesting(null));
    final interceptor = container.read(
      Provider<AuthInterceptor>(AuthInterceptor.new),
    );
    final options = _CountingRequestOptions();
    final handler = RequestInterceptorHandler();

    interceptor.onRequest(options, handler);

    expect(handler.isCompleted, isTrue);
    expect(options.uriReads, 0);
  });

  test('代理地址变化会重建 HTTP/1.1 客户端', () {
    final first = readClient();

    container.read(proxyAddress.notifier).setAddress('127.0.0.1:7890');
    final second = readClient();

    expect(second, isNot(same(first)));
    expect(second.httpClientAdapter, isA<IOHttpClientAdapter>());
  });
}
