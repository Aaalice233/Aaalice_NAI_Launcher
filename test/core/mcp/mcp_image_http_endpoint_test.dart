import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_image_http_endpoint.dart';

void main() {
  late HttpServer server;
  late HttpClient client;
  late McpImageHttpEndpoint endpoint;
  late DateTime now;
  late bool strip;

  McpImageDisplayLink publish({bool stripped = true, int size = 4}) =>
      endpoint.publish(
        Uint8List(size)..fillRange(0, size, 42),
        mimeType: 'image/png',
        metadataStripped: stripped,
      )!;

  Future<HttpClientResponse> request(
    Uri uri, {
    String method = 'GET',
    String? origin,
    String? host,
  }) async {
    final outgoing = await client.openUrl(method, uri);
    if (origin != null) outgoing.headers.set('Origin', origin);
    if (host != null) outgoing.headers.set('Host', host);
    return outgoing.close();
  }

  Future<void> expectStatus(
    Uri uri,
    int status, {
    String method = 'GET',
    String? origin,
    String? host,
  }) async {
    final response = await request(
      uri,
      method: method,
      origin: origin,
      host: host,
    );
    expect(response.statusCode, status);
    await response.drain<void>();
  }

  setUp(() async {
    now = DateTime.utc(2026, 9, 14);
    strip = false;
    endpoint = McpImageHttpEndpoint(
      clock: () => now,
      requiresStrippedMetadata: () => strip,
      maxEntries: 2,
      maxBytes: 12,
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint.start(Uri.parse('http://127.0.0.1:${server.port}/mcp'));
    server.listen(endpoint.handle);
    client = HttpClient()..findProxy = (_) => 'DIRECT';
  });

  tearDown(() async {
    client.close(force: true);
    endpoint.stop();
    await server.close(force: true);
  });

  test(
    'serves immutable bytes under an unguessable image-only capability',
    () async {
      final original = Uint8List.fromList([1, 2, 3, 4]);
      final link = endpoint.publish(
        original,
        mimeType: 'image/png',
        metadataStripped: true,
      )!;
      original[0] = 99;
      expect(
        link.url.path,
        matches(RegExp(r'^/mcp/images/[A-Za-z0-9_-]{43}\.png$')),
      );
      expect(link.expiresAt, now.add(const Duration(hours: 1)));
      final response = await request(link.url);
      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.contentType?.mimeType, 'image/png');
      expect(response.headers.value('cache-control'), contains('no-store'));
      expect(response.headers.value('x-content-type-options'), 'nosniff');
      expect(response.headers.value('referrer-policy'), 'no-referrer');
      expect(
        response.headers.value('content-disposition'),
        'inline; filename="image.png"',
      );
      expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), [
        1,
        2,
        3,
        4,
      ]);
    },
  );

  test('HEAD returns image headers without a body', () async {
    final response = await request(publish().url, method: 'HEAD');
    expect(response.contentLength, 4);
    expect(await response.fold<List<int>>([], (a, b) => a..addAll(b)), isEmpty);
  });

  test('GET from an Electron opaque origin supports image fetching', () async {
    final response = await request(publish().url, origin: 'null');
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value('access-control-allow-origin'), 'null');
    expect(response.headers.value('access-control-allow-credentials'), isNull);
    await response.drain<void>();
  });

  test(
    'remote origins, rebound hosts and unsupported methods are rejected',
    () async {
      final link = publish();
      await expectStatus(link.url, 403, origin: 'https://untrusted.example');
      await expectStatus(
        link.url,
        403,
        host: 'untrusted.example:${server.port}',
      );
      await expectStatus(link.url, 403, host: '127.0.0.1:1');
      await expectStatus(link.url, 405, method: 'POST');
      await expectStatus(link.url, 405, method: 'DELETE');
    },
  );

  test(
    'neither query tokens, changed keys nor source paths grant access',
    () async {
      final link = publish();
      for (final uri in [
        link.url.replace(path: '${McpImageHttpEndpoint.pathPrefix}missing.png'),
        link.url.replace(
          path: '${McpImageHttpEndpoint.pathPrefix}C:/private/original.png',
        ),
        link.url.replace(
          path: '${McpImageHttpEndpoint.pathPrefix}%2e%2e/private.png',
        ),
        link.url.replace(query: 'token=master-token'),
      ]) {
        await expectStatus(uri, 404);
      }
    },
  );

  test(
    'expiry and shutdown revoke capabilities without wall-clock waits',
    () async {
      final link = publish();
      now = link.expiresAt;
      await expectStatus(link.url, 404);
      final fresh = publish();
      endpoint.stop();
      expect(
        endpoint.publish(
          Uint8List(1),
          mimeType: 'image/png',
          metadataStripped: true,
        ),
        isNull,
      );
      endpoint.start(link.url.replace(path: '/mcp'));
      await expectStatus(fresh.url, 404);
    },
  );

  test(
    'stricter privacy revokes raw links but retains sanitized links',
    () async {
      final raw = publish(stripped: false);
      final safe = publish();
      strip = true;
      await expectStatus(raw.url, 404);
      await expectStatus(safe.url, 200);
      expect(
        endpoint.publish(
          Uint8List(1),
          mimeType: 'image/png',
          metadataStripped: false,
        ),
        isNull,
      );
      strip = false;
      await expectStatus(raw.url, 404);
    },
  );

  test('cache is bounded by both entry count and bytes', () async {
    final first = publish();
    final second = publish();
    final third = publish();
    await expectStatus(first.url, 404);
    await expectStatus(second.url, 200);
    final large = publish(size: 10);
    await expectStatus(second.url, 404);
    await expectStatus(third.url, 404);
    await expectStatus(large.url, 200);
    expect(
      endpoint.publish(
        Uint8List(13),
        mimeType: 'image/png',
        metadataStripped: true,
      ),
      isNull,
    );
  });

  test('rejects active content and empty payloads', () {
    for (final mime in [
      'image/svg+xml',
      'text/html',
      'application/octet-stream',
    ]) {
      expect(
        endpoint.publish(Uint8List(4), mimeType: mime, metadataStripped: true),
        isNull,
      );
    }
    expect(
      endpoint.publish(
        Uint8List(0),
        mimeType: 'image/png',
        metadataStripped: true,
      ),
      isNull,
    );
  });
}
