import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/onedrive_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';

import 'cloud_sync_backend_contract.dart';

void main() {
  runCloudSyncBackendContract(
    provider: 'OneDrive',
    createBackend: () => _backend(_FakeOneDriveApi()),
    expectations: const CloudSyncBackendContractExpectations(
      mode: CloudBackendMode.bidirectional,
    ),
  );

  test('cancellation interrupts the private access-token wait', () async {
    final tokenResult = Completer<String>();
    final api = _FakeOneDriveApi();
    final backend = OneDriveCloudSyncBackend(
      accessTokenProvider: () => tokenResult.future,
      namespace: 'cloud',
      graphBaseUri: Uri.parse('https://graph.microsoft.test/v1.0/'),
      dio: Dio()..httpClientAdapter = api,
    );
    final operation = OperationToken();
    final capability = operation.runInScope(backend.testCapability);

    operation.cancel();

    await expectLater(capability, throwsA(isA<OperationCancelledException>()));
    expect(api.requests, isEmpty);
    tokenResult.complete('late-token');
  });

  test('cancellation interrupts Graph download retry backoff', () async {
    final api = _RateLimitedDownloadOneDriveApi();
    api.putFile('cloud/objects/snapshot.0', utf8.encode('payload'));
    final backend = OneDriveCloudSyncBackend(
      accessTokenProvider: () async => 'secret-access-token',
      namespace: 'cloud',
      graphBaseUri: Uri.parse('https://graph.microsoft.test/v1.0/'),
      dio: Dio()..httpClientAdapter = api,
    );
    final operation = OperationToken();
    final download = operation.runInScope(
      () => backend.readObject('snapshot.0'),
    );
    await api.downloadStarted.future;

    operation.cancel();

    await expectLater(download, throwsA(isA<OperationCancelledException>()));
  });

  test('uploads and downloads through approot without leaking token', () async {
    final api = _FakeOneDriveApi();
    final dio = Dio()..httpClientAdapter = api;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers.putIfAbsent(
            'Authorization',
            () => 'Bearer interceptor-token',
          );
          handler.next(options);
        },
      ),
    );
    final backend = OneDriveCloudSyncBackend(
      accessTokenProvider: () async => 'secret-access-token',
      namespace: 'cloud',
      graphBaseUri: Uri.parse('https://graph.microsoft.test/v1.0/'),
      dio: dio,
    );
    final bytes = Uint8List.fromList(utf8.encode('object payload'));

    final uploaded = await backend.putObject(
      'snapshot.0',
      bytes,
      sha256: sha256.convert(bytes).toString(),
    );
    final downloaded = await backend.readObject('snapshot.0');

    expect(downloaded!.bytes, bytes);
    expect(downloaded.revision, uploaded.revision);
    final appRootGet = api.requests.indexWhere(
      (request) =>
          request.method == 'GET' &&
          request.uri.path == '/v1.0/me/drive/special/approot',
    );
    final firstFolderCreate = api.requests.indexWhere(
      (request) =>
          request.method == 'POST' &&
          request.uri.path == '/v1.0/me/drive/items/approot-id/children',
    );
    expect(appRootGet, greaterThanOrEqualTo(0));
    expect(firstFolderCreate, greaterThan(appRootGet));
    final folderCreateRequest = api.requests[firstFolderCreate];
    expect(folderCreateRequest.uri.queryParameters, isEmpty);
    final folderCreateBody =
        jsonDecode(folderCreateRequest.data as String) as Map<String, dynamic>;
    expect(folderCreateBody, {'name': 'cloud', 'folder': <String, Object?>{}});
    expect(
      api.requests.any(
        (request) => request.uri.path.contains(
          '/me/drive/special/approot:/cloud/objects/snapshot.0',
        ),
      ),
      isTrue,
    );
    final signedRequests = api.requests.where(
      (request) => request.uri.host == 'signed.onedrive.test',
    );
    expect(signedRequests, isNotEmpty);
    for (final request in signedRequests) {
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    }
  });

  test(
    'inventories all object pages once and uploads missing objects without metadata',
    () async {
      final existingBytesA = Uint8List.fromList([1]);
      final existingBytesB = Uint8List.fromList([2, 3]);
      final unrelatedBytes = Uint8List.fromList([4]);
      final existingA = sha256.convert(existingBytesA).toString();
      final existingB = sha256.convert(existingBytesB).toString();
      final unrelated = sha256.convert(unrelatedBytes).toString();
      final missingBytesA = Uint8List.fromList([7, 8, 9]);
      final missingBytesB = Uint8List.fromList([10, 11, 12]);
      final missingA = sha256.convert(missingBytesA).toString();
      final missingB = sha256.convert(missingBytesB).toString();
      final api = _FakeOneDriveApi()
        ..putFile('cloud/objects/$existingA', existingBytesA)
        ..putFile('cloud/objects/$existingB', existingBytesB)
        ..putFile('cloud/objects/$unrelated', unrelatedBytes);
      final backend = _backend(api);

      final existing = await backend.findExistingObjects({
        existingA: 1,
        existingB: 2,
        missingA: missingBytesA.length,
        missingB: missingBytesB.length,
      });
      await backend.putObject(missingA, missingBytesA, sha256: missingA);
      await backend.putObject(missingB, missingBytesB, sha256: missingB);

      expect(existing, {existingA, existingB});
      expect(api.appRootRequests, 1);
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/children'),
        ),
        hasLength(2),
      );
      expect(
        api.requests.where(
          (request) =>
              request.method == 'GET' &&
              request.uri.path.endsWith(':/children'),
        ),
        hasLength(2),
      );
      for (final missing in [missingA, missingB]) {
        expect(
          api.requests.where(
            (request) =>
                request.method == 'GET' &&
                _FakeOneDriveApi.graphItemPath(request.uri.path) ==
                    'cloud/objects/$missing',
          ),
          isEmpty,
        );
      }
    },
  );

  test(
    'object inventory fails closed on size and duplicate conflicts',
    () async {
      final objectId = List.filled(64, 'd').join();
      final sizeConflictApi = _FakeOneDriveApi()
        ..putFile('cloud/objects/$objectId', [1, 2]);

      await expectLater(
        _backend(sizeConflictApi).findExistingObjects({objectId: 1}),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );

      final duplicateApi = _FakeOneDriveApi()
        ..putFile('cloud/objects/$objectId', [1, 2])
        ..additionalChildren.add({
          'id': 'duplicate-id',
          'name': objectId,
          'eTag': '"duplicate"',
          'size': 2,
          'file': <String, Object?>{},
        });
      await expectLater(
        _backend(duplicateApi).findExistingObjects({objectId: 2}),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );

      final invalidNameApi = _FakeOneDriveApi()
        ..putFile('cloud/objects/not-a-sha256', [1]);
      await expectLater(
        _backend(invalidNameApi).findExistingObjects({objectId: 2}),
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

  test('follows every children page before sorting and limiting', () async {
    final api = _FakeOneDriveApi()
      ..putFile('cloud/snapshots/2024.json', [1])
      ..putFile('cloud/snapshots/2026.json', [2])
      ..putFile('cloud/snapshots/2025.json', [3])
      ..putFile('cloud/snapshots/ignore.txt', [4]);

    final ids = await _backend(api).listSnapshotIds(limit: 2);

    expect(ids, ['2026', '2025']);
    expect(
      api.requests.where((request) => request.uri.path.endsWith(':/children')),
      hasLength(2),
    );
  });

  test('HEAD uses upload-session If-Match CAS', () async {
    final api = _FakeOneDriveApi();
    final backend = _backend(api);
    final head1 = await backend.commitHead(
      Uint8List.fromList([1]),
      expectedRevision: null,
    );

    final head2 = await backend.commitHead(
      Uint8List.fromList([2]),
      expectedRevision: head1.revision,
    );

    expect(head2.revision, isNot(head1.revision));
    final replaceSessions = api.requests.where(
      (request) =>
          request.uri.path.endsWith(':/createUploadSession') &&
          request.headers['If-Match'] == head1.revision,
    );
    expect(replaceSessions, hasLength(1));
    await expectLater(
      backend.commitHead(
        Uint8List.fromList([3]),
        expectedRevision: head1.revision,
      ),
      throwsA(
        isA<CloudBackendException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudBackendErrorKind.conflict,
            )
            .having((error) => error.statusCode, 'statusCode', 412),
      ),
    );
  });

  test(
    'expected null never falls back to overwrite and immutable is idempotent',
    () async {
      final api = _FakeOneDriveApi();
      final backend = _backend(api);
      final first = Uint8List.fromList([1, 2]);
      final other = Uint8List.fromList([2, 1]);

      final initial = await backend.putObject(
        'same.0',
        first,
        sha256: sha256.convert(first).toString(),
      );
      final retry = await backend.putObject(
        'same.0',
        first,
        sha256: sha256.convert(first).toString(),
      );
      expect(retry.revision, initial.revision);

      await expectLater(
        backend.putObject(
          'same.0',
          other,
          sha256: sha256.convert(other).toString(),
        ),
        throwsA(
          isA<CloudBackendException>().having(
            (error) => error.kind,
            'kind',
            CloudBackendErrorKind.conflict,
          ),
        ),
      );
      await expectLater(
        backend.commitHead(Uint8List.fromList([9]), expectedRevision: null),
        completion(isA<CloudCommitResult>()),
      );
      await expectLater(
        backend.commitHead(Uint8List.fromList([8]), expectedRevision: null),
        throwsA(
          isA<CloudBackendException>()
              .having(
                (error) => error.kind,
                'kind',
                CloudBackendErrorKind.conflict,
              )
              .having((error) => error.statusCode, 'statusCode', 409),
        ),
      );
      expect(api.fileBytes('cloud/HEAD.json'), [9]);
      final createOnly = api.requests.where((request) {
        if (!request.uri.path.endsWith(
          '/me/drive/special/approot:/cloud/HEAD.json:/createUploadSession',
        )) {
          return false;
        }
        final body = jsonDecode(request.data as String) as Map<String, dynamic>;
        return (body['item'] as Map)['@microsoft.graph.conflictBehavior'] ==
            'fail';
      });
      expect(createOnly, hasLength(2));
    },
  );

  test(
    'deleteNamespace invalidates folder singleflight before rebuild',
    () async {
      final first = Uint8List.fromList([1, 2, 3]);
      final second = Uint8List.fromList([4, 5, 6]);
      final firstId = sha256.convert(first).toString();
      final secondId = sha256.convert(second).toString();
      final api = _FakeOneDriveApi();
      final backend = _backend(api);

      await backend.putObject(firstId, first, sha256: firstId);
      await backend.deleteNamespace();
      await backend.putObject(secondId, second, sha256: secondId);

      expect(api.fileBytes('cloud/objects/$secondId'), second);
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/children'),
        ),
        hasLength(4),
      );
    },
  );

  test(
    'folder 404 invalidates singleflight and rebuilds exactly once',
    () async {
      final first = Uint8List.fromList([1, 2, 3]);
      final second = Uint8List.fromList([7, 8, 9]);
      final firstId = sha256.convert(first).toString();
      final secondId = sha256.convert(second).toString();
      final api = _FakeOneDriveApi();
      final backend = _backend(api);

      await backend.putObject(firstId, first, sha256: firstId);
      api.removeNamespace('cloud');
      await backend.putObject(secondId, second, sha256: secondId);

      expect(api.fileBytes('cloud/objects/$secondId'), second);
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith(':/createUploadSession'),
        ),
        hasLength(3),
      );
      expect(
        api.requests.where(
          (request) =>
              request.method == 'POST' &&
              request.uri.path.endsWith('/children'),
        ),
        hasLength(4),
      );
    },
  );

  test('retries 429 using Retry-After then succeeds', () async {
    final api = _FakeOneDriveApi()
      ..putFile('cloud/objects/item', [5])
      ..metadataRateLimitsRemaining = 2;

    final read = await _backend(api).readObject('item');

    expect(read!.bytes, [5]);
    expect(api.metadataRateLimitResponses, 2);
  });

  test('reports approot Graph errors without delaying setup retries', () async {
    final api = _FakeOneDriveApi()
      ..appRootFailureStatus = 503
      ..appRootFailureCode = 'serviceNotAvailable'
      ..appRootInnerFailureCode = 'itemDisabledDueToPendingProvisioning';

    await expectLater(
      _backend(api).testCapability(),
      throwsA(
        isA<CloudBackendException>()
            .having(
              (error) => error.kind,
              'kind',
              CloudBackendErrorKind.network,
            )
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.message,
              'message',
              contains('正在为此账号开通 OneDrive 应用目录'),
            ),
      ),
    );
    expect(api.appRootRequests, 1);
  });

  test('includes a bounded Microsoft error message in diagnostics', () async {
    final api = _FakeOneDriveApi()
      ..appRootFailureStatus = 400
      ..appRootFailureCode = 'invalidRequest'
      ..appRootFailureMessage = 'The provided name is invalid.\nRetry later.';

    await expectLater(
      _backend(api).testCapability(),
      throwsA(
        isA<CloudBackendException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              contains(
                'invalidRequest: The provided name is invalid. Retry later.',
              ),
            ),
      ),
    );
  });

  test('redacts credentials echoed by Microsoft error messages', () async {
    final api = _FakeOneDriveApi()
      ..appRootFailureStatus = 400
      ..appRootFailureCode = 'invalidRequest'
      ..appRootFailureMessage =
          'Authorization: Bearer secret-token password=hunter2';

    await expectLater(
      _backend(api).testCapability(),
      throwsA(
        isA<CloudBackendException>()
            .having(
              (error) => error.message,
              'message',
              contains('Bearer [redacted]'),
            )
            .having(
              (error) => error.message,
              'message',
              contains('password=[redacted]'),
            )
            .having(
              (error) => error.message,
              'message',
              isNot(anyOf(contains('secret-token'), contains('hunter2'))),
            ),
      ),
    );
  });

  test('capability validates app root without backup writes', () async {
    final api = _FakeOneDriveApi();

    final capability = await _backend(api).testCapability();

    expect(capability.mode, CloudBackendMode.bidirectional);
    expect(api.requests, hasLength(1));
    expect(api.requests.single.method, 'GET');
    expect(api.requests.single.uri.path, endsWith('/me/drive/special/approot'));
    expect(api.files, isEmpty);
  });
}

