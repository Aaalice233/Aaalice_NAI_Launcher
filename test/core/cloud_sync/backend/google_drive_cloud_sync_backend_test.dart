import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/google_drive_cloud_sync_backend.dart';

void main() {
  test(
    'capability is explicitly manual-only and warns about missing CAS',
    () async {
      final api = _FakeDriveApi();

      final capability = await _backend(api).testCapability();

      expect(capability.mode, CloudBackendMode.manualBackupOnly);
      expect(capability.supportsBidirectional, isFalse);
      expect(capability.warnings, contains(contains('compare-and-swap')));
      expect(capability.warnings, contains(contains('无法安全启用双向同步')));
      expect(
        api.requests.single.uri.queryParameters['spaces'],
        'appDataFolder',
      );
    },
  );

  test(
    'uploads and downloads hidden deterministic appDataFolder records',
    () async {
      final api = _FakeDriveApi();
      final backend = _backend(api);
      final object = Uint8List.fromList([1, 2, 3, 4]);
      final manifest = Uint8List.fromList(utf8.encode('{"snapshot":"s1"}'));

      await backend.putObject(
        's1.0',
        object,
        sha256: sha256.convert(object).toString(),
      );
      await backend.putSnapshotManifest(
        's1',
        manifest,
        sha256: sha256.convert(manifest).toString(),
      );

      expect((await backend.readObject('s1.0'))!.bytes, object);
      expect((await backend.readSnapshotManifest('s1'))!.bytes, manifest);
      expect(
        api.files.values.map((file) => file.name),
        containsAll([
          'aaalice-cloud-sync-object-s1.0',
          'aaalice-cloud-sync-snapshot-s1.json',
        ]),
      );
      for (final file in api.files.values) {
        expect(file.parents, ['appDataFolder']);
        expect(file.appProperties['protocol'], 'aaalice-cloud-sync-v1');
        expect(file.appProperties['namespace'], hasLength(64));
      }
    },
  );

  test('namespace inspection sees every hidden provider artifact', () async {
    final api = _FakeDriveApi();
    final backend = _backend(api);

    expect(await backend.isNamespaceEmpty(), isTrue);
    api.addFile(
      name: 'aaalice-cloud-sync-object-orphan.0',
      type: 'object',
      bytes: Uint8List.fromList([1]),
    );
    expect(await backend.isNamespaceEmpty(), isFalse);
  });

  test('follows Drive list pagination for snapshot history', () async {
    final api = _FakeDriveApi(forceSingleItemPages: true)
      ..addFile(
        name: 'aaalice-cloud-sync-snapshot-s1.json',
        type: 'manifest',
        bytes: Uint8List.fromList([1]),
      )
      ..addFile(
        name: 'aaalice-cloud-sync-snapshot-s3.json',
        type: 'manifest',
        bytes: Uint8List.fromList([3]),
      )
      ..addFile(
        name: 'aaalice-cloud-sync-snapshot-s2.json',
        type: 'manifest',
        bytes: Uint8List.fromList([2]),
      );

    final ids = await _backend(api).listSnapshotIds(limit: 2);

    expect(ids, ['s3', 's2']);
    expect(
      api.requests.where((request) => request.uri.path.endsWith('/files')),
      hasLength(3),
    );
    expect(api.requests.last.uri.queryParameters['pageToken'], isNotNull);
  });

  test(
    'identical immutable duplicates are verified, different ones conflict',
    () async {
      final same = Uint8List.fromList([7, 8, 9]);
      final api = _FakeDriveApi()
        ..addFile(
          name: 'aaalice-cloud-sync-object-item',
          type: 'object',
          bytes: same,
        )
        ..addFile(
          name: 'aaalice-cloud-sync-object-item',
          type: 'object',
          bytes: Uint8List.fromList(same),
        );
      final backend = _backend(api);

      final result = await backend.putObject(
        'item',
        same,
        sha256: sha256.convert(same).toString(),
      );
      expect(result.revision, isNotEmpty);
      expect(
        api.requests.where((request) => request.method == 'POST'),
        isEmpty,
      );

      api.addFile(
        name: 'aaalice-cloud-sync-object-item',
        type: 'object',
        bytes: Uint8List.fromList([0]),
      );
      await expectLater(
        backend.readObject('item'),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );
    },
  );

  test('mutable duplicate names conflict instead of pretending CAS', () async {
    final api = _FakeDriveApi()
      ..addFile(
        name: 'aaalice-cloud-sync-HEAD.json',
        type: 'head',
        bytes: Uint8List.fromList([1]),
      )
      ..addFile(
        name: 'aaalice-cloud-sync-HEAD.json',
        type: 'head',
        bytes: Uint8List.fromList([1]),
      );

    await expectLater(
      _backend(api).readHead(),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );
  });

  test('429 list response is retried before upload', () async {
    final api = _FakeDriveApi()
      ..remainingRateLimits = 1
      ..rateLimitPath = '/drive/v3/files';
    final bytes = Uint8List.fromList([4, 2]);

    await _backend(
      api,
    ).putObject('retry', bytes, sha256: sha256.convert(bytes).toString());

    expect(api.rateLimitResponses, 1);
    expect(
      api.requests.where((request) => request.method == 'POST'),
      hasLength(1),
    );
  });

  test(
    'HEAD revision only rejects an already-stale read before best-effort write',
    () async {
      final api = _FakeDriveApi();
      final backend = _backend(api);
      final first = await backend.commitHead(
        Uint8List.fromList([1]),
        expectedRevision: null,
      );
      await backend.commitHead(
        Uint8List.fromList([2]),
        expectedRevision: first.revision,
      );

      await expectLater(
        backend.commitHead(
          Uint8List.fromList([3]),
          expectedRevision: first.revision,
        ),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );
      expect((await backend.testCapability()).supportsBidirectional, isFalse);
    },
  );
}

