import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_backend_config.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';

import 'backend_test_support.dart';
import 'cloud_sync_backend_contract.dart';

void main() {
  runCloudSyncBackendContract(
    provider: 'WebDAV',
    createBackend: _statefulBackend,
    expectations: const CloudSyncBackendContractExpectations(
      mode: CloudBackendMode.bidirectional,
    ),
  );

  test('default backend reads only the isolated v3 namespace', () async {
    final adapter = RecordingAdapter((request) {
      expect(request.uri.path, '/sync/aaalice-sync-v3/HEAD.json');
      return const TestHttpResponse(404);
    });
    final backend = WebDavCloudSyncBackend(
      baseUri: Uri.parse('https://dav.example/sync/'),
      username: 'alice',
      password: 'secret',
      dio: Dio()..httpClientAdapter = adapter,
    );

    expect(await backend.readHead(), isNull);
    expect(
      adapter.requests.any(
        (request) => request.uri.path.startsWith('/sync/aaalice-sync/'),
      ),
      isFalse,
    );
  });

  test('records every redirected and retried HTTP attempt', () async {
    var redirectedAttempts = 0;
    late int requestBytes;
    final finalResponse = _davResponse([_davFile('/sync/', collection: true)]);
    final adapter = RecordingAdapter((request) {
      requestBytes = (request.data as Uint8List).length;
      if (request.uri.path == '/sync/') {
        return const TestHttpResponse(307, '', {
          'location': ['/sync/redirected/'],
        });
      }
      redirectedAttempts++;
      return redirectedAttempts == 1
          ? const TestHttpResponse(503, 'retry')
          : finalResponse;
    });
    final logs = <String>[];

    await runZoned(
      () => CloudSyncTelemetry.trace(
        'webdav-test',
        _backend(adapter).validateConnectionReadOnly,
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logs.add(line),
      ),
    );

    final metrics = logs.singleWhere(
      (line) => line.contains('operation=webdav-test'),
    );
    expect(adapter.requests, hasLength(4));
    expect(metrics, contains('requests=4'));
    expect(
      metrics,
      contains(
        'bytesRead=${utf8.encode('retry').length + utf8.encode(finalResponse.body as String).length}',
      ),
    );
    expect(metrics, contains('bytesWritten=${requestBytes * 4}'));
  });

  test('read-only connection validation never mutates WebDAV', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'PROPFIND') {
        expect(request.uri.path, '/sync/');
        expect(request.headers['Depth'], '0');
        return _davResponse([_davFile('/sync/', collection: true)]);
      }
      if (request.method == 'GET' && request.uri.path.endsWith('/HEAD.json')) {
        return const TestHttpResponse(200, '{"snapshotId":"existing"}');
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });
    final backend = _backend(adapter);

    await backend.validateConnectionReadOnly();
    final head = await backend.readHead();

    expect(head, isNotNull);
    expect(adapter.requests.map((request) => request.method), [
      'PROPFIND',
      'GET',
    ]);
    expect(
      adapter.requests.map((request) => request.method),
      isNot(contains(anyOf('MKCOL', 'PUT', 'DELETE'))),
    );
  });

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
          final body = utf8.decode(request.data! as Uint8List);
          expect(body, isNot(contains('allprop')));
          if (request.headers['Depth'] == '1' &&
              request.uri.path.endsWith('/snapshots/')) {
            expect(body, contains('<d:prop><d:resourcetype/></d:prop>'));
            expect(body, isNot(contains('getetag')));
          }
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
    final etags = <String, String>{};
    var revision = 0;
    final adapter = RecordingAdapter((request) {
      final path = request.uri.path;
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'DELETE') {
        if (request.headers['If-Match'] != null &&
            request.headers['If-Match'] != etags[path]) {
          return const TestHttpResponse(412);
        }
        values.remove(path);
        etags.remove(path);
        return const TestHttpResponse(204);
      }
      if (request.method == 'GET') {
        final value = values[path];
        if (value == null) return const TestHttpResponse(404);
        return TestHttpResponse(200, latin1.decode(value), {
          'etag': [etags[path]!],
        });
      }
      if (request.method == 'HEAD') {
        return values.containsKey(path)
            ? TestHttpResponse(200, '', {
                'etag': [etags[path]!],
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
        values[path] = Uint8List.fromList(request.data as List<int>);
        final etag = '"v${++revision}"';
        etags[path] = etag;
        return TestHttpResponse(201, '', {
          'etag': [etag],
        });
      }
      return const TestHttpResponse(200);
    });

    final result = await _backend(adapter).testCapability();

    expect(result.mode, CloudBackendMode.manualBackupOnly);
    expect(result.message, contains('If-Match'));
    expect(values, isEmpty);
  });

  test('manual immutable PUT never replays an ambiguous write', () async {
    var putAttempts = 0;
    final adapter = RecordingAdapter((request) {
      if (request.method == 'PROPFIND') {
        return _davResponse([_davFile(request.uri.path, collection: true)]);
      }
      if (request.method == 'MKCOL') return const TestHttpResponse(405);
      if (request.method == 'GET') return const TestHttpResponse(404);
      if (request.method == 'PUT') {
        putAttempts++;
        return const TestHttpResponse(503);
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });
    final backend = _backend(adapter);
    await backend.validateConnectionReadOnly();
    final bytes = Uint8List.fromList([1, 2, 3]);

    await expectLater(
      backend.putObject(
        sha256.convert(bytes).toString(),
        bytes,
        sha256: sha256.convert(bytes).toString(),
      ),
      throwsA(isA<CloudBackendException>()),
    );

    expect(putAttempts, 1);
  });

  test(
    'immutable write rejects a mismatched declared hash before IO',
    () async {
      final adapter = RecordingAdapter((request) {
        fail('Unexpected ${request.method} ${request.uri}');
      });
      final bytes = Uint8List.fromList([1, 2, 3]);

      await expectLater(
        _backend(adapter).putObject(
          'mismatched',
          bytes,
          sha256: sha256.convert([4, 5, 6]).toString(),
        ),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'immutable manifest uses If-None-Match and accepts identical retry',
    () async {
      final bytes = Uint8List.fromList(utf8.encode('{"snapshot":1}'));
      final hash = sha256.convert(bytes).toString();
      var putCount = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(405);
        if (request.method == 'PROPFIND') {
          return _davResponse([_davFile(request.uri.path, collection: true)]);
        }
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

  test('missing PUT ETag falls back to one strong ETag read', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'PUT') return const TestHttpResponse(201);
      if (request.method == 'HEAD') {
        return const TestHttpResponse(200, '', {
          'etag': ['"verified"'],
        });
      }
      fail('Unexpected ${request.method}');
    });
    final bytes = Uint8List.fromList([1, 2, 3]);
    final hash = sha256.convert(bytes).toString();

    final result = await _backend(
      adapter,
    ).putObject('no-response-etag', bytes, sha256: hash);

    expect(result.revision, '"verified"');
    expect(adapter.requests.map((request) => request.method), [
      'MKCOL',
      'MKCOL',
      'PUT',
      'HEAD',
    ]);
  });

  test('falls back to Depth-0 PROPFIND when HEAD omits ETag', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'PUT') return const TestHttpResponse(201);
      if (request.method == 'HEAD') return const TestHttpResponse(200);
      if (request.method == 'PROPFIND') {
        final body = utf8.decode(request.data! as Uint8List);
        expect(body, contains('<d:prop><d:getetag/></d:prop>'));
        expect(body, isNot(contains('allprop')));
        expect(body, isNot(contains('resourcetype')));
        return _davResponse([
          _davFile('/sync/aaalice-sync/HEAD.json', etagValue: 'nutstore-v1'),
        ]);
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });

    final result = await _backend(
      adapter,
    ).commitHead(Uint8List.fromList([1, 2, 3]), expectedRevision: null);

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
      if (request.method == 'PROPFIND') {
        return _davResponse([_davFile(request.uri.path, collection: true)]);
      }
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

  test('coalesces concurrent collection creation', () async {
    final firstMkcol = Completer<void>();
    var mkcols = 0;
    final adapter = RecordingAdapter((request) async {
      if (request.method == 'MKCOL') {
        mkcols++;
        if (mkcols == 1) await firstMkcol.future;
        return const TestHttpResponse(201);
      }
      if (request.method == 'PUT') {
        return const TestHttpResponse(201, '', {
          'etag': ['"created"'],
        });
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });
    final backend = _backend(adapter);
    final bytes = Uint8List.fromList([1]);
    final hash = sha256.convert(bytes).toString();

    final uploads = [
      backend.putObject('concurrent-a', bytes, sha256: hash),
      backend.putObject('concurrent-b', bytes, sha256: hash),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(mkcols, 1);
    firstMkcol.complete();
    await Future.wait(uploads);

    expect(
      adapter.requests.where((request) => request.method == 'MKCOL'),
      hasLength(2),
    );
  });

  test('uses one strict Depth-1 object inventory', () async {
    final bytes = Uint8List.fromList(utf8.encode('abc'));
    final objectId = sha256.convert(bytes).toString();
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(201);
      if (request.method == 'PROPFIND') {
        expect(request.uri.path, endsWith('/objects/'));
        expect(request.headers['Depth'], '1');
        final body = utf8.decode(request.data as Uint8List);
        expect(body, contains('<d:resourcetype/>'));
        expect(body, contains('<d:getetag/>'));
        expect(body, contains('<d:getcontentlength/>'));
        expect(body, isNot(contains('allprop')));
        return _davResponse([
          _davFile(request.uri.path, collection: true, etag: false),
          _davFile('${request.uri.path}$objectId', contentLength: 3),
          _davFile(
            '${request.uri.path}weak',
            etagValue: 'W/"weak"',
            contentLength: 3,
          ),
          _davFile('${request.uri.path}missing', etag: false, contentLength: 3),
        ]);
      }
      if (request.method == 'GET') {
        expect(request.uri.path, endsWith(objectId));
        return TestHttpResponse(200, bytes);
      }
      fail('Unexpected ${request.method} ${request.uri}');
    });

    final backend = _backend(adapter);
    final existing = await backend.findExistingObjects({
      objectId: 3,
      'weak': 3,
      'missing': 3,
    });
    final cached = await backend.findExistingObjects({objectId: 3});

    expect(existing, {objectId});
    expect(cached, {objectId});
    expect(
      adapter.requests.where((request) => request.method == 'PROPFIND'),
      hasLength(2),
    );
    expect(
      adapter.requests.where((request) => request.method == 'GET'),
      hasLength(1),
    );
  });

  test('inventory rejects duplicate entries and size conflicts', () async {
    Future<void> expectRejected(List<String> entries) async {
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(201);
        if (request.method == 'PROPFIND') return _davResponse(entries);
        fail('Unexpected ${request.method}');
      });
      await expectLater(
        _backend(adapter).findExistingObjects(const {'same': 3}),
        throwsA(isA<CloudBackendException>()),
      );
    }

    await expectRejected([
      _davFile('/sync/aaalice-sync/objects/same', contentLength: 3),
      _davFile('/sync/aaalice-sync/objects/same', contentLength: 3),
    ]);
    await expectRejected([
      _davFile('/sync/aaalice-sync/objects/same', contentLength: 4),
    ]);
    await expectRejected([
      _davFile('/sync/aaalice-sync/objects/nested/same', contentLength: 3),
    ]);
  });

  test(
    'inventory upload path avoids per-object GET and repeated MKCOL',
    () async {
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(201);
        if (request.method == 'PROPFIND') {
          return _davResponse([
            _davFile(request.uri.path, collection: true, etag: false),
          ]);
        }
        if (request.method == 'PUT') {
          expect(request.headers['If-None-Match'], '*');
          return const TestHttpResponse(201, '', {
            'etag': ['"created"'],
          });
        }
        fail('Unexpected ${request.method} ${request.uri}');
      });
      final backend = _backend(adapter);
      final bytes = Uint8List.fromList([1, 2, 3]);
      final hash = sha256.convert(bytes).toString();

      expect(
        await backend.findExistingObjects(const {'first': 3, 'second': 3}),
        isEmpty,
      );
      await Future.wait([
        backend.putObject('first', bytes, sha256: hash),
        backend.putObject('second', bytes, sha256: hash),
      ]);

      expect(adapter.requests.map((request) => request.method), [
        'MKCOL',
        'MKCOL',
        'PROPFIND',
        'PUT',
        'PUT',
      ]);
    },
  );

  test(
    'Nutstore 400 for an existing collection is verified before upload',
    () async {
      var puts = 0;
      final adapter = RecordingAdapter((request) {
        if (request.method == 'MKCOL') return const TestHttpResponse(400);
        if (request.method == 'PROPFIND') {
          expect(request.headers['Depth'], '0');
          expect(request.data, isA<Uint8List>());
          return _davResponse([_davFile(request.uri.path, collection: true)]);
        }
        if (request.method == 'PUT') {
          puts++;
          return const TestHttpResponse(201, '', {
            'etag': ['"object"'],
          });
        }
        fail('Unexpected ${request.method} ${request.uri}');
      });
      final bytes = Uint8List.fromList([1, 2, 3]);

      await _backend(adapter).putObject(
        'nutstore-object',
        bytes,
        sha256: sha256.convert(bytes).toString(),
      );

      expect(puts, 1);
      expect(
        adapter.requests.where((request) => request.method == 'PROPFIND'),
        hasLength(2),
      );
    },
  );

  test('MKCOL 400 is not ignored when the target is a file', () async {
    final adapter = RecordingAdapter((request) {
      if (request.method == 'MKCOL') return const TestHttpResponse(400);
      if (request.method == 'PROPFIND') {
        return _davResponse([_davFile(request.uri.path)]);
      }
      fail('PUT must not run for a non-collection target');
    });
    final bytes = Uint8List.fromList([1]);

    await expectLater(
      _backend(adapter).putObject(
        'unsafe-object',
        bytes,
        sha256: sha256.convert(bytes).toString(),
      ),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.statusCode,
          'statusCode',
          400,
        ),
      ),
    );
  });

  test(
    'PROPFIND parses DAV files, excludes collections, and limits ids',
    () async {
      final adapter = RecordingAdapter(
        (request) => const TestHttpResponse(
          207,
          '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
          '<d:response><d:href>/sync/snapshots/2025.json</d:href>'
          '<d:propstat><d:prop><d:resourcetype/></d:prop>'
          '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
          '<d:response><d:href>/sync/snapshots/2026.json</d:href>'
          '<d:propstat><d:prop><d:resourcetype/></d:prop>'
          '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
          '<d:response><d:href>/sync/snapshots/2099.json/</d:href>'
          '<d:propstat><d:prop><d:resourcetype><d:collection/>'
          '</d:resourcetype></d:prop>'
          '<d:status>HTTP/1.1 200 OK</d:status></d:propstat></d:response>'
          '</d:multistatus>',
        ),
      );

      expect(await _backend(adapter).listSnapshotIds(limit: 1), ['2026']);
      expect(adapter.requests.single.method, 'PROPFIND');
      expect(adapter.requests.single.headers['Depth'], '1');
      final body = utf8.decode(adapter.requests.single.data! as Uint8List);
      expect(body, contains('<d:prop><d:resourcetype/></d:prop>'));
      expect(body, isNot(contains('allprop')));
      expect(body, isNot(contains('getetag')));
      expect(await _backend(adapter).listSnapshotIds(limit: 0), isEmpty);
      expect(adapter.requests, hasLength(1));
    },
  );

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
        final body = utf8.decode(request.data! as Uint8List);
        expect(
          body,
          contains('<d:prop><d:resourcetype/><d:getetag/></d:prop>'),
        );
        expect(body, isNot(contains('allprop')));
        expect(body, isNot(contains('getcontentlength')));
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
  int contentLength = 10,
}) {
  final name = Uri.parse(href).pathSegments.last;
  return '<d:response><d:href>$href</d:href><d:propstat>'
      '<d:status>HTTP/1.1 ${ok ? '200 OK' : '404 Not Found'}</d:status><d:prop>'
      '${etag ? '<d:getetag>${etagValue != null && etagValue.startsWith('W/') ? etagValue : '"${etagValue ?? name}"'}</d:getetag>' : ''}'
      '${modified ? '<d:getlastmodified>${old ? 'Sun, 01 Mar 2026 12:00:00 GMT' : 'Tue, 10 Mar 2026 12:00:00 GMT'}</d:getlastmodified>' : ''}'
      '<d:getcontentlength>$contentLength</d:getcontentlength>'
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

WebDavCloudSyncBackend _statefulBackend() {
  final api = _StatefulWebDavApi();
  return _backend(RecordingAdapter(api.handle));
}

class _StatefulWebDavApi {
  final Map<String, Uint8List> _files = {};
  final Map<String, String> _etags = {};
  final Set<String> _collections = {'/sync/'};
  var _revision = 0;

  TestHttpResponse handle(RequestOptions request) {
    final path = request.uri.path;
    switch (request.method) {
      case 'MKCOL':
        if (_collections.contains(path)) return const TestHttpResponse(405);
        final parent = _parentCollection(path);
        if (!_collections.contains(parent)) return const TestHttpResponse(409);
        _collections.add(_collectionPath(path));
        return const TestHttpResponse(201);
      case 'GET':
        final bytes = _files[path];
        if (bytes == null) return const TestHttpResponse(404);
        return TestHttpResponse(200, latin1.decode(bytes), {
          'etag': [_etags[path]!],
        });
      case 'HEAD':
        final etag = _etags[path];
        if (etag == null) return const TestHttpResponse(404);
        return TestHttpResponse(200, '', {
          'etag': [etag],
        });
      case 'PUT':
        final existing = _files[path];
        if (request.headers['If-None-Match'] == '*' && existing != null) {
          return const TestHttpResponse(412);
        }
        final expected = request.headers['If-Match']?.toString();
        if (expected != null && expected != _etags[path]) {
          return const TestHttpResponse(412);
        }
        _files[path] = Uint8List.fromList(request.data as List<int>);
        final etag = '"stateful-${++_revision}"';
        _etags[path] = etag;
        return TestHttpResponse(existing == null ? 201 : 204, '', {
          'etag': [etag],
        });
      case 'DELETE':
        final expected = request.headers['If-Match']?.toString();
        if (!_files.containsKey(path)) return const TestHttpResponse(404);
        if (expected != null && expected != _etags[path]) {
          return const TestHttpResponse(412);
        }
        _files.remove(path);
        _etags.remove(path);
        return const TestHttpResponse(204);
      case 'PROPFIND':
        return _propfind(path, request.headers['Depth']?.toString());
      default:
        return TestHttpResponse(
          500,
          'unexpected ${request.method} ${request.uri}',
        );
    }
  }

  TestHttpResponse _propfind(String path, String? depth) {
    final isCollection = _collections.contains(_collectionPath(path));
    final isFile = _files.containsKey(path);
    if (!isCollection && !isFile) return const TestHttpResponse(404);

    final entries = <String>[
      _entry(
        isCollection ? _collectionPath(path) : path,
        collection: isCollection,
      ),
    ];
    if (depth == '1' && isCollection) {
      final collection = _collectionPath(path);
      entries.addAll(
        _collections
            .where(
              (candidate) =>
                  candidate != collection &&
                  _parentCollection(candidate) == collection,
            )
            .map((candidate) => _entry(candidate, collection: true)),
      );
      entries.addAll(
        _files.keys
            .where((candidate) => _parentCollection(candidate) == collection)
            .map((candidate) => _entry(candidate)),
      );
    }
    return TestHttpResponse(
      207,
      '<?xml version="1.0"?><d:multistatus xmlns:d="DAV:">'
      '${entries.join()}</d:multistatus>',
      const {
        'date': ['Thu, 12 Mar 2026 12:00:00 GMT'],
      },
    );
  }

  String _entry(String path, {bool collection = false}) {
    final etag = _etags[path];
    return '<d:response><d:href>$path</d:href><d:propstat>'
        '<d:status>HTTP/1.1 200 OK</d:status><d:prop>'
        '${etag == null ? '' : '<d:getetag>$etag</d:getetag>'}'
        '<d:getlastmodified>Tue, 10 Mar 2026 12:00:00 GMT</d:getlastmodified>'
        '<d:getcontentlength>${_files[path]?.length ?? 0}</d:getcontentlength>'
        '<d:resourcetype>${collection ? '<d:collection/>' : ''}</d:resourcetype>'
        '</d:prop></d:propstat></d:response>';
  }

  static String _collectionPath(String path) =>
      path.endsWith('/') ? path : '$path/';

  static String _parentCollection(String path) {
    final normalized = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final slash = normalized.lastIndexOf('/');
    return normalized.substring(0, slash + 1);
  }
}
