import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/github_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/google_drive_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/onedrive_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/backend/webdav_cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/bounded_transfer_scheduler.dart';
import 'package:nai_launcher/core/cloud_sync/data_source.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_uploader.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';

Future<void> main(List<String> args) => runCloudSyncBenchmark(args);

Future<void> runCloudSyncBenchmark(List<String> args) async {
  final includeOneGiB = args.contains('--include-1gib');
  final output =
      _argument(args, '--output') ??
      'tool/.tmp/cloud-sync-benchmark/report.synthetic.json';
  final results = <Map<String, Object?>>[];
  final providerProtocolSmoke = await _runProviderProtocolSmoke();
  final schedulerBudgets = <Map<String, Object?>>[];
  for (final limits in const [
    androidCloudTransferLimits,
    desktopCloudTransferLimits,
  ]) {
    schedulerBudgets.add(await _runSchedulerBudgetScenario(limits));
  }

  for (final count in const [1, 10, 100, 1000]) {
    for (final changed in {0, 1, count < 10 ? count : 10, count}) {
      results.add(
        await _runChangedObjectScenario(
          recordCount: count,
          changedCount: changed,
          payloadBytes: 256,
        ),
      );
    }
  }
  results.add(
    await _runChangedObjectScenario(
      recordCount: 25,
      changedCount: 25,
      payloadBytes: 4 * 1024 * 1024,
      label: '100MiB',
    ),
  );
  if (includeOneGiB) {
    results.add(
      await _runChangedObjectScenario(
        recordCount: 256,
        changedCount: 256,
        payloadBytes: 4 * 1024 * 1024,
        label: '1GiB',
      ),
    );
  }

  final report = <String, Object?>{
    'schemaVersion': 1,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'includesOneGiB': includeOneGiB,
    'providerProtocolSmoke': providerProtocolSmoke,
    'schedulerBudgets': schedulerBudgets,
    'results': results,
  };
  final file = File(output);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  stdout.writeln('Cloud-sync benchmark passed: ${file.path}');
}

String? _argument(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0) return null;
  if (index + 1 >= args.length) {
    throw ArgumentError('Missing value for $name');
  }
  return args[index + 1];
}

Future<List<Map<String, Object?>>> _runProviderProtocolSmoke() async {
  final cases =
      <
        ({String provider, CloudSyncBackend backend, _ProtocolAdapter adapter})
      >[];

  _ProtocolAdapter adapter(
    _ProtocolResponse Function(RequestOptions request) handler,
  ) => _ProtocolAdapter(handler);

  final githubAdapter = adapter((request) {
    final path = request.uri.path;
    if (path.endsWith('/branches/sync')) {
      return _ProtocolResponse.json(200, {
        'commit': {'sha': 'commit-sha'},
      });
    }
    if (path.endsWith('/git/commits/commit-sha')) {
      return _ProtocolResponse.json(200, {
        'tree': {'sha': 'tree-sha'},
      });
    }
    if (path.endsWith('/git/trees/tree-sha')) {
      return _ProtocolResponse.json(200, {
        'truncated': false,
        'tree': <Object?>[],
      });
    }
    throw StateError('Unexpected GitHub request: ${request.method} $path');
  });
  cases.add((
    provider: 'github',
    backend: GitHubCloudSyncBackend(
      owner: 'benchmark',
      repository: 'cloud-sync',
      branch: 'sync',
      token: 'benchmark-token',
      apiBaseUri: Uri.parse('https://github.benchmark/'),
      dio: Dio()..httpClientAdapter = githubAdapter,
    ),
    adapter: githubAdapter,
  ));

  final googleAdapter = adapter((request) {
    if (request.uri.path.endsWith('/drive/v3/files')) {
      return _ProtocolResponse.json(200, {'files': <Object?>[]});
    }
    throw StateError(
      'Unexpected Google Drive request: ${request.method} ${request.uri.path}',
    );
  });
  cases.add((
    provider: 'googleDrive',
    backend: GoogleDriveCloudSyncBackend(
      accessTokenProvider: () async => 'benchmark-token',
      namespace: 'benchmark',
      apiBaseUri: Uri.parse('https://google.benchmark/'),
      dio: Dio()..httpClientAdapter = googleAdapter,
    ),
    adapter: googleAdapter,
  ));

  final oneDriveAdapter = adapter((_) => const _ProtocolResponse(status: 404));
  cases.add((
    provider: 'oneDrive',
    backend: OneDriveCloudSyncBackend(
      accessTokenProvider: () async => 'benchmark-token',
      namespace: 'benchmark',
      graphBaseUri: Uri.parse('https://onedrive.benchmark/v1.0/'),
      dio: Dio()..httpClientAdapter = oneDriveAdapter,
    ),
    adapter: oneDriveAdapter,
  ));

  final webDavAdapter = adapter((_) => const _ProtocolResponse(status: 404));
  cases.add((
    provider: 'webDav',
    backend: WebDavCloudSyncBackend(
      baseUri: Uri.parse('https://webdav.benchmark/root/'),
      username: 'benchmark',
      password: 'benchmark',
      dio: Dio()..httpClientAdapter = webDavAdapter,
    ),
    adapter: webDavAdapter,
  ));

  final evidence = <Map<String, Object?>>[];
  for (final value in cases) {
    final head = await value.backend.readHead();
    if (head != null || value.adapter.requests.isEmpty) {
      throw StateError('${value.provider} protocol smoke did not read HEAD');
    }
    evidence.add({
      'provider': value.provider,
      'profile': 'protocolFake',
      'operation': 'readHead',
      'requestCount': value.adapter.requests.length,
      'requests': [for (final request in value.adapter.requests) request.json],
      'ioReadBytes': value.adapter.responseBytes,
      'ioWrittenBytes': value.adapter.requestBytes,
    });
  }
  return evidence;
}