GoogleDriveCloudSyncBackend _backend(HttpClientAdapter adapter) =>
    GoogleDriveCloudSyncBackend(
      accessTokenProvider: () async => 'access-token-secret',
      namespace: 'cloud',
      apiBaseUri: Uri.parse('https://google.test/'),
      dio: Dio()..httpClientAdapter = adapter,
    );

class _FakeDriveApi implements HttpClientAdapter {
  _FakeDriveApi({this.forceSingleItemPages = false});

  final bool forceSingleItemPages;
  final Map<String, _FakeFile> files = {};
  final List<RequestOptions> requests = [];
  var remainingRateLimits = 0;
  var rateLimitResponses = 0;
  String? rateLimitPath;
  var _nextId = 1;

  void addFile({
    required String name,
    required String type,
    required Uint8List bytes,
  }) {
    final id = 'file-${_nextId++}';
    files[id] = _FakeFile(
      id: id,
      name: name,
      bytes: bytes,
      version: 1,
      appProperties: {
        'protocol': 'aaalice-cloud-sync-v1',
        'namespace': sha256.convert(utf8.encode('cloud')).toString(),
        'recordType': type,
      },
      parents: const ['appDataFolder'],
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    expect(options.headers['authorization'], 'Bearer access-token-secret');
    final path = options.uri.path;
    if (remainingRateLimits > 0 &&
        (rateLimitPath == null || rateLimitPath == path)) {
      remainingRateLimits--;
      rateLimitResponses++;
      return _response(
        429,
        '{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}',
        {
          'retry-after': ['0'],
        },
      );
    }

    if (options.method == 'GET' && path == '/drive/v3/files') {
      return _list(options.uri);
    }
    if (options.method == 'GET' &&
        path.startsWith('/drive/v3/files/') &&
        options.uri.queryParameters['alt'] == 'media') {
      final id = Uri.decodeComponent(path.substring('/drive/v3/files/'.length));
      final file = files[id];
      return file == null
          ? _response(404, '')
          : ResponseBody(Stream.value(file.bytes), 200);
    }
    if (options.method == 'POST' && path == '/upload/drive/v3/files') {
      final contentType = options.headers['content-type'] as String;
      final boundary = contentType.substring(
        contentType.indexOf('boundary=') + 9,
      );
      final body = options.data as Uint8List;
      final parsed = _parseMultipart(body, boundary);
      final metadata =
          jsonDecode(utf8.decode(parsed.metadata)) as Map<String, dynamic>;
      final properties = (metadata['appProperties'] as Map)
          .cast<String, String>();
      addFile(
        name: metadata['name'] as String,
        type: properties['recordType']!,
        bytes: parsed.bytes,
      );
      final file = files.values.last;
      expect(metadata['parents'], ['appDataFolder']);
      return _response(200, jsonEncode(file.metadata));
    }
    if (options.method == 'PATCH' &&
        path.startsWith('/upload/drive/v3/files/')) {
      final id = Uri.decodeComponent(
        path.substring('/upload/drive/v3/files/'.length),
      );
      final file = files[id];
      if (file == null) return _response(404, '');
      file.bytes = Uint8List.fromList(options.data as List<int>);
      file.version++;
      return _response(200, jsonEncode(file.metadata));
    }
    if (options.method == 'DELETE' && path.startsWith('/drive/v3/files/')) {
      final id = Uri.decodeComponent(path.substring('/drive/v3/files/'.length));
      return files.remove(id) == null ? _response(404, '') : _response(204, '');
    }
    return _response(500, 'unexpected ${options.method} $path');
  }

  ResponseBody _list(Uri uri) {
    final query = uri.queryParameters['q'] ?? '';
    final name = RegExp(r"name = '([^']+)'").firstMatch(query)?.group(1);
    final type = RegExp(
      r"key='recordType' and value='([^']+)'",
    ).firstMatch(query)?.group(1);
    final filtered = files.values
        .where((file) => name == null || file.name == name)
        .where(
          (file) => type == null || file.appProperties['recordType'] == type,
        )
        .toList();
    final offset = int.tryParse(uri.queryParameters['pageToken'] ?? '') ?? 0;
    final requested =
        int.tryParse(uri.queryParameters['pageSize'] ?? '') ?? 100;
    final count = forceSingleItemPages ? 1 : requested;
    final end = (offset + count).clamp(0, filtered.length);
    final page = filtered.sublist(offset.clamp(0, filtered.length), end);
    return _response(
      200,
      jsonEncode({
        'files': page.map((file) => file.metadata).toList(),
        if (end < filtered.length) 'nextPageToken': '$end',
      }),
    );
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody _response(
    int status,
    String body, [
    Map<String, List<String>> headers = const {},
  ]) => ResponseBody.fromString(body, status, headers: headers);
}

class _FakeFile {
  _FakeFile({
    required this.id,
    required this.name,
    required this.bytes,
    required this.version,
    required this.appProperties,
    required this.parents,
  });

  final String id;
  final String name;
  Uint8List bytes;
  int version;
  final Map<String, String> appProperties;
  final List<String> parents;

  Map<String, Object?> get metadata => {
    'id': id,
    'name': name,
    'size': '${bytes.length}',
    'md5Checksum': md5.convert(bytes).toString(),
    'modifiedTime': '2026-01-01T00:00:00Z',
    'version': '$version',
    'appProperties': appProperties,
  };
}

class _Multipart {
  const _Multipart(this.metadata, this.bytes);

  final Uint8List metadata;
  final Uint8List bytes;
}

_Multipart _parseMultipart(Uint8List body, String boundary) {
  final firstHeaderEnd = _indexOf(body, utf8.encode('\r\n\r\n'));
  final secondBoundary = _indexOf(
    body,
    utf8.encode('\r\n--$boundary\r\n'),
    firstHeaderEnd + 4,
  );
  final secondHeaderEnd = _indexOf(
    body,
    utf8.encode('\r\n\r\n'),
    secondBoundary,
  );
  final closing = _indexOf(
    body,
    utf8.encode('\r\n--$boundary--\r\n'),
    secondHeaderEnd + 4,
  );
  return _Multipart(
    Uint8List.sublistView(body, firstHeaderEnd + 4, secondBoundary),
    Uint8List.sublistView(body, secondHeaderEnd + 4, closing),
  );
}

int _indexOf(Uint8List source, List<int> pattern, [int start = 0]) {
  for (var index = start; index <= source.length - pattern.length; index++) {
    var matches = true;
    for (var offset = 0; offset < pattern.length; offset++) {
      if (source[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) return index;
  }
  throw StateError('multipart marker not found');
}
