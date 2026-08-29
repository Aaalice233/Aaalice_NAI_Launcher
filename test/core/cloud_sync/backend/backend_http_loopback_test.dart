import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/backend_http.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';

void main() {
  test('HEAD ignores the declared representation length', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 4 * 1024 * 1024;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp().request(
      'HEAD',
      Uri.parse('http://127.0.0.1:${server.port}/large-resource'),
      maxResponseBytes: 0,
    );

    expect(response.statusCode, 200);
    expect(response.data, isEmpty);
  });

  test('204 response is treated as bodyless', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final response = await BackendHttp().request(
      'DELETE',
      Uri.parse('http://127.0.0.1:${server.port}/resource'),
      maxResponseBytes: 0,
    );

    expect(response.statusCode, HttpStatus.noContent);
    expect(response.data, isEmpty);
  });

  test('List<int> XML payload is sent as raw bytes instead of JSON', () async {
    final received = Completer<List<int>>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      received.complete(
        await request.fold<List<int>>([], (all, chunk) {
          all.addAll(chunk);
          return all;
        }),
      );
      request.response.statusCode = HttpStatus.multiStatus;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));
    final xml = utf8.encode('<d:propfind xmlns:d="DAV:"/>');

    await BackendHttp().request(
      'PROPFIND',
      Uri.parse('http://127.0.0.1:${server.port}/dav'),
      headers: const {'Content-Type': 'application/xml; charset=utf-8'},
      data: xml,
    );

    expect(await received.future, xml);
  });

  test('chunked response stops at cumulative hard limit', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.chunkedTransferEncoding = true;
      request.response.add([1, 2, 3]);
      await request.response.flush();
      request.response.add([4, 5, 6]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    await expectLater(
      BackendHttp().request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}/chunked'),
        maxResponseBytes: 4,
        tooLargeKind: CloudBackendErrorKind.quota,
      ),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.quota,
        ),
      ),
    );
  });

  test(
    'loopback cross-origin redirect never sends Authorization to target',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var targetRequests = 0;
      target.listen((request) async {
        targetRequests++;
        request.response.statusCode = 200;
        await request.response.close();
      });
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      source.listen((request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${target.port}/credential-target',
          );
        await request.response.close();
      });
      addTearDown(() async {
        await source.close(force: true);
        await target.close(force: true);
      });

      await expectLater(
        BackendHttp().request(
          'GET',
          Uri.parse('http://127.0.0.1:${source.port}/start'),
          headers: const {'Authorization': 'Bearer must-not-leak'},
        ),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.redirectRejected,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(targetRequests, 0);
    },
  );
}
