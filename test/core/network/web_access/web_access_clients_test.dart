import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/web_access/exa_search_client.dart';
import 'package:nai_launcher/core/network/web_access/safe_web_reader.dart';
import 'package:nai_launcher/core/network/web_access/searxng_search_client.dart';
import 'package:nai_launcher/core/network/web_access/web_access_http_transport.dart';
import 'package:nai_launcher/core/network/web_access/web_access_models.dart';
import 'package:nai_launcher/core/network/web_access/web_access_service.dart';

void main() {
  group('SearxngSearchClient', () {
    test('maps JSON results and enforces domain filters locally', () async {
      final requestSeen = Completer<Uri>();
      final server = await _serve((request) async {
        requestSeen.complete(request.uri);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'results': [
              {
                'title': 'Allowed result',
                'url': 'https://docs.example.com/page',
                'content': 'Useful snippet',
              },
              {
                'title': 'Blocked result',
                'url': 'https://bad.example/page',
                'content': 'Should not escape filtering',
              },
              {
                'title': 'Unsafe scheme',
                'url': 'file://example.com/private',
                'content': 'Should not be exposed as a web result',
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final response = await SearxngSearchClient(Dio()).search(
        baseUrl: 'http://${server.address.host}:${server.port}',
        request: const WebSearchRequest(
          query: 'flutter agents',
          resultCount: 5,
          recency: WebSearchRecency.week,
          includeDomains: ['example.com'],
          excludeDomains: ['bad.example'],
        ),
      );

      final uri = await requestSeen.future;
      expect(uri.path, '/search');
      expect(uri.queryParameters['format'], 'json');
      expect(uri.queryParameters['time_range'], 'week');
      expect(uri.queryParameters['q'], contains('site:example.com'));
      expect(uri.queryParameters['q'], contains('-site:bad.example'));
      expect(response.backend, WebSearchBackend.searxng);
      expect(response.results, hasLength(1));
      expect(response.results.single.title, 'Allowed result');
    });
  });

  group('ExaSearchClient', () {
    test('uses anonymous MCP without an API key header', () async {
      final requestSeen = Completer<HttpRequest>();
      final bodySeen = Completer<Map<String, dynamic>>();
      final server = await _serve((request) async {
        requestSeen.complete(request);
        bodySeen.complete(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'result': {
              'content': [
                {'type': 'text', 'text': 'Title: Exa result\nURL: https://example.com/exa\nText: Search snippet\n---'},
              ],
            },
          })}\n\n',
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final endpoint = Uri.parse(
        'http://${server.address.host}:${server.port}/mcp',
      );

      final response = await ExaSearchClient(Dio(), mcpEndpoint: endpoint)
          .searchMcp(
            const WebSearchRequest(query: 'latest Flutter', resultCount: 3),
          );

      final httpRequest = await requestSeen.future;
      final rpcBody = await bodySeen.future;
      expect(httpRequest.headers.value('x-api-key'), isNull);
      expect(httpRequest.uri.queryParameters['tools'], 'web_search_exa');
      expect(rpcBody['method'], 'tools/call');
      expect(response.backend, WebSearchBackend.exaMcp);
      expect(response.results.single.url, 'https://example.com/exa');
    });

    test('sends the key only to the direct Exa API endpoint', () async {
      final keySeen = Completer<String?>();
      final bodySeen = Completer<Map<String, dynamic>>();
      final server = await _serve((request) async {
        keySeen.complete(request.headers.value('x-api-key'));
        bodySeen.complete(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'results': [
              {
                'title': 'Direct result',
                'url': 'https://example.com/direct',
                'highlights': ['Bounded highlight'],
              },
              {
                'title': 'Wrong domain',
                'url': 'https://other.example/direct',
                'highlights': ['Must be removed locally'],
              },
              {
                'title': 'Unsafe scheme',
                'url': 'javascript://example.com/alert',
                'highlights': ['Must never be returned'],
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final apiBase = Uri.parse('http://${server.address.host}:${server.port}');

      final response = await ExaSearchClient(Dio(), apiBaseUrl: apiBase)
          .searchApi(
            const WebSearchRequest(
              query: 'direct search',
              resultCount: 5,
              includeDomains: ['example.com'],
              excludeDomains: ['other.example'],
            ),
            apiKey: 'exa-secret',
          );

      expect(await keySeen.future, 'exa-secret');
      final body = await bodySeen.future;
      expect(body['contents'], {'highlights': true});
      expect(response.backend, WebSearchBackend.exaApi);
      expect(response.results.single.snippet, 'Bounded highlight');
    });
  });

  test(
    'auto mode falls back from SearXNG to anonymous MCP, not paid API',
    () async {
      var keyLoads = 0;
      final server = await _serve((request) async {
        if (request.uri.path == '/search') {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          await request.response.close();
          return;
        }
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'result': {
              'content': [
                {'type': 'text', 'text': 'Title: Fallback\nURL: https://example.com/fallback\nText: MCP result'},
              ],
            },
          })}\n\n',
        );
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final root = Uri.parse('http://${server.address.host}:${server.port}');
      final service = WebAccessService(
        searxng: SearxngSearchClient(Dio()),
        exa: ExaSearchClient(Dio(), mcpEndpoint: root.resolve('/mcp')),
        reader: SafeWebReader(Dio()),
        loadExaApiKey: () async {
          keyLoads++;
          return 'paid-key';
        },
      );

      final response = await service.search(
        config: WebAccessConfig(
          enabled: true,
          mode: WebSearchMode.auto,
          searxngBaseUrl: root.toString(),
        ),
        request: const WebSearchRequest(query: 'fallback', resultCount: 1),
      );

      expect(response.backend, WebSearchBackend.exaMcp);
      expect(response.fallbackFrom, WebSearchBackend.searxng);
      expect(keyLoads, 0);
    },
  );

  group('WebAccessHttpTransport', () {
    test('checks and pins the resolved address at connect time', () async {
      var requests = 0;
      var lookups = 0;
      Future<List<InternetAddress>> resolve(String _) async {
        lookups++;
        return [
          lookups == 1
              ? InternetAddress('93.184.216.34')
              : InternetAddress.loopbackIPv4,
        ];
      }

      final server = await _serve((request) async {
        requests++;
        request.response.write('must not be reached');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final dio = createWebAccessDio(
        options: BaseOptions(connectTimeout: const Duration(seconds: 2)),
        protectPublicTargetsAtConnect: true,
        resolveAddresses: resolve,
      );
      addTearDown(() => dio.close(force: true));
      final reader = SafeWebReader(dio, resolveAddresses: resolve);

      await expectLater(
        reader.read('http://public.example.test:${server.port}/page'),
        throwsA(
          isA<WebAccessException>().having(
            (error) => error.kind,
            'kind',
            WebAccessErrorKind.blockedAddress,
          ),
        ),
      );
      expect(lookups, 2);
      expect(requests, 0);
    });

    test('uses the selected proxy instead of the global transport', () async {
      final hostSeen = Completer<String>();
      final proxy = await _serve((request) async {
        hostSeen.complete(request.headers.host);
        request.response.headers.contentType = ContentType.text;
        request.response.write('proxied');
        await request.response.close();
      });
      addTearDown(() => proxy.close(force: true));
      final dio = createWebAccessDio(
        options: BaseOptions(connectTimeout: const Duration(seconds: 2)),
        proxyAddress: '${proxy.address.host}:${proxy.port}',
      );
      addTearDown(() => dio.close(force: true));

      final response = await dio.get<String>(
        'http://unresolvable.invalid/page',
        options: Options(responseType: ResponseType.plain),
      );

      expect(response.data, 'proxied');
      expect(await hostSeen.future, 'unresolvable.invalid');
    });
  });

  group('SafeWebReader', () {
    test('blocks loopback targets by default', () async {
      final reader = SafeWebReader(Dio());

      await expectLater(
        reader.read('http://127.0.0.1/private'),
        throwsA(
          isA<WebAccessException>().having(
            (error) => error.kind,
            'kind',
            WebAccessErrorKind.blockedAddress,
          ),
        ),
      );
    });

    test('extracts HTML locally and enforces the character limit', () async {
      final server = await _serve((request) async {
        request.response.headers.contentType = ContentType.html;
        final paragraph = List.filled(900, 'A').join();
        request.response.write('''
          <html><head><title>Reader title</title></head><body>
          <nav>Navigation noise</nav>
          <article><h1>Heading</h1><p>$paragraph</p></article>
          </body></html>
        ''');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));
      final reader = SafeWebReader(Dio(), validateTarget: (_) async {});

      final page = await reader.read(
        'http://${server.address.host}:${server.port}/article',
        maxCharacters: 500,
      );

      expect(page.title, 'Reader title');
      expect(page.content, contains('Heading'));
      expect(page.content, isNot(contains('Navigation noise')));
      expect(page.content.runes.length, lessThanOrEqualTo(503));
      expect(page.truncated, isTrue);
    });

    test('trusted proxy skips DNS preflight only for hostnames', () async {
      final resolvedHosts = <String>[];
      Future<List<InternetAddress>> resolve(String hostname) async {
        resolvedHosts.add(hostname);
        return [
          InternetAddress('198.18.0.42'),
          InternetAddress('fdfe:dcba:9876::42'),
        ];
      }

      final dio = Dio()..httpClientAdapter = _StaticHtmlAdapter();
      final proxiedReader = SafeWebReader(
        dio,
        trustProxyForHostnames: true,
        resolveAddresses: resolve,
      );

      final page = await proxiedReader.read('https://docs.example.test/page');

      expect(page.content, contains('Proxy-compatible page'));
      expect(resolvedHosts, isEmpty);

      final directReader = SafeWebReader(dio, resolveAddresses: resolve);
      await expectLater(
        directReader.read('https://docs.example.test/page'),
        throwsA(
          isA<WebAccessException>().having(
            (error) => error.kind,
            'kind',
            WebAccessErrorKind.blockedAddress,
          ),
        ),
      );
      expect(resolvedHosts, ['docs.example.test']);
      await expectLater(
        proxiedReader.read('http://198.18.0.42/private'),
        throwsA(
          isA<WebAccessException>().having(
            (error) => error.kind,
            'kind',
            WebAccessErrorKind.blockedAddress,
          ),
        ),
      );
    });

    test(
      'trusted proxy validates a private redirect before fetching it',
      () async {
        final adapter = _PrivateRedirectAdapter();
        final dio = Dio()..httpClientAdapter = adapter;
        final reader = SafeWebReader(
          dio,
          trustProxyForHostnames: true,
          resolveAddresses: (_) => throw StateError('DNS must not be used'),
        );

        await expectLater(
          reader.read('https://public.example.test/start'),
          throwsA(
            isA<WebAccessException>().having(
              (error) => error.kind,
              'kind',
              WebAccessErrorKind.blockedAddress,
            ),
          ),
        );
        expect(adapter.requests, 1);
      },
    );
  });
}

class _StaticHtmlAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '<html><body><main><p>Proxy-compatible page</p></main></body></html>',
      HttpStatus.ok,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PrivateRedirectAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return ResponseBody.fromString(
      '',
      HttpStatus.found,
      headers: {
        HttpHeaders.locationHeader: ['http://127.0.0.1/private'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<HttpServer> _serve(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) => unawaited(handler(request)));
  return server;
}
