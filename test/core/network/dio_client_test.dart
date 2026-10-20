import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/proxy_settings_provider.dart';
import 'package:nai_launcher/core/network/system_proxy_http_overrides.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  final proxyAddress = StateProvider<String?>((ref) => null);
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

  test('代理地址变化会重建 HTTP/1.1 客户端', () {
    final first = readClient();

    container.read(proxyAddress.notifier).state = '127.0.0.1:7890';
    final second = readClient();

    expect(second, isNot(same(first)));
    expect(second.httpClientAdapter, isA<IOHttpClientAdapter>());
  });
}
