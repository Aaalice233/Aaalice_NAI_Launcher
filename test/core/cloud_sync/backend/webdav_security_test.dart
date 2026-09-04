import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_cloud_sync_backend.dart';

import 'backend_test_support.dart';

void main() {
  test('rejects absolute, empty, dot, and traversal namespaces', () {
    for (final namespace in [
      '/absolute',
      'empty//segment',
      'dot/./segment',
      'escape/../segment',
      r'C:\absolute',
    ]) {
      expect(
        () => WebDavCloudSyncBackend(
          baseUri: Uri.parse('https://dav.example/'),
          username: 'alice',
          password: 'secret',
          namespace: namespace,
        ),
        throwsArgumentError,
        reason: namespace,
      );
    }
  });

  test('no-ETag manual mode completes repeated verified backups', () async {
    final values = <String, Uint8List>{};
    final adapter = RecordingAdapter((request) {
      final path = request.uri.path;
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'PUT') {
        values[path] = Uint8List.fromList(request.data as List<int>);
        return const TestHttpResponse(201);
      }
      if (request.method == 'GET') {
        final value = values[path];
        return value == null
            ? const TestHttpResponse(404)
            : TestHttpResponse(200, latin1.decode(value));
      }
      if (request.method == 'HEAD') {
        return values.containsKey(path)
            ? const TestHttpResponse(200)
            : const TestHttpResponse(404);
      }
      if (request.method == 'PROPFIND') {
        return _davResponse([
          for (final key in values.keys.where((key) => key.endsWith('.json')))
            _davFile(key),
        ]);
      }
      if (request.method == 'DELETE') {
        values.remove(path);
        return const TestHttpResponse(204);
      }
      fail('Unexpected ${request.method} $path');
    });
    final backend = _backend(adapter);

    final capability = await backend.testCapability();
    expect(capability.mode, CloudBackendMode.manualBackupOnly);
    expect(capability.warnings, [CloudBackendWarning.webDavWeakCas]);
    expect(backend.maxConcurrentObjectUploads, 1);
    final propfindsBeforeInventory = adapter.requests
        .where((request) => request.method == 'PROPFIND')
        .length;
    expect(await backend.findExistingObjects(const {'candidate': 1}), isEmpty);
    expect(
      adapter.requests.where((request) => request.method == 'PROPFIND'),
      hasLength(propfindsBeforeInventory),
    );

    for (final id in ['first', 'second']) {
      final object = Uint8List.fromList(utf8.encode('object-$id'));
      final manifest = Uint8List.fromList(utf8.encode('manifest-$id'));
      await backend.putObject(
        '$id.0',
        object,
        sha256: sha256.convert(object).toString(),
      );
      await backend.putSnapshotManifest(
        id,
        manifest,
        sha256: sha256.convert(manifest).toString(),
      );
      await backend.commitHead(
        Uint8List.fromList(utf8.encode('head-$id')),
        expectedRevision: id == 'first' ? null : 'ignored-in-manual-mode',
      );
      expect(utf8.decode((await backend.readHead())!.bytes), 'head-$id');
    }
  });

  test('deleteNamespace deletes only verified files with If-Match', () async {
    final deleted = <RequestOptions>[];
    final removed = <String>{};
    final adapter = RecordingAdapter((request) {
      if (request.method == 'PROPFIND') {
        if (request.uri.path.endsWith('/objects/')) {
          const path = '/sync/aaalice-sync/objects/item.0';
          return _davResponse(removed.contains(path) ? [] : [_davFile(path)]);
        }
        if (request.uri.path.endsWith('/snapshots/')) {
          const path = '/sync/aaalice-sync/snapshots/item.json';
          return _davResponse(removed.contains(path) ? [] : [_davFile(path)]);
        }
        const head = '/sync/aaalice-sync/HEAD.json';
        return _davResponse([
          if (!removed.contains(head)) _davFile(head),
          _davFile('/sync/aaalice-sync/objects/', collection: true),
          _davFile('/sync/aaalice-sync/snapshots/', collection: true),
        ]);
      }
      if (request.method == 'DELETE') {
        deleted.add(request);
        removed.add(request.uri.path);
        return const TestHttpResponse(204);
      }
      fail('Unexpected ${request.method}');
    });

    await _backend(adapter).deleteNamespace();

    expect(deleted, hasLength(3));
    expect(
      deleted.every(
        (request) =>
            request.uri.path != '/sync/aaalice-sync/' &&
            request.headers['If-Match'] != null,
      ),
      isTrue,
    );
  });

  test('deleteNamespace preserves data when inventory ETag changes', () async {
    var rootScans = 0;
    final adapter = RecordingAdapter((request) {
      if (request.method == 'PROPFIND') {
        if (request.uri.path.endsWith('/aaalice-sync/')) {
          rootScans++;
          return _davResponse([
            _davFile(
              '/sync/aaalice-sync/HEAD.json',
              etagValue: rootScans == 1 ? 'old' : 'new',
            ),
          ]);
        }
        return _davResponse(const []);
      }
      fail('Concurrent data must not be deleted');
    });

    await expectLater(
      _backend(adapter).deleteNamespace(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );
  });

  test('rejects oversized WebDAV GET from Content-Length', () async {
    final adapter = RecordingAdapter(
      (_) => const TestHttpResponse(200, '', {
        'content-length': ['65537'],
        'etag': ['"head"'],
      }),
    );

    await expectLater(
      _backend(adapter).readHead(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.invalidResponse,
        ),
      ),
    );
  });
}

TestHttpResponse _davResponse(List<String> responses) => TestHttpResponse(
  207,
  '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${responses.join()}</d:multistatus>',
);

String _davFile(String href, {bool collection = false, String? etagValue}) {
  final name = Uri.parse(href).pathSegments.last;
  return '<d:response><d:href>$href</d:href><d:propstat>'
      '<d:status>HTTP/1.1 200 OK</d:status><d:prop>'
      '<d:getetag>"${etagValue ?? name}"</d:getetag>'
      '<d:resourcetype>${collection ? '<d:collection/>' : ''}</d:resourcetype>'
      '</d:prop></d:propstat></d:response>';
}

WebDavCloudSyncBackend _backend(RecordingAdapter adapter) =>
    WebDavCloudSyncBackend(
      baseUri: Uri.parse('https://dav.example/sync/'),
      username: 'alice',
      password: 'secret',
      namespace: 'aaalice-sync',
      dio: Dio()..httpClientAdapter = adapter,
    );