OneDriveCloudSyncBackend _backend(HttpClientAdapter adapter) =>
    OneDriveCloudSyncBackend(
      accessTokenProvider: () async => 'secret-access-token',
      namespace: 'cloud',
      graphBaseUri: Uri.parse('https://graph.microsoft.test/v1.0/'),
      dio: Dio()..httpClientAdapter = adapter,
    );

class _StoredFile {
  _StoredFile(this.bytes, this.eTag);

  Uint8List bytes;
  String eTag;
}

class _UploadSession {
  const _UploadSession(this.path);

  final String path;
}

class _FakeResponse {
  const _FakeResponse(
    this.status, [
    this.body = const [],
    this.headers = const {},
  ]);

  factory _FakeResponse.json(
    int status,
    Object body, [
    Map<String, List<String>> headers = const {},
  ]) => _FakeResponse(status, utf8.encode(jsonEncode(body)), headers);

  final int status;
  final List<int> body;
  final Map<String, List<String>> headers;
}

class _RateLimitedDownloadOneDriveApi extends _FakeOneDriveApi {
  final downloadStarted = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (request.method == 'GET' && request.uri.path.endsWith(':/content')) {
      if (!downloadStarted.isCompleted) downloadStarted.complete();
      return ResponseBody.fromBytes(
        const [],
        429,
        headers: {
          'retry-after': ['10'],
        },
      );
    }
    return super.fetch(request, requestStream, cancelFuture);
  }
}

