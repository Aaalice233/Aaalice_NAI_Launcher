import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_backend_config.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';

import 'backend_test_support.dart';

void main() {
  test(
    'capability probe verifies both CAS conditions and never uses LOCK',
    () async {
      final values = <String, Uint8List>{};
      final etags = <String, String>{};
      var revision = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(201);
        final path = request.uri.path;
        if (request.method == 'DELETE') {
          values.remove(path);
          etags.remove(path);
          return const TestHttpResponse(204);
        }
        if (request.method == 'PROPFIND') {
          return _davResponse([
            for (final key in values.keys.where((key) => key.endsWith('.json')))
              _davFile(key),
          ]);
        }
        if (request.method == 'GET') {
          final value = values[path];
          if (value == null) return const TestHttpResponse(404);
          return TestHttpResponse(200, latin1.decode(value), {
            'etag': [etags[path]!],
          });
        }
        if (request.method == 'HEAD') {
          if (!values.containsKey(path)) return const TestHttpResponse(404);
          return TestHttpResponse(200, '', {
            'etag': [etags[path]!],
          });
        }
        if (request.method == 'PUT') {
          final ifNoneMatch = request.headers['If-None-Match'];
          final ifMatch = request.headers['If-Match'];
          if (ifNoneMatch == '*' && values.containsKey(path)) {
            return const TestHttpResponse(412);
          }
          if (ifMatch != null && ifMatch != etags[path]) {
            return const TestHttpResponse(412);
          }
          values[path] = Uint8List.fromList(request.data as List<int>);
          etags[path] = '"v${++revision}"';
          return TestHttpResponse(201, '', {
            'etag': [etags[path]!],
          });
        }
        fail('Unexpected ${request.method} ${request.uri}');
      });
      final backend = _backend(adapter);

      final capability = await backend.testCapability();

      expect(capability.mode, CloudBackendMode.bidirectional);
      expect(
        adapter.requests.map((request) => request.method),
        isNot(contains('LOCK')),
      );
      expect(
        adapter.requests
            .where((request) => request.method == 'PUT')
            .map((request) => request.data),
        everyElement(isA<Uint8List>()),
      );
      expect(
        adapter.requests
            .where((request) => request.method == 'PUT')
            .map((request) => request.headers),
        contains(
          predicate(
            (headers) => headers is Map && headers['If-Match'] == '"v1"',
          ),
        ),
      );
      expect(
        adapter.requests
            .where((request) => request.method == 'MKCOL')
            .map((request) => request.headers['Content-Length']),
        everyElement('0'),
      );
    },
  );

  test('failed If-Match semantics downgrade to manual backup only', () async {
    final values = <String, Uint8List>{};
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'DELETE') {
        values.remove(request.uri.path);
        return const TestHttpResponse(204);
      }
      if (request.method == 'GET') {
        final value = values[request.uri.path];
        if (value == null) return const TestHttpResponse(404);
        return TestHttpResponse(200, latin1.decode(value), const {
          'etag': ['"v2"'],
        });
      }
      if (request.method == 'HEAD') {
        return values.containsKey(request.uri.path)
            ? const TestHttpResponse(200, '', {
                'etag': ['"v1"'],
              })
            : const TestHttpResponse(404);
      }
      if (request.method == 'PROPFIND') {
        return _davResponse([
          for (final path in values.keys.where(
            (path) => path.endsWith('.json'),
          ))
            _davFile(path),
        ]);
      }
      if (request.method == 'PUT') {
        values[request.uri.path] = Uint8List.fromList(
          request.data as List<int>,
        );
        return const TestHttpResponse(201, '', {
          'etag': ['"v1"'],
        });
      }
      return const TestHttpResponse(200, '', {
        'etag': ['"v1"'],
      });
    });

    final result = await _backend(adapter).testCapability();

    expect(result.mode, CloudBackendMode.manualBackupOnly);
    expect(result.message, contains('If-Match'));
  });

  test(
    'immutable manifest uses If-None-Match and accepts identical retry',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{"snapshot":1}'));
      final hash = sha256.convert(bytes).toString();
      var putCount = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(405);
        if (request.method == 'PUT') {
          putCount++;
          return const TestHttpResponse(412);
        }
        if (request.method == 'GET') {
          return TestHttpResponse(200, utf8.decode(bytes), {
            'etag': ['"same"'],
          });
        }
        fail('Unexpected request');
      });

      final result = await _backend(
        adapter,
      ).putSnapshotManifest('2026-01-01T00-00-00Z', bytes, sha256: hash);

      expect(result.revision, '"same"');
      expect(putCount, 1);
      final put = adapter.requests.firstWhere(
        (request) => request.method == 'PUT',
      );
      expect(put.headers['If-None-Match'], '*');
      expect(put.uri.path, endsWith('/snapshots/2026-01-01T00-00-00Z.json'));
    },
  );

  test('falls back to Depth-0 PROPFIND when HEAD omits ETag', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'PUT') return const TestHttpResponse(201);
      if (request.method == 'HEAD') return const TestHttpResponse(200);
      if (request.method == 'PROPFIND') {
        return _davResponse([
          _davFile('/sync/aaalice-sync/KEY.json', etagValue: 'nutstore-v1'),
        ]);
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });

    final result = await _backend(
      adapter,
    ).commitKeyEnvelope(Uint8List.fromList([1, 2, 3]), expectedRevision: null);

    expect(result.revision, '"nutstore-v1"');
    expect(
      adapter.requests
          .firstWhere((request) => request.method == 'PROPFIND')
          .headers['Depth'],
      '0',
    );
  });

  test('reuses recently verified collections across object uploads', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(405);
      if (request.method == 'PUT') {
        return const TestHttpResponse(201, '', {
          'etag': ['"object"'],
        });
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });
    final backend = _backend(adapter);
    final bytes = Uint8List.fromList([1]);
    final hash = sha256.convert(bytes).toString();

    await backend.putObject('object-a', bytes, sha256: hash);
    await backend.putObject('object-b', bytes, sha256: hash);

    expect(
      adapter.requests.where((request) => request.method == 'MKCOL'),
      hasLength(2),
    );
    expect(
      adapter.requests
          .where((request) => request.method == 'MKCOL')
          .map((request) => request.headers['Content-Length']),
      everyElement('0'),
    );
  });

  test('PROPFIND parses DAV XML and limits recent snapshot ids', () async {
    final adapter = RecordingAdapter(
      (request) => const TestHttpResponse(
        207,
        '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
        '<d:response><d:href>/sync/snapshots/2025.json</d:href></d:response>'
        '<d:response><d:href>/sync/snapshots/2026.json</d:href></d:response>'
        '</d:multistatus>',
      ),
    );

    expect(await _backend(adapter).listSnapshotIds(limit: 1), ['2026']);
    expect(adapter.requests.single.method, 'PROPFIND');
    expect(adapter.requests.single.headers['Depth'], '1');
  });

  test('maps quota response without exposing response secrets', () async {
    const secret = 'malicious-password-echo';
    final adapter = RecordingAdapter(
      (_) => const TestHttpResponse(
        507,
        '<html>Authorization: Basic $secret</html>',
      ),
    );

    await expectLater(
      _backend(adapter).deleteNamespace(),
      throwsA(
        isA<CloudBackendException>()
            .having((error) => error.kind, 'kind', CloudBackendErrorKind.quota)
            .having(
              (error) => error.message,
              'message',
              allOf(isNot(contains(secret)), isNot(contains('Authorization'))),
            ),
      ),
    );
  });

  test(
    'cross-host redirect is rejected before Authorization can leak',
    () async {
      final adapter = RecordingAdapter(
        (_) => const TestHttpResponse(302, '', {
          'location': ['https://evil.example/steal'],
        }),
      );

      await expectLater(
        _backend(adapter).readHead(),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.redirectRejected,
          ),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.uri.host, 'dav.example');
    },
  );

  test('requires HTTPS unless insecure HTTP is explicitly allowed', () {
    WebDavCloudSyncBackend create({bool allowInsecureHttp = false}) =>
        WebDavCloudSyncBackend(
          baseUri: Uri.parse('http://127.0.0.1:8080/dav'),
          username: 'local',
          password: 'secret',
          allowInsecureHttp: allowInsecureHttp,
        );

    expect(create, throwsArgumentError);
    expect(() => create(allowInsecureHttp: true), returnsNormally);
  });

  test('insecure HTTP opt-in survives config serialization', () {
    final config = WebDavBackendConfig(
      baseUri: Uri.parse('http://localhost:8080/dav'),
      namespace: 'local/sync',
      allowInsecureHttp: true,
    );

    final restored = WebDavBackendConfig.fromJson(config.toJson());

    expect(restored.allowInsecureHttp, isTrue);
    expect(restored.baseUri, config.baseUri);
    expect(restored.namespace, 'local/sync');
    expect(
      () => WebDavCloudSyncBackend.fromConfig(
        config: restored,
        username: 'local',
        password: 'secret',
      ),
      returnsNormally,
    );
  });

  test(
    'namespace cleanup accepts collection hrefs without trailing slash',
    () async {
      final adapter = RecordingAdapter((request) {
        if (request.method != 'PROPFIND') {
          fail('Unexpected ${request.method} ${request.uri}');
        }
        if (request.uri.path.endsWith('/aaalice-sync/')) {
          return _davResponse([
            _davFile('/sync/aaalice-sync', collection: true, etag: false),
            _davFile(
              '/sync/aaalice-sync/objects',
              collection: true,
              etag: false,
            ),
            _davFile(
              '/sync/aaalice-sync/snapshots',
              collection: true,
              etag: false,
            ),
          ]);
        }
        return _davResponse([
          _davFile(
            request.uri.path.replaceFirst(RegExp(r'/$'), ''),
            collection: true,
            etag: false,
          ),
        ]);
      });

      await _backend(adapter).deleteNamespace();

      expect(
        adapter.requests.map((request) => request.method),
        everyElement('PROPFIND'),
      );
    },
  );

  group('unreferenced object maintenance', () {
    test(
      'protects manifests and fresh objects, deleting old orphan with ETag',
      () async {
        final deleted = <RequestOptions>[];
        final adapter = RecordingAdapter((request) {
          if (request.method == 'PROPFIND' &&
              request.uri.path.endsWith('/snapshots/')) {
            return _davResponse([
              _davFile('/sync/aaalice-sync/snapshots/live.json'),
            ]);
          }
          if (request.method == 'PROPFIND') {
            return _davResponse([
              _davFile('/sync/aaalice-sync/objects/live.0', old: true),
              _davFile('/sync/aaalice-sync/objects/head-only.0', old: true),
              _davFile('/sync/aaalice-sync/objects/fresh.0'),
              _davFile('/sync/aaalice-sync/objects/orphan.0', old: true),
            ]);
          }
          if (request.method == 'GET') {
            return TestHttpResponse(
              200,
              utf8.decode(
                SnapshotHead(
                  snapshotId: 'head-only',
                  manifestSha256: '0' * 64,
                  updatedAt: DateTime.utc(2026),
                ).encode(),
              ),
            );
          }
          if (request.method == 'DELETE') {
            deleted.add(request);
            return const TestHttpResponse(204);
          }
          fail('Unexpected ${request.method}');
        });

        final result = await _backend(adapter).cleanUnreferencedObjects();

        expect(result.scanned, 4);
        expect(result.deleted, 1);
        expect(result.skipped, 3);
        expect(deleted.single.uri.path, endsWith('/objects/orphan.0'));
        expect(deleted.single.headers['If-Match'], '"orphan.0"');
      },
    );

    test('second manifest scan closes concurrent upload race', () async {
      var manifestScans = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'PROPFIND' &&
            request.uri.path.endsWith('/snapshots/')) {
          manifestScans++;
          return _davResponse(
            manifestScans == 1
                ? const []
                : [_davFile('/sync/aaalice-sync/snapshots/racing.json')],
          );
        }
        if (request.method == 'PROPFIND') {
          return _davResponse([
            _davFile('/sync/aaalice-sync/objects/racing.0', old: true),
          ]);
        }
        if (request.method == 'GET') return const TestHttpResponse(404);
        fail('DELETE must not race a new manifest');
      });

      final result = await _backend(adapter).cleanUnreferencedObjects();

      expect(manifestScans, 2);
      expect(result.deleted, 0);
      expect(result.skipped, 1);
    });

    test('404 and 412 deletes are safe skips', () async {
      var deletes = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'PROPFIND' &&
            request.uri.path.endsWith('/snapshots/')) {
          return _davResponse(const []);
        }
        if (request.method == 'PROPFIND') {
          return _davResponse([
            _davFile('/sync/aaalice-sync/objects/gone.0', old: true),
            _davFile('/sync/aaalice-sync/objects/changed.0', old: true),
          ]);
        }
        if (request.method == 'GET') return const TestHttpResponse(404);
        if (request.method == 'DELETE') {
          deletes++;
          return TestHttpResponse(deletes == 1 ? 404 : 412);
        }
        fail('Unexpected request');
      });

      final result = await _backend(adapter).cleanUnreferencedObjects();

      expect(result.deleted, 0);
      expect(result.skipped, 2);
      expect(result.warnings, isEmpty);
    });

    test(
      'rejects unsafe DAV entries and preserves incomplete metadata',
      () async {
        final adapter = RecordingAdapter((request) {
          if (request.method == 'PROPFIND' &&
              request.uri.path.endsWith('/snapshots/')) {
            return _davResponse(const []);
          }
          if (request.method == 'PROPFIND') {
            return _davResponse([
              _davFile(
                '/sync/aaalice-sync/objects/no-etag.0',
                old: true,
                etag: false,
              ),
              _davFile('/sync/aaalice-sync/objects/no-time.0', modified: false),
              _davFile('/sync/aaalice-sync/objects/folder.0', collection: true),
              _davFile('/sync/aaalice-sync/objects/non200.0', ok: false),
              _davFile(
                'https://evil.example/sync/aaalice-sync/objects/escape.0',
              ),
              _davFile('/sync/aaalice-sync/objects/nested/escape.0'),
            ]);
          }
          if (request.method == 'GET') {
            return TestHttpResponse(
              200,
              utf8.decode(
                SnapshotHead(
                  snapshotId: 'head-only',
                  manifestSha256: '0' * 64,
                  updatedAt: DateTime.utc(2026),
                ).encode(),
              ),
            );
          }
          fail('No object is safe to delete');
        });

        final result = await _backend(adapter).cleanUnreferencedObjects();

        expect(result.deleted, 0);
        expect(result.skipped, 6);
        expect(
          result.warnings.join(' '),
          allOf(contains('no-etag.0'), contains('no-time.0')),
        );
      },
    );

    test(
      'missing server Date and 500 errors return redacted warnings',
      () async {
        const secret = 'password-echo';
        var failWith500 = false;
        final adapter = RecordingAdapter((request) {
          if (failWith500) {
            return const TestHttpResponse(500, '<html>$secret</html>');
          }
          if (request.uri.path.endsWith('/snapshots/')) {
            return _davResponse(const []);
          }
          return _davResponse([
            _davFile('/sync/aaalice-sync/objects/orphan.0', old: true),
          ], includeDate: false);
        });
        final backend = _backend(adapter);

        final noDate = await backend.cleanUnreferencedObjects();
        expect(noDate.deleted, 0);
        expect(noDate.warnings.join(' '), contains('Date'));
        failWith500 = true;
        final failed = await backend.cleanUnreferencedObjects();
        expect(failed.warnings.join(' '), isNot(contains(secret)));
        expect(failed.warnings.join(' '), contains('HTTP 500'));
      },
    );
  });
}

