import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/proxy_settings_provider.dart';
import 'package:nai_launcher/core/network/system_proxy_http_overrides.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/settings/proxy_settings.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  late HttpOverrides? previousOverrides;
  late ProviderContainer container;
  late _RouteServer origin;
  late _RouteServer proxyA;
  late _RouteServer proxyB;
  final clients = <Dio>[];

  setUp(() async {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = SystemProxyHttpOverrides('DIRECT');
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.proxyEnabled] = false
      ..values[StorageKeys.proxyMode] = 'manual';
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    container.listen(proxySettingsNotifierProvider, (_, _) {});
    origin = await _RouteServer.start('origin');
    proxyA = await _RouteServer.start('proxy-a');
    proxyB = await _RouteServer.start('proxy-b');
  });

  tearDown(() async {
    for (final client in clients) {
      client.close(force: true);
    }
    clients.clear();
    container.dispose();
    await origin.close();
    await proxyA.close();
    await proxyB.close();
    HttpOverrides.global = previousOverrides;
  });

  ProxySettingsNotifier settings() =>
      container.read(proxySettingsNotifierProvider.notifier);

  Future<void> useProxy(_RouteServer proxy) =>
      settings().setManualProxy('127.0.0.1', proxy.server.port);

  Future<String> requestWithDio() async {
    final client = container.read(dioClientProvider);
    clients.add(client);
    final response = await client.get<String>(
      origin.url.toString(),
      options: Options(
        headers: {'Authorization': 'Bearer local-fixture'},
        receiveTimeout: const Duration(seconds: 2),
      ),
    );
    return response.data!;
  }

  test(
    'Dio immediately follows proxy enable, address and disable changes',
    () async {
      expect(await requestWithDio(), 'origin');
      await useProxy(proxyA);
      expect(await requestWithDio(), 'origin');

      await settings().setEnabled(true);
      expect(await requestWithDio(), 'proxy-a');

      await useProxy(proxyB);
      expect(await requestWithDio(), 'proxy-b');

      await settings().setEnabled(false);
      expect(await requestWithDio(), 'origin');

      await settings().setEnabled(true);
      expect(await requestWithDio(), 'proxy-b');

      await settings().clearManualProxy();
      expect(container.read(currentProxyAddressProvider), isNull);
      expect(await requestWithDio(), 'origin');
    },
  );

  test(
    'an already-created HttpClient also uses the updated proxy route',
    () async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      addTearDown(() => client.close(force: true));

      Future<String> request() async {
        final request = await client.getUrl(origin.url);
        final response = await request.close();
        return response.transform(utf8.decoder).join();
      }

      expect(await request(), 'origin');
      await useProxy(proxyA);
      await settings().setEnabled(true);
      expect(await request(), 'proxy-a');
      await useProxy(proxyB);
      expect(await request(), 'proxy-b');
      await settings().setEnabled(false);
      expect(await request(), 'origin');
    },
  );

  test('switching from automatic to manual applies the saved address', () async {
    await settings().setMode(ProxyMode.auto);
    await useProxy(proxyA);
    // No request is sent while automatic mode could resolve a real system proxy.
    await settings().setEnabled(true);
    await settings().setMode(ProxyMode.manual);

    expect(await requestWithDio(), 'proxy-a');
  });
}

class _RouteServer {
  final HttpServer server;
  final StreamSubscription<HttpRequest> subscription;

  _RouteServer(this.server, this.subscription);

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/user/subscription');

  static Future<_RouteServer> start(String route) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) async {
      request.response.headers.contentType = ContentType.text;
      request.response.write(route);
      await request.response.close();
    });
    return _RouteServer(server, subscription);
  }

  Future<void> close() async {
    await server.close(force: true);
    await subscription.cancel();
  }
}