class _FakeOneDriveApi implements HttpClientAdapter {
  final Map<String, _StoredFile> files = {};
  final Set<String> folders = {};
  final Map<String, _UploadSession> sessions = {};
  final List<RequestOptions> requests = [];
  final List<Map<String, Object>> additionalChildren = [];
  int metadataRateLimitsRemaining = 0;
  int metadataRateLimitResponses = 0;
  bool observedStalePrecondition = false;
  bool observedCreateConflict = false;
  bool appRootRequested = false;
  int appRootRequests = 0;
  int? appRootFailureStatus;
  String appRootFailureCode = 'serviceNotAvailable';
  String? appRootInnerFailureCode;
  String? appRootFailureMessage;
  int _revision = 0;
  int _session = 0;

  void putFile(String path, List<int> bytes) {
    _ensureFolders(path);
    files[path] = _StoredFile(Uint8List.fromList(bytes), _nextETag());
  }

  List<int>? fileBytes(String path) => files[path]?.bytes;

  void removeNamespace(String path) {
    files.removeWhere(
      (filePath, _) => filePath == path || filePath.startsWith('$path/'),
    );
    folders.removeWhere(
      (folderPath) => folderPath == path || folderPath.startsWith('$path/'),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions request,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(request);
    final response = await _handle(request, requestStream);
    return ResponseBody.fromBytes(
      response.body,
      response.status,
      headers: response.headers,
    );
  }

  Future<_FakeResponse> _handle(
    RequestOptions request,
    Stream<Uint8List>? requestStream,
  ) async {
    if (request.uri.host == 'signed.onedrive.test') {
      if (request.headers.keys.any(
        (key) => key.toLowerCase() == 'authorization',
      )) {
        return _FakeResponse.json(400, {'error': 'token leaked'});
      }
      if (request.method == 'PUT') {
        final session = sessions.remove(request.uri.path.split('/').last);
        if (session == null) return _FakeResponse.json(404, {});
        final bytes = await _requestBytes(request, requestStream);
        final stored = _StoredFile(bytes, _nextETag());
        files[session.path] = stored;
        return _FakeResponse.json(201, _item(session.path, stored));
      }
      if (request.method == 'GET' && request.uri.path == '/download') {
        final stored = files[request.uri.queryParameters['path']];
        return stored == null
            ? _FakeResponse.json(404, {})
            : _FakeResponse(200, stored.bytes);
      }
    }

    if (request.uri.path == '/v1.0/me/drive/special/approot') {
      if (request.method == 'GET') {
        appRootRequests++;
        final failureStatus = appRootFailureStatus;
        if (failureStatus != null) {
          return _FakeResponse.json(failureStatus, {
            'error': {
              'code': appRootFailureCode,
              if (appRootFailureMessage case final message?) 'message': message,
              if (appRootInnerFailureCode case final innerCode?)
                'innerError': {'code': innerCode},
            },
          });
        }
        appRootRequested = true;
        return _FakeResponse.json(200, {
          'id': 'approot-id',
          'name': 'Aaalice NAI Launcher',
          'eTag': '"approot"',
          'size': 0,
          'folder': <String, Object?>{},
          'specialFolder': {'name': 'approot'},
        });
      }
    }

    final graphPath = _graphItemPath(request.uri.path);
    if (request.method == 'POST' && request.uri.path.endsWith('/children')) {
      if (!appRootRequested) {
        return _FakeResponse.json(404, {
          'error': {'code': 'itemNotFound'},
        });
      }
      final body = jsonDecode(request.data as String) as Map<String, dynamic>;
      final name = body['name'] as String;
      final parent = graphPath ?? _folderPathForChildrenRequest(request.uri);
      if (parent == null) {
        return _FakeResponse.json(400, {
          'error': {'code': 'invalidRequest'},
        });
      }
      final path = parent.isEmpty ? name : '$parent/$name';
      if (folders.contains(path) || files.containsKey(path)) {
        return _FakeResponse.json(409, {
          'error': {'code': 'nameAlreadyExists'},
        });
      }
      folders.add(path);
      return _FakeResponse.json(201, {
        'id': _folderId(path),
        'name': name,
        'eTag': '"folder-$path"',
        'size': 0,
        'folder': <String, Object?>{},
      });
    }
    if (request.method == 'POST' &&
        request.uri.path.endsWith(':/createUploadSession')) {
      final path = graphPath!;
      final separator = path.lastIndexOf('/');
      final parent = separator <= 0 ? '' : path.substring(0, separator);
      if (parent.isNotEmpty && !folders.contains(parent)) {
        return _FakeResponse.json(404, {
          'error': {'code': 'itemNotFound'},
        });
      }
      final current = files[path];
      final expected = request.headers['If-Match']?.toString();
      if (expected != null && current?.eTag != expected) {
        observedStalePrecondition = true;
        return _FakeResponse.json(412, {
          'error': {'code': 'preconditionFailed'},
        });
      }
      final body = jsonDecode(request.data as String) as Map<String, dynamic>;
      final behavior =
          (body['item'] as Map)['@microsoft.graph.conflictBehavior'];
      if (expected == null && behavior == 'fail' && current != null) {
        observedCreateConflict = true;
        return _FakeResponse.json(409, {
          'error': {'code': 'nameAlreadyExists'},
        });
      }
      final id = '${++_session}';
      sessions[id] = _UploadSession(path);
      return _FakeResponse.json(200, {
        'uploadUrl': 'https://signed.onedrive.test/upload/$id',
      });
    }
    if (request.method == 'GET' && request.uri.path.endsWith(':/content')) {
      final path = graphPath!;
      final stored = files[path];
      if (stored == null) return _FakeResponse.json(404, {});
      if (request.headers['If-Match'] != stored.eTag) {
        return _FakeResponse.json(412, {});
      }
      return _FakeResponse(302, const [], {
        'location': [
          'https://signed.onedrive.test/download?path=${Uri.encodeQueryComponent(path)}',
        ],
      });
    }
    if (request.method == 'GET' && request.uri.path.endsWith(':/children')) {
      return _children(request, graphPath!);
    }
    if (request.method == 'GET' && graphPath != null) {
      if (metadataRateLimitsRemaining > 0) {
        metadataRateLimitsRemaining--;
        metadataRateLimitResponses++;
        return _FakeResponse.json(429, {}, const {
          'retry-after': ['0'],
        });
      }
      final stored = files[graphPath];
      if (stored != null) {
        return _FakeResponse.json(200, _item(graphPath, stored));
      }
      if (folders.contains(graphPath)) {
        return _FakeResponse.json(200, {
          'id': _folderId(graphPath),
          'name': graphPath.split('/').last,
          'eTag': '"folder-$graphPath"',
          'size': 0,
          'folder': <String, Object?>{},
        });
      }
      return _FakeResponse.json(404, {});
    }
    if (request.method == 'DELETE' && graphPath != null) {
      final existed =
          files.remove(graphPath) != null || folders.remove(graphPath);
      files.removeWhere((path, _) => path.startsWith('$graphPath/'));
      folders.removeWhere((path) => path.startsWith('$graphPath/'));
      return _FakeResponse(existed ? 204 : 404);
    }
    return _FakeResponse.json(500, {
      'unexpected': '${request.method} ${request.uri}',
    });
  }

  String? _folderPathForChildrenRequest(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length != 6 ||
        segments[0] != 'v1.0' ||
        segments[1] != 'me' ||
        segments[2] != 'drive' ||
        segments[3] != 'items' ||
        segments[5] != 'children') {
      return null;
    }
    final id = segments[4];
    if (id == 'approot-id') return '';
    if (!id.startsWith('folder-')) return null;
    return Uri.decodeComponent(id.substring('folder-'.length));
  }