TestHttpResponse _davResponse(
  List<String> responses, {
  bool includeDate = true,
}) => TestHttpResponse(
  207,
  '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">${responses.join()}</d:multistatus>',
  includeDate
      ? const {
          'date': ['Thu, 12 Mar 2026 12:00:00 GMT'],
        }
      : const {},
);

String _davFile(
  String href, {
  bool old = false,
  bool etag = true,
  bool modified = true,
  bool collection = false,
  bool ok = true,
  String? etagValue,
}) {
  final name = Uri.parse(href).pathSegments.last;
  return '<d:response><d:href>$href</d:href><d:propstat>'
      '<d:status>HTTP/1.1 ${ok ? '200 OK' : '404 Not Found'}</d:status><d:prop>'
      '${etag ? '<d:getetag>"${etagValue ?? name}"</d:getetag>' : ''}'
      '${modified ? '<d:getlastmodified>${old ? 'Sun, 01 Mar 2026 12:00:00 GMT' : 'Tue, 10 Mar 2026 12:00:00 GMT'}</d:getlastmodified>' : ''}'
      '<d:getcontentlength>10</d:getcontentlength>'
      '<d:resourcetype>${collection ? '<d:collection/>' : ''}</d:resourcetype>'
      '</d:prop></d:propstat></d:response>';
}

WebDavCloudSyncBackend _backend(RecordingAdapter adapter) =>
    WebDavCloudSyncBackend(
      baseUri: Uri.parse('https://dav.example/sync/'),
      username: 'alice',
      password: 'secret',
      dio: Dio()..httpClientAdapter = adapter,
    );