Future<Map<String, Object?>> _runSchedulerBudgetScenario(
  CloudTransferLimits limits,
) async {
  const itemBytes = maxCloudTransferItemBytes;
  final gate = Completer<void>();
  var peakItems = 0;
  var peakReservedBytes = 0;
  final scheduler = BoundedTransferScheduler(
    maxConcurrentItems: limits.maxConcurrentItems,
    maxBytesInFlight: limits.maxBytesInFlight,
  );
  final future = scheduler.run<int, void>(
    items: [
      for (var index = 0; index < 8; index++)
        BoundedTransferItem(value: index, bytes: itemBytes),
    ],
    token: OperationToken(),
    transfer: (_) => gate.future,
    onReservationChanged: (activeItems, reservedBytes) {
      if (activeItems > peakItems) peakItems = activeItems;
      if (reservedBytes > peakReservedBytes) {
        peakReservedBytes = reservedBytes;
      }
    },
  );
  await Future<void>.delayed(Duration.zero);
  final expectedPeakBytes =
      limits.maxConcurrentItems * maxCloudTransferItemBytes;
  if (peakItems != limits.maxConcurrentItems ||
      peakReservedBytes != expectedPeakBytes ||
      peakReservedBytes > limits.maxBytesInFlight) {
    throw StateError(
      '${limits.profile.name} production scheduler limits mismatch: '
      'items=$peakItems bytes=$peakReservedBytes budget=${limits.maxBytesInFlight}',
    );
  }
  gate.complete();
  await future;
  return {
    'profile': limits.profile.name,
    'itemCount': 8,
    'itemBytes': itemBytes,
    'logicalIoBytes': 8 * itemBytes,
    'maxConcurrentItems': limits.maxConcurrentItems,
    'budgetBytes': limits.maxBytesInFlight,
    'peakReservedItems': peakItems,
    'peakReservedBytes': peakReservedBytes,
  };
}