  String _folderId(String path) => 'folder-${Uri.encodeComponent(path)}';

  _FakeResponse _children(RequestOptions request, String directory) {
    final names = files.entries.where((entry) {
      final parent = entry.key.contains('/')
          ? entry.key.substring(0, entry.key.lastIndexOf('/'))
          : '';
      return parent == directory;
    }).toList()..sort((first, second) => first.key.compareTo(second.key));
    final page = int.tryParse(request.uri.queryParameters['page'] ?? '') ?? 1;
    final start = (page - 1) * 2;
    final values = names
        .skip(start)
        .take(2)
        .map((entry) => _item(entry.key, entry.value))
        .toList();
    if (page == 1) values.addAll(additionalChildren);
    final hasNext = start + 2 < names.length;
    return _FakeResponse.json(200, {
      'value': values,
      if (hasNext)
        '@odata.nextLink':
            'https://graph.microsoft.test/v1.0/me/drive/special/approot:/${Uri.encodeComponent(directory)}:/children?page=${page + 1}',
    });
  }

  Map<String, Object> _item(String path, _StoredFile stored) => {
    'id': 'file-${Uri.encodeComponent(path)}',
    'name': path.split('/').last,
    'eTag': stored.eTag,
    'size': stored.bytes.length,
    'file': <String, Object?>{},
  };

  static String? graphItemPath(String uriPath) {
    const marker = '/v1.0/me/drive/special/approot:/';
    if (!uriPath.startsWith(marker)) return null;
    var value = uriPath.substring(marker.length);
    for (final suffix in [':/createUploadSession', ':/content', ':/children']) {
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }
    return Uri.decodeComponent(value);
  }

  String? _graphItemPath(String uriPath) => graphItemPath(uriPath);

  void _ensureFolders(String path) {
    final segments = path.split('/');
    for (var index = 1; index < segments.length; index++) {
      folders.add(segments.take(index).join('/'));
    }
  }

  String _nextETag() => '"e${++_revision}"';

  static Future<Uint8List> _requestBytes(
    RequestOptions request,
    Stream<Uint8List>? stream,
  ) async {
    if (request.data is Uint8List) return request.data as Uint8List;
    if (request.data is List<int>) {
      return Uint8List.fromList(request.data as List<int>);
    }
    final builder = BytesBuilder(copy: false);
    if (stream != null) {
      await for (final chunk in stream) {
        builder.add(chunk);
      }
    }
    return builder.takeBytes();
  }

  @override
  void close({bool force = false}) {}
}
