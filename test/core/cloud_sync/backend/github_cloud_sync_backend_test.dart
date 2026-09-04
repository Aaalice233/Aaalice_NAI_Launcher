import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/backend_http.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_api_client.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_backend_support.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';

import 'backend_test_support.dart';
import 'cloud_sync_backend_contract.dart';
import 'github_fake_api.dart';

void main() {
  test('malformed Git blob SHA never bypasses content validation', () {
    expect(
      GitHubBackendSupport.matchesGitBlobSha(Uint8List.fromList([1]), 'bad'),
      isFalse,
    );
  });

  runCloudSyncBackendContract(
    provider: 'GitHub',
    createBackend: () => _backend(FakeGitHubApi()),
    expectations: const CloudSyncBackendContractExpectations(
      mode: CloudBackendMode.bidirectional,
    ),
  );

  test('default backend writes only the isolated v3 namespace', () async {
    final api = FakeGitHubApi();
    final backend = GitHubCloudSyncBackend(
      owner: 'alice',
      repository: 'private',
      branch: 'sync',
      token: 'github_pat_secret',
      apiBaseUri: Uri.parse('https://api.github.test/'),
      dio: Dio()..httpClientAdapter = api,
    );

    await _uploadSnapshot(backend, 'isolated', expectedRevision: null);

    expect(api.files.keys, contains('aaalice-sync-v3/HEAD.json'));
    expect(
      api.files.keys.any(
        (path) =>
            path == 'aaalice-sync/HEAD.json' ||
            path.startsWith('aaalice-sync/objects/') ||
            path.startsWith('aaalice-sync/snapshots/'),
      ),
      isFalse,
    );
  });

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
    expect(
      api.requests.where(
        (request) => request.method == 'PATCH' || request.method == 'PUT',
      ),
      isEmpty,
    );
  });

  test(
    'public repositories get a privacy warning without blocking use',
    () async {
      final capability = await _backend(
        FakeGitHubApi(repositoryPrivate: false),
      ).testCapability();

      expect(capability.warnings, [CloudBackendWarning.githubPublicRepository]);
    },
  );

  test('concurrent immutable uploads share one staging session', () async {
    final api = FakeGitHubApi();
    final backend = _backend(api);
    final first = Uint8List.fromList([1]);
    final second = Uint8List.fromList([2]);
    final firstId = sha256.convert(first).toString();
    final secondId = sha256.convert(second).toString();

    await Future.wait([
      backend.putObject(firstId, first, sha256: firstId),
      backend.putObject(secondId, second, sha256: secondId),
    ]);
    final manifest = Uint8List.fromList(utf8.encode('{}'));
    await backend.putSnapshotManifest(
      'snapshot',
      manifest,
      sha256: sha256.convert(manifest).toString(),
    );
    await backend.commitHead(
      Uint8List.fromList(utf8.encode('{}')),
      expectedRevision: null,
    );

    expect(
      api.files.keys,
      containsAll(['cloud/objects/$firstId', 'cloud/objects/$secondId']),
    );
  });

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

  test('HEAD blob 未变但 branch 已推进时拒绝旧 revision', () async {
    final api = FakeGitHubApi();
    final initial = await _uploadSnapshot(
      _backend(api),
      's1',
      expectedRevision: null,
    );
    final initialCommit = initial.revision.split(':').last;

    api.advanceBranchAfterNextBranchRead = true;
    await _backend(api).readHead();
    expect(api.branch, isNot(initialCommit));
    final blobUploadsBeforeCommit = api.requests
        .where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/git/blobs'),
        )
        .length;

    await expectLater(
      _backend(api).commitHead(
        Uint8List.fromList(utf8.encode('stale-head')),
        expectedRevision: initial.revision,
      ),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.conflict,
        ),
      ),
    );
    expect(
      api.requests.where(
        (request) =>
            request.method == 'POST' && request.uri.path.endsWith('/git/blobs'),
      ),
      hasLength(blobUploadsBeforeCommit),
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

  test('deleteNamespace 由单一 tree commit 原子删除多级 namespace 且不 force', () async {
    final api = FakeGitHubApi(
      initialFiles: {
        'parent/cloud/HEAD.json': Uint8List.fromList([1]),
        'parent/cloud/objects/a': Uint8List.fromList([2]),
        'parent/kept.txt': Uint8List.fromList([3]),
        'unrelated.txt': Uint8List.fromList([4]),
      },
    );

    await _backend(api, namespace: 'parent/cloud').deleteNamespace();

    expect(api.files.keys, containsAll(['parent/kept.txt', 'unrelated.txt']));
    expect(
      api.files.keys.where((path) => path.startsWith('parent/cloud/')),
      isEmpty,
    );
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

  test('读取固定 tree 中的不可变 blob，不使用逐 path Contents', () async {
    final wanted = Uint8List.fromList([1, 2, 3, 4]);
    final api = FakeGitHubApi(initialFiles: {'cloud/objects/item': wanted});

    final read = await _backend(api).readObject('item');

    expect(read!.bytes, wanted);
    expect(
      api.requests.any((request) => request.uri.path.contains('/git/blobs/')),
      isTrue,
    );
    expect(
      api.requests.any((request) => request.uri.path.contains('/contents/')),
      isFalse,
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
    'recursive inventory fails closed when GitHub truncates the tree',
    () async {
      final api = FakeGitHubApi()..truncateNextRecursiveTree = true;
      final backend = _backend(api) as CloudObjectInventoryBackend;

      await expectLater(
        backend.findExistingObjects(const {}),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test(
    'N objects use one inventory and only C new object blob uploads',
    () async {
      final existingA = Uint8List.fromList([1]);
      final existingB = Uint8List.fromList([2]);
      final newA = Uint8List.fromList([3]);
      final newB = Uint8List.fromList([4]);
      final payloads = [existingA, existingB, newA, newB];
      final ids = [
        for (final bytes in payloads) sha256.convert(bytes).toString(),
      ];
      final api = FakeGitHubApi(
        initialFiles: {
          'cloud/objects/${ids[0]}': existingA,
          'cloud/objects/${ids[1]}': existingB,
        },
      );
      final backend = _backend(api);
      final inventory = backend as CloudObjectInventoryBackend;

      final existing = await inventory.findExistingObjects({
        for (var index = 0; index < payloads.length; index++)
          ids[index]: payloads[index].length,
      });
      expect(existing, {ids[0], ids[1]});
      for (var index = 0; index < payloads.length; index++) {
        if (existing.contains(ids[index])) continue;
        await backend.putObject(
          ids[index],
          payloads[index],
          sha256: ids[index],
        );
      }
      final manifest = Uint8List.fromList([5]);
      await backend.putSnapshotManifest(
        's1',
        manifest,
        sha256: sha256.convert(manifest).toString(),
      );
      await backend.commitHead(Uint8List.fromList([6]), expectedRevision: null);

      expect(
        api.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.uri.path.contains('/git/trees/') &&
              request.uri.queryParameters['recursive'] == '1',
        ),
        hasLength(1),
      );
      expect(
        api.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.uri.path.contains('/contents/cloud/objects/'),
        ),
        isEmpty,
      );
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/git/blobs'),
        ),
        hasLength(4),
        reason: '2 new objects plus manifest and HEAD',
      );
    },
  );

  test(
    'readObject remains pinned to the commit read before a branch race',
    () async {
      final original = Uint8List.fromList([1, 2, 3]);
      final replacement = Uint8List.fromList([9, 8, 7]);
      final api = FakeGitHubApi(initialFiles: {'cloud/objects/item': original})
        ..advanceBranchAfterNextBranchRead = true
        ..filesForNextBranchAdvance = {'cloud/objects/item': replacement};

      final read = await _backend(api).readObject('item');

      expect(read!.bytes, original);
      expect(
        api.requests.any(
          (request) => request.uri.path.endsWith('/git/commits/c0'),
        ),
        isTrue,
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
        _backend(adapter, sleeper: (_) async {}).readObject('item'),
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

  test('downloads a valid 4 MiB GitHub blob using raw media type', () async {
    final bytes = Uint8List(maxCloudObjectResponseBytes);
    final blobSha = sha1.convert([
      ...utf8.encode('blob ${bytes.length}\u0000'),
      ...bytes,
    ]).toString();
    final adapter = RecordingAdapter((request) {
      final path = request.uri.path;
      if (path.endsWith('/branches/sync')) {
        return TestHttpResponse(
          200,
          jsonEncode({
            'commit': {'sha': 'fixed-commit'},
          }),
        );
      }
      if (path.endsWith('/git/commits/fixed-commit')) {
        return TestHttpResponse(
          200,
          jsonEncode({
            'tree': {'sha': 'fixed-tree'},
          }),
        );
      }
      if (path.endsWith('/git/trees/fixed-tree')) {
        return TestHttpResponse(
          200,
          jsonEncode({
            'truncated': false,
            'tree': [
              {
                'path': 'cloud/objects/item',
                'type': 'blob',
                'sha': blobSha,
                'size': bytes.length,
              },
            ],
          }),
        );
      }
      expect(request.headers['Accept'], 'application/vnd.github.raw+json');
      return TestHttpResponse(200, bytes);
    });

    final read = await _backend(adapter).readObject('item');

    expect(read, isNotNull);
    expect(read!.bytes, hasLength(maxCloudObjectResponseBytes));
  });

  test('bounds secondary rate-limit Retry-After before retrying', () async {
    var attempts = 0;
    final sleeps = <Duration>[];
    final adapter = RecordingAdapter((_) {
      attempts++;
      if (attempts < 3) {
        return const TestHttpResponse(
          403,
          '{"message":"secondary rate limit"}',
          {
            'retry-after': ['120'],
            'x-ratelimit-remaining': ['42'],
          },
        );
      }
      return const TestHttpResponse(200, '{}');
    });

    final result = await GitHubApiClient(
      owner: 'alice',
      repository: 'private',
      branch: 'sync',
      token: 'token',
      apiBaseUri: Uri.parse('https://api.github.test/'),
      dio: Dio()..httpClientAdapter = adapter,
      sleeper: (delay) async => sleeps.add(delay),
    ).repositoryInfo();

    expect(result, isEmpty);
    expect(attempts, 3);
    expect(sleeps, [const Duration(seconds: 30), const Duration(seconds: 30)]);
  });

  test('does not retry an ordinary permission 403', () async {
    final adapter = RecordingAdapter(
      (_) =>
          const TestHttpResponse(403, '{"message":"Resource not accessible"}', {
            'x-ratelimit-remaining': ['42'],
          }),
    );

    await expectLater(
      _backend(adapter, sleeper: (_) async {}).readObject('item'),
      throwsA(
        isA<CloudBackendException>().having(
          (error) => error.kind,
          'kind',
          CloudBackendErrorKind.authorization,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });

  test(
    'telemetry records each failed HTTP attempt and response bytes',
    () async {
      final adapter = RecordingAdapter(
        (_) => const TestHttpResponse(503, 'fail'),
      );

      final log = await _captureTelemetryLog(
        'github-failed-attempts',
        () => expectLater(
          _backend(adapter).readObject('item'),
          throwsA(isA<CloudBackendException>()),
        ),
      );

      expect(adapter.requests, hasLength(3));
      expect(log, contains('requests=3'));
      expect(log, contains('bytesRead=12'));
      expect(log, contains('bytesWritten=0'));
    },
  );

  test('telemetry records encoded GitHub request body bytes', () async {
    final api = FakeGitHubApi();
    final bytes = Uint8List.fromList([1, 2, 3]);

    final log = await _captureTelemetryLog(
      'github-request-bytes',
      () => _backend(api).putObject(
        sha256.convert(bytes).toString(),
        bytes,
        sha256: sha256.convert(bytes).toString(),
      ),
    );

    final upload = api.requests.singleWhere(
      (request) =>
          request.method == 'POST' && request.uri.path.endsWith('/git/blobs'),
    );
    final encodedRequestBytes = utf8.encode(upload.data as String).length;
    expect(log, contains('requests=${api.requests.length}'));
    expect(log, contains('bytesWritten=$encodedRequestBytes'));
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

Future<String> _captureTelemetryLog(
  String operation,
  Future<void> Function() action,
) async {
  final output = <String>[];
  await runZoned(
    () => CloudSyncTelemetry.trace(operation, action),
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => output.add(line),
    ),
  );
  return output.join('\n');
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

GitHubCloudSyncBackend _backend(
  HttpClientAdapter adapter, {
  BackendHttpSleeper? sleeper,
  String namespace = 'cloud',
}) => GitHubCloudSyncBackend(
  owner: 'alice',
  repository: 'private',
  branch: 'sync',
  token: 'github_pat_secret',
  namespace: namespace,
  apiBaseUri: Uri.parse('https://api.github.test/'),
  dio: Dio()..httpClientAdapter = adapter,
  sleeper: sleeper,
);