Future<Map<String, Object?>> _runChangedObjectScenario({
  required int recordCount,
  required int changedCount,
  required int payloadBytes,
  String? label,
}) async {
  final backend = _BenchmarkBackend();
  final dataSource = _BenchmarkDataSource();
  final uploader = ResumableSnapshotUploader(
    backend: backend,
    dataSource: dataSource,
    now: DateTime.now,
  );
  final baseline = await _snapshot(recordCount, payloadBytes, const {});
  await _upload(
    uploader: uploader,
    backend: backend,
    dataSource: dataSource,
    snapshot: baseline.snapshot,
    operationId: 'baseline-$recordCount-$payloadBytes',
  );

  final changedIds = {for (var index = 0; index < changedCount; index++) index};
  final prepareWatch = Stopwatch()..start();
  final candidate = await _snapshot(recordCount, payloadBytes, changedIds);
  prepareWatch.stop();
  if (candidate.sourceReads != recordCount ||
      candidate.sourceHashPasses != recordCount) {
    throw StateError(
      'Preparation must read and hash each source exactly once: '
      'reads=${candidate.sourceReads}, hashes=${candidate.sourceHashPasses}, '
      'N=$recordCount',
    );
  }
  final putsBefore = backend.objectPutCalls;
  final callsBefore = backend.logicalCalls;
  backend.resetPeakTransferBytes();
  CloudSyncTelemetrySnapshot? metrics;
  final watch = Stopwatch()..start();
  await CloudSyncTelemetry.trace(
    'benchmark-$recordCount-$changedCount-$payloadBytes',
    () => _upload(
      uploader: uploader,
      backend: backend,
      dataSource: dataSource,
      snapshot: candidate.snapshot,
      operationId: 'candidate-$recordCount-$changedCount-$payloadBytes',
    ),
    onComplete: (value) => metrics = value,
  );
  watch.stop();
  final uploaded = backend.objectPutCalls - putsBefore;
  final logicalCalls = backend.logicalCalls - callsBefore;
  if (uploaded != changedCount) {
    throw StateError(
      'Expected $changedCount changed object writes, observed $uploaded '
      '(N=$recordCount, bytes=$payloadBytes)',
    );
  }
  if (logicalCalls != changedCount + 3) {
    throw StateError(
      'Expected C + 3 logical backend calls, observed $logicalCalls '
      '(N=$recordCount, C=$changedCount)',
    );
  }
  if (backend.peakTransferBytes > defaultCloudTransferBytesInFlight) {
    throw StateError(
      'Transfer byte budget exceeded: ${backend.peakTransferBytes}',
    );
  }
  if (metrics!.payloadReads != changedCount) {
    throw StateError(
      'Expected each changed payload to be read once: '
      'expected=$changedCount actual=${metrics!.payloadReads}',
    );
  }
  if (metrics!.hashPasses != 0) {
    throw StateError(
      'Verified prepared payloads must not be hashed again during transfer: '
      'actual=${metrics!.hashPasses}',
    );
  }

  return {
    'label': label ?? 'N=$recordCount/C=$changedCount',
    'recordCount': recordCount,
    'changedCount': changedCount,
    'payloadBytes': payloadBytes,
    'logicalBytes': recordCount * payloadBytes,
    'prepareElapsedMs': prepareWatch.elapsedMilliseconds,
    'transferElapsedMs': watch.elapsedMilliseconds,
    'objectUploads': uploaded,
    'logicalBackendCalls': logicalCalls,
    'peakTransferBytes': backend.peakTransferBytes,
    'sourceReads': candidate.sourceReads,
    'sourceHashPasses': candidate.sourceHashPasses,
    'payloadReads': metrics!.payloadReads,
    'hashPasses': metrics!.hashPasses,
    'localBytesRead': metrics!.localBytesRead,
    'checkpoints': dataSource.checkpoints,
  };
}

Future<_PreparedBenchmarkSnapshot> _snapshot(
  int recordCount,
  int payloadBytes,
  Set<int> changed,
) async {
  final records = <CloudSyncRecord>[];
  var sourceReads = 0;
  var sourceHashPasses = 0;
  for (var index = 0; index < recordCount; index++) {
    final revision = changed.contains(index) ? 1 : 0;
    sourceReads++;
    sourceHashPasses++;
    final digest = await sha256
        .bind(_payloadStream(index, revision, payloadBytes))
        .first;
    records.add(
      CloudSyncRecord(
        id: 'record-$index',
        kind: 'resource',
        binary: true,
        deleted: false,
        payload: _BenchmarkVerifiedPayload(
          length: payloadBytes,
          sha256: digest.toString(),
          openRead: () => _payloadStream(index, revision, payloadBytes),
        ),
      ),
    );
  }
  return _PreparedBenchmarkSnapshot(
    snapshot: CloudSyncSnapshotData(records),
    sourceReads: sourceReads,
    sourceHashPasses: sourceHashPasses,
  );
}

final class _BenchmarkVerifiedPayload extends CloudSyncPayload
    implements VerifiedCloudSyncPayload {
  _BenchmarkVerifiedPayload({
    required super.length,
    required super.sha256,
    required super.openRead,
  });
}

