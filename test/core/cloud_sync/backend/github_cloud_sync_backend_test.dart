import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_cloud_sync_backend.dart';

import 'backend_test_support.dart';
import 'github_fake_api.dart';

void main() {
  test('connection check does not create probe commits', () async {
    final api = FakeGitHubApi();

    final capability = await _backend(api).testCapability();

    expect(capability.mode, CloudBackendMode.bidirectional);
    expect(capability.supportsHistory, isTrue);
    expect(capability.supportsDelete, isTrue);
    expect(
      api.files.keys.any((path) => path.contains('.capability-')),
      isFalse,
    );
    expect(api.requests.where((request) => request.method == 'PATCH'), isEmpty);
  });

  test(
    'public repositories get a privacy warning without blocking use',
    () async {
      final capability = await _backend(
        FakeGitHubApi(repositoryPrivate: false),
      ).testCapability();

      expect(capability.warnings, contains(contains('公开仓库')));
    },
  );

  test('初次与第二次同步均以单一 commit 原子发布完整 snapshot', () async {
    final api = FakeGitHubApi();
    final backend = _backend(api);

    final first = await _uploadSnapshot(backend, 's1', expectedRevision: null);
    expect(
      api.files.keys,
      containsAll(<String>[
        'cloud/objects/s1.0',
        'cloud/snapshots/s1.json',
        'cloud/HEAD.json',
      ]),
    );

    final second = await _uploadSnapshot(
      backend,
      's2',
      expectedRevision: first.revision,
    );
    expect(second.revision, endsWith(':${api.branch}'));
    expect(
      api.files.keys,
      containsAll(<String>[
        'cloud/objects/s1.0',
        'cloud/objects/s2.0',
        'cloud/snapshots/s2.json',
      ]),
    );
    expect(api.snapshotCommitCount, 2);
    expect(
      api.requests.where(
        (request) =>
            request.method == 'PUT' &&
            request.uri.path.contains('/contents/cloud/objects'),
      ),
      isEmpty,
    );
  });

  test('并发 branch 更新使非 force ref CAS 失败且不暴露半套文件', () async {
    final api = FakeGitHubApi();
    final backend = _backend(api);
    await backend.putObject(
      's1.0',
      Uint8List.fromList([1]),
      sha256: sha256.convert([1]).toString(),
    );
    await backend.putSnapshotManifest(
      's1',
      Uint8List.fromList([2]),
      sha256: sha256.convert([2]).toString(),
    );
    api.conflictNextRefUpdate = true;

    await expectLater(
      backend.commitHead(Uint8List.fromList([3]), expectedRevision: null),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );
    expect(api.files.keys, isNot(contains('cloud/objects/s1.0')));
    expect(api.files.keys, isNot(contains('cloud/HEAD.json')));
  });

  test('deleteNamespace 由单一 tree commit 原子删除且不 force', () async {
    final api = FakeGitHubApi(
      initialFiles: {
        'cloud/HEAD.json': Uint8List.fromList([1]),
        'cloud/objects/a': Uint8List.fromList([2]),
        'unrelated.txt': Uint8List.fromList([3]),
      },
    );

    await _backend(api).deleteNamespace();

    expect(api.files.keys, ['unrelated.txt']);
    final patches = api.requests.where((request) => request.method == 'PATCH');
    expect(patches, hasLength(1));
    expect(
      jsonDecode(patches.single.data as String),
      containsPair('force', false),
    );
    expect(
      api.requests.where((request) => request.method == 'DELETE'),
      isEmpty,
    );
  });

  test('stale inline content 校验 Git blob SHA 后回退不可变 blob', () async {
    final wanted = Uint8List.fromList([1, 2, 3, 4]);
    final api = FakeGitHubApi(initialFiles: {'cloud/objects/item': wanted})
      ..staleInlinePath = 'cloud/objects/item'
      ..staleInlineBytes = Uint8List.fromList([9, 9]);

    final read = await _backend(api).readObject('item');

    expect(
      read,
      isNotNull,
      reason: api.requests.map((request) => request.uri.toString()).join('\n'),
    );
    expect(read!.bytes, wanted);
    expect(
      api.requests.any((request) => request.uri.path.contains('/git/blobs/')),
      isTrue,
    );
  });

  test(
    'immutable retry reads base revision and does not stage duplicate blob',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final api = FakeGitHubApi(initialFiles: {'cloud/objects/item': bytes});

      final result = await _backend(
        api,
      ).putObject('item', bytes, sha256: sha256.convert(bytes).toString());

      expect(result.revision, hasLength(40));
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/git/blobs'),
        ),
        isEmpty,
      );
    },
  );

  test(
    '403 rate limit is classified without exposing response headers',
    () async {
      final adapter = RecordingAdapter(
        (_) => const TestHttpResponse(403, '{}', {
          'x-ratelimit-remaining': ['0'],
          'x-ratelimit-reset': ['1893456000'],
          'x-oauth-scopes': ['secret-scope-value'],
        }),
      );

      await expectLater(
        _backend(adapter).readObject('item'),
        throwsA(
          isA<CloudBackendException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudBackendErrorKind.rateLimited,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('secret-scope-value')),
              ),
        ),
      );
    },
  );

  test('rejects oversized GitHub JSON before buffering its body', () async {
    final adapter = RecordingAdapter(
      (_) => const TestHttpResponse(200, '', {
        'content-length': ['6000000'],
      }),
    );

    await expectLater(
      _backend(adapter).readObject('item'),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.invalidResponse,
        ),
      ),
    );
  });

  test('accepts a valid 4 MiB GitHub blob with wrapped base64', () async {
    final bytes = Uint8List(maxCloudObjectResponseBytes);
    final encoded = base64Encode(bytes);
    final wrapped = <String>[
      for (var offset = 0; offset < encoded.length; offset += 60)
        encoded.substring(
          offset,
          offset + 60 < encoded.length ? offset + 60 : encoded.length,
        ),
    ].join('\n');
    final blobSha = sha1.convert([
      ...utf8.encode('blob ${bytes.length}\u0000'),
      ...bytes,
    ]).toString();
    final body = jsonEncode({
      'sha': blobSha,
      'size': bytes.length,
      'encoding': 'base64',
      'content': wrapped,
    });
    final adapter = RecordingAdapter((_) => TestHttpResponse(200, body));

    final read = await _backend(adapter).readObject('item');

    expect(read, isNotNull);
    expect(read!.bytes, hasLength(maxCloudObjectResponseBytes));
  });

  test('rejects unsafe repository namespaces', () {
    for (final namespace in ['/absolute', 'empty//segment', 'dot/./segment']) {
      expect(
        () => GitHubCloudSyncBackend(
          owner: 'alice',
          repository: 'private',
          branch: 'sync',
          token: 'token',
          namespace: namespace,
        ),
        throwsArgumentError,
      );
    }
  });
}

Future<CloudCommitResult> _uploadSnapshot(
  GitHubCloudSyncBackend backend,
  String id, {
  required String? expectedRevision,
}) async {
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
  return backend.commitHead(
    Uint8List.fromList(utf8.encode('head-$id')),
    expectedRevision: expectedRevision,
  );
}

GitHubCloudSyncBackend _backend(HttpClientAdapter adapter) =>
    GitHubCloudSyncBackend(
      owner: 'alice',
      repository: 'private',
      branch: 'sync',
      token: 'github_pat_secret',
      namespace: 'cloud',
      apiBaseUri: Uri.parse('https://api.github.test/'),
      dio: Dio()..httpClientAdapter = adapter,
    );