final class _PreparedBenchmarkSnapshot {
  const _PreparedBenchmarkSnapshot({
    required this.snapshot,
    required this.sourceReads,
    required this.sourceHashPasses,
  });

  final CloudSyncSnapshotData snapshot;
  final int sourceReads;
  final int sourceHashPasses;
}

Stream<List<int>> _payloadStream(int index, int revision, int length) async* {
  const chunkSize = 64 * 1024;
  var offset = 0;
  while (offset < length) {
    final remaining = length - offset;
    final size = remaining < chunkSize ? remaining : chunkSize;
    final chunk = Uint8List(size);
    for (var byteIndex = 0; byteIndex < size; byteIndex++) {
      chunk[byteIndex] =
          (index * 31 + revision * 17 + offset + byteIndex) & 0xff;
    }
    if (offset == 0 && size >= 5) {
      chunk[0] = index & 0xff;
      chunk[1] = (index >> 8) & 0xff;
      chunk[2] = (index >> 16) & 0xff;
      chunk[3] = (index >> 24) & 0xff;
      chunk[4] = revision;
    }
    yield chunk;
    offset += size;
  }
}

Future<void> _upload({
  required ResumableSnapshotUploader uploader,
  required _BenchmarkBackend backend,
  required _BenchmarkDataSource dataSource,
  required CloudSyncSnapshotData snapshot,
  required String operationId,
}) async {
  var journal = SyncJournal(
    operationId: operationId,
    operation: JournalOperation.uploadLocal,
    phase: JournalPhase.prepared,
    updatedAt: DateTime.now().toUtc(),
    snapshotId: 'snapshot-$operationId',
    targetFingerprint: List.filled(64, '0').join(),
    expectedRevision: backend.headRevision,
    uploadRequired: true,
  );
  journal = await uploader.resume(
    journal: journal,
    snapshot: snapshot,
    token: OperationToken(),
    checkpoint: (value) async {
      dataSource.checkpoints++;
      journal = value;
    },
  );
  if (journal.phase != JournalPhase.savingBase) {
    throw StateError('Uploader stopped at ${journal.phase.name}');
  }
}

final class _BenchmarkBackend
    implements
        CloudSyncBackend,
        CloudObjectInventoryBackend,
        ConcurrentCloudObjectUploadBackend {
  final Map<String, int> objects = {};
  final Map<String, Uint8List> manifests = {};
  Uint8List? head;
  String? headRevision;
  int objectPutCalls = 0;
  int logicalCalls = 0;
  int peakTransferBytes = 0;
  int _activeTransferBytes = 0;
  int _revision = 0;

  void resetPeakTransferBytes() => peakTransferBytes = _activeTransferBytes;

  @override
  int get maxConcurrentObjectUploads => 8;

  @override
  Future<CloudObjectInventoryResult> findExistingObjects(
    Map<String, int> expectedObjects, {
    Map<String, String> trustedRevisions = const {},
    OperationToken? token,
    CloudObjectInventoryProgressCallback? onProgress,
  }) async {
    logicalCalls++;
    final found = {
      for (final entry in expectedObjects.entries)
        if (objects[entry.key] == entry.value) entry.key,
    };
    return CloudObjectInventoryResult(
      existingObjectIds: found,
      verifiedRevisions: {for (final id in found) id: id},
    );
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    if (sha256 != objectId || (!payloadVerified && digest(bytes) != objectId)) {
      throw StateError('Object identity mismatch');
    }
    final existing = objects[objectId];
    if (existing != null && existing != bytes.length) {
      throw StateError('Immutable object conflict');
    }
    objectPutCalls++;
    logicalCalls++;
    _activeTransferBytes += bytes.length;
    if (_activeTransferBytes > peakTransferBytes) {
      peakTransferBytes = _activeTransferBytes;
    }
    try {
      await Future<void>.delayed(Duration.zero);
      objects[objectId] = bytes.length;
      return CloudCommitResult(revision: objectId);
    } finally {
      _activeTransferBytes -= bytes.length;
    }
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    if (!payloadVerified && digest(bytes) != sha256) {
      throw StateError('Manifest identity mismatch');
    }
    logicalCalls++;
    manifests[snapshotId] = Uint8List.fromList(bytes);
    return CloudCommitResult(revision: sha256);
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    if (expectedRevision != headRevision) throw StateError('Stale HEAD');
    logicalCalls++;
    head = Uint8List.fromList(bytes);
    headRevision = 'r${++_revision}';
    return CloudCommitResult(revision: headRevision!);
  }

  @override
  Future<CloudHeadRead?> readHead() async => head == null
      ? null
      : CloudHeadRead(
          bytes: Uint8List.fromList(head!),
          revision: headRevision!,
        );

  @override
  Future<CloudObjectRead?> readObject(String objectId) async => null;

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) async {
    final bytes = manifests[snapshotId];
    return bytes == null
        ? null
        : CloudObjectRead(
            bytes: Uint8List.fromList(bytes),
            revision: digest(bytes),
          );
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async =>
      manifests.keys.take(limit).toList();

  @override
  Future<CloudBackendCapability> testCapability() async =>
      const CloudBackendCapability(
        mode: CloudBackendMode.bidirectional,
        message: 'benchmark',
      );

  @override
  Future<void> deleteNamespace() async {
    objects.clear();
    manifests.clear();
    head = null;
    headRevision = null;
  }
}

final class _BenchmarkDataSource implements CloudSyncDataSource {
  final Map<String, Map<String, Uint8List>> artifacts = {};
  int checkpoints = 0;

  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async {
    artifacts.putIfAbsent(operationId, () => {})[name] = Uint8List.fromList(
      bytes,
    );
  }

  @override
  Future<List<int>?> readUploadArtifact(
    String operationId,
    String name,
  ) async => artifacts[operationId]?[name];

  @override
  Future<void> deleteUploadArtifact(String operationId, String name) async =>
      artifacts[operationId]?.remove(name);

  @override
  Future<CloudSyncSnapshotData> captureLocal() =>
      throw UnsupportedError('benchmark');
  @override
  Future<CloudSyncSnapshotData?> readBase() =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> stage(
    String operationId,
    CloudSyncSnapshotData snapshot, {
    CloudSyncSnapshotData? recoveryPoint,
  }) => throw UnsupportedError('benchmark');
  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<String> stagedFingerprint(String operationId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> apply(String operationId) => throw UnsupportedError('benchmark');
  @override
  Future<void> rollback(String operationId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> rollbackForRecovery(String operationId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> restoreBaseForRecovery(String operationId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> saveBase(CloudSyncSnapshotData snapshot, String snapshotId) =>
      throw UnsupportedError('benchmark');
  @override
  Future<void> completeOperation(String operationId) async =>
      artifacts.remove(operationId);
}

String digest(List<int> bytes) => sha256.convert(bytes).toString();

final class _ProtocolResponse {
  const _ProtocolResponse({
    required this.status,
    this.body = const <int>[],
    this.headers = const {},
  });

  factory _ProtocolResponse.json(int status, Object value) => _ProtocolResponse(
    status: status,
    body: Uint8List.fromList(utf8.encode(jsonEncode(value))),
    headers: const {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  final int status;
  final List<int> body;
  final Map<String, List<String>> headers;
}

final class _ProtocolRequestEvidence {
  const _ProtocolRequestEvidence({
    required this.method,
    required this.path,
    required this.status,
    required this.requestBytes,
    required this.responseBytes,
  });

  final String method;
  final String path;
  final int status;
  final int requestBytes;
  final int responseBytes;

  Map<String, Object?> get json => {
    'method': method,
    'path': path,
    'status': status,
    'requestBytes': requestBytes,
    'responseBytes': responseBytes,
  };
}

final class _ProtocolAdapter implements HttpClientAdapter {
  _ProtocolAdapter(this._handler);

  final _ProtocolResponse Function(RequestOptions request) _handler;
  final List<_ProtocolRequestEvidence> requests = [];

  int get requestBytes =>
      requests.fold(0, (total, request) => total + request.requestBytes);
  int get responseBytes =>
      requests.fold(0, (total, request) => total + request.responseBytes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    var streamedRequestBytes = 0;
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        streamedRequestBytes += chunk.length;
      }
    }
    final response = _handler(options);
    requests.add(
      _ProtocolRequestEvidence(
        method: options.method,
        path: options.uri.path,
        status: response.status,
        requestBytes: streamedRequestBytes,
        responseBytes: response.body.length,
      ),
    );
    return ResponseBody.fromBytes(
      response.body,
      response.status,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}
