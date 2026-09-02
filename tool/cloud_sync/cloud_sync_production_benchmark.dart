import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/coordinator.dart';
import 'package:nai_launcher/core/cloud_sync/journal.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/core/cloud_sync/snapshot_transfer.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';
import 'package:nai_launcher/data/cloud_sync/app_cloud_sync_data_source.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync_data_adapter_registry.dart';
import 'package:nai_launcher/data/cloud_sync/portable_sync_record.dart';

const _oneGiB = 1024 * 1024 * 1024;
const _sourceChunkBytes = 64 * 1024;

Future<void> main(List<String> arguments) async {
  final output =
      _argument(arguments, '--output') ??
      'tool/.tmp/cloud-sync-benchmark/production-report.json';
  final ready = _argument(arguments, '--ready');
  final go = _argument(arguments, '--go');
  final logicalBytes = int.parse(
    _argument(arguments, '--bytes') ?? _oneGiB.toString(),
  );
  if (logicalBytes <= 0 || logicalBytes % _sourceChunkBytes != 0) {
    throw ArgumentError.value(logicalBytes, '--bytes');
  }

  final reportFile = File(output);
  final runRoot = Directory('${reportFile.parent.path}/production-run');
  if (await runRoot.exists()) await runRoot.delete(recursive: true);
  await runRoot.create(recursive: true);
  if (ready != null) {
    await File(ready).writeAsString('ready', flush: true);
  }
  if (go != null) {
    final goFile = File(go);
    while (!await goFile.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  final backend = _DiskBenchmarkBackend(Directory('${runRoot.path}/remote'));
  final producerAdapter = _BenchmarkAdapter(
    exportResource: true,
    logicalBytes: logicalBytes,
  );
  final producer = AppCloudSyncDataSource(
    registry: CloudSyncDataAdapterRegistry([producerAdapter]),
    root: Directory('${runRoot.path}/producer'),
  );
  final coordinator = SyncCoordinator(
    backend: backend,
    dataSource: producer,
    journalStore: JournalStore(File('${runRoot.path}/producer-journal.json')),
  );

  CloudSyncTelemetrySnapshot? uploadMetrics;
  late SyncOutcome upload;
  final uploadWatch = Stopwatch()..start();
  await CloudSyncTelemetry.trace('production-1gib-upload', () async {
    upload = await coordinator.synchronize(token: OperationToken());
  }, onComplete: (value) => uploadMetrics = value);
  uploadWatch.stop();
  final payloadCount = upload.snapshot.records.values
      .where((record) => record.payload != null)
      .length;
  if (producerAdapter.sourceOpens != 1 ||
      uploadMetrics!.hashPasses != payloadCount) {
    throw StateError(
      'production capture was not single pass: opens='
      '${producerAdapter.sourceOpens}, hashes=${uploadMetrics!.hashPasses}, '
      'payloads=$payloadCount',
    );
  }

  final consumerAdapter = _BenchmarkAdapter(
    exportResource: false,
    logicalBytes: logicalBytes,
  );
  final consumer = AppCloudSyncDataSource(
    registry: CloudSyncDataAdapterRegistry([consumerAdapter]),
    root: Directory('${runRoot.path}/consumer'),
  );
  final remoteHead = await backend.readHead();
  if (remoteHead == null) throw StateError('benchmark HEAD is missing');
  final head = SnapshotHead.decode(remoteHead.bytes);

  CloudSyncTelemetrySnapshot? downloadMetrics;
  final downloadWatch = Stopwatch()..start();
  await CloudSyncTelemetry.trace('production-1gib-download-apply', () async {
    final target = await CloudSnapshotTransfer(
      backend: backend,
      dataSource: consumer,
    ).downloadHead(head, OperationToken(), null);
    final local = await consumer.captureLocal();
    final recovery = await consumer.buildRecoveryPoint(
      local: local,
      target: target,
    );
    await consumer.stage(
      'production-download',
      target,
      recoveryPoint: recovery,
    );
    await consumer.apply('production-download');
    await consumer.saveBase(target, head.snapshotId);
    await consumer.completeOperation('production-download');
  }, onComplete: (value) => downloadMetrics = value);
  downloadWatch.stop();

  final rebuiltConsumer = AppCloudSyncDataSource(
    registry: CloudSyncDataAdapterRegistry([consumerAdapter]),
    root: Directory('${runRoot.path}/consumer'),
  );
  final durableBase = await rebuiltConsumer.readBase();
  if (durableBase == null || durableBase.records.length != payloadCount) {
    throw StateError('saved base did not survive data-source reconstruction');
  }

  if (consumerAdapter.appliedBytes != logicalBytes ||
      consumerAdapter.sequenceErrors != 0 ||
      downloadMetrics!.hashPasses != payloadCount) {
    throw StateError(
      'production restore failed: bytes=${consumerAdapter.appliedBytes}, '
      'sequenceErrors=${consumerAdapter.sequenceErrors}, '
      'hashes=${downloadMetrics!.hashPasses}, payloads=$payloadCount',
    );
  }

  final report = <String, Object?>{
    'schemaVersion': 2,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'scenario': 'production-1gib-roundtrip',
    'logicalBytes': logicalBytes,
    'defaultOneGiBExecuted': logicalBytes == _oneGiB,
    'productionPath': const [
      'AppCloudSyncDataSource.captureLocal',
      'VerifiedBlobStore',
      'SyncCoordinator/ResumableSnapshotUploader',
      'CloudSnapshotTransfer.materializeRemotePayload',
      'AppCloudSyncDataSource.stage/apply/saveBase',
    ],
    'sourceOpens': producerAdapter.sourceOpens,
    'payloadCount': payloadCount,
    'uploadedObjectBytes': backend.objectBytesWritten,
    'downloadedObjectBytes': backend.objectBytesRead,
    'appliedBytes': consumerAdapter.appliedBytes,
    'durableBaseRecords': durableBase.records.length,
    'uploadHashPasses': uploadMetrics!.hashPasses,
    'downloadHashPasses': downloadMetrics!.hashPasses,
    'uploadElapsedMs': uploadWatch.elapsedMilliseconds,
    'downloadApplyElapsedMs': downloadWatch.elapsedMilliseconds,
    'uploadTelemetry': _telemetry(uploadMetrics!),
    'downloadTelemetry': _telemetry(downloadMetrics!),
  };
  await reportFile.parent.create(recursive: true);
  await reportFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
    flush: true,
  );
  await runRoot.delete(recursive: true);
}

Map<String, Object?> _telemetry(CloudSyncTelemetrySnapshot value) => {
  'hashPasses': value.hashPasses,
  'payloadReads': value.payloadReads,
  'localBytesRead': value.localBytesRead,
  'localBytesWritten': value.localBytesWritten,
  'bytesRead': value.bytesRead,
  'bytesWritten': value.bytesWritten,
};

String? _argument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index < 0) return null;
  if (index + 1 >= arguments.length) throw ArgumentError('Missing $name');
  return arguments[index + 1];
}

final class _BenchmarkAdapter implements CloudSyncDataAdapter {
  _BenchmarkAdapter({required this.exportResource, required this.logicalBytes});

  final bool exportResource;
  final int logicalBytes;
  int sourceOpens = 0;
  int appliedBytes = 0;
  int sequenceErrors = 0;

  @override
  String get id => 'production-benchmark';

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    if (!exportResource) return;
    yield PortableSyncRecord(
      adapterId: id,
      id: 'one-gib-resource',
      kind: 'benchmark',
      data: const {'generated': true},
      resource: PortableSyncResource(
        relativePath: 'one-gib.bin',
        length: logicalBytes,
        openRead: () {
          sourceOpens++;
          if (sourceOpens > 1) {
            throw StateError('benchmark source was opened more than once');
          }
          return _deterministicBytes(logicalBytes);
        },
      ),
    );
  }

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {
    if (records.isNotEmpty &&
        (records.length != 1 || records.single.resource == null)) {
      throw StateError('benchmark preflight did not receive the resource');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    if (records.length != 1) {
      throw StateError('benchmark apply record count mismatch');
    }
    var offset = 0;
    await for (final chunk in records.single.resource!.openRead()) {
      for (
        var markerOffset = 0;
        markerOffset < chunk.length;
        markerOffset += _sourceChunkBytes
      ) {
        final expected = offset ~/ _sourceChunkBytes;
        if (chunk[markerOffset] != expected & 0xff ||
            chunk[markerOffset + 1] != (expected >> 8) & 0xff ||
            chunk[markerOffset + 2] != (expected >> 16) & 0xff ||
            chunk[markerOffset + 3] != (expected >> 24) & 0xff) {
          sequenceErrors++;
        }
        offset += _sourceChunkBytes;
      }
      appliedBytes += chunk.length;
    }
  }

  Stream<List<int>> _deterministicBytes(int length) async* {
    final chunks = length ~/ _sourceChunkBytes;
    for (var index = 0; index < chunks; index++) {
      final bytes = Uint8List(_sourceChunkBytes);
      bytes[0] = index & 0xff;
      bytes[1] = (index >> 8) & 0xff;
      bytes[2] = (index >> 16) & 0xff;
      bytes[3] = (index >> 24) & 0xff;
      yield bytes;
    }
  }
}

final class _DiskBenchmarkBackend
    implements
        CloudSyncBackend,
        CloudObjectInventoryBackend,
        ConcurrentCloudObjectUploadBackend {
  _DiskBenchmarkBackend(this.root);

  final Directory root;
  int _headRevision = 0;
  int objectBytesWritten = 0;
  int objectBytesRead = 0;

  Directory get _objects => Directory('${root.path}/objects');
  Directory get _snapshots => Directory('${root.path}/snapshots');
  File get _head => File('${root.path}/HEAD');

  @override
  int get maxConcurrentObjectUploads => 4;

  @override
  Future<CloudBackendCapability> testCapability() async =>
      const CloudBackendCapability(
        mode: CloudBackendMode.bidirectional,
        message: 'production benchmark disk backend',
      );

  @override
  Future<Set<String>> findExistingObjects(
    Map<String, int> expectedObjects,
  ) async {
    final found = <String>{};
    for (final entry in expectedObjects.entries) {
      final file = File('${_objects.path}/${entry.key}');
      if (await file.exists() && await file.length() == entry.value) {
        found.add(entry.key);
      }
    }
    return found;
  }

  @override
  Future<CloudHeadRead?> readHead() async {
    if (!await _head.exists()) return null;
    return CloudHeadRead(
      bytes: Uint8List.fromList(await _head.readAsBytes()),
      revision: _headRevision.toString(),
    );
  }

  @override
  Future<CloudObjectRead?> readObject(String objectId) async {
    final file = File('${_objects.path}/$objectId');
    if (!await file.exists()) return null;
    final bytes = Uint8List.fromList(await file.readAsBytes());
    objectBytesRead += bytes.length;
    return CloudObjectRead(bytes: bytes, revision: objectId);
  }

  @override
  Future<CloudObjectRead?> readSnapshotManifest(String snapshotId) async {
    final file = File('${_snapshots.path}/$snapshotId.json');
    if (!await file.exists()) return null;
    return CloudObjectRead(
      bytes: Uint8List.fromList(await file.readAsBytes()),
      revision: snapshotId,
    );
  }

  @override
  Future<CloudCommitResult> putObject(
    String objectId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    if (objectId != sha256) throw StateError('object identity mismatch');
    await _objects.create(recursive: true);
    final file = File('${_objects.path}/$objectId');
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: false);
      objectBytesWritten += bytes.length;
    }
    return CloudCommitResult(revision: objectId);
  }

  @override
  Future<CloudCommitResult> putSnapshotManifest(
    String snapshotId,
    Uint8List bytes, {
    required String sha256,
    bool payloadVerified = false,
  }) async {
    await _snapshots.create(recursive: true);
    final file = File('${_snapshots.path}/$snapshotId.json');
    if (!await file.exists()) await file.writeAsBytes(bytes, flush: true);
    return CloudCommitResult(revision: sha256);
  }

  @override
  Future<CloudCommitResult> commitHead(
    Uint8List bytes, {
    required String? expectedRevision,
  }) async {
    final current = await _head.exists() ? _headRevision.toString() : null;
    if (current != expectedRevision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'stale benchmark HEAD',
      );
    }
    await root.create(recursive: true);
    await _head.writeAsBytes(bytes, flush: true);
    _headRevision++;
    return CloudCommitResult(revision: _headRevision.toString());
  }

  @override
  Future<List<String>> listSnapshotIds({int limit = 20}) async {
    if (!await _snapshots.exists() || limit <= 0) return const [];
    final ids = await _snapshots
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .map((entity) => entity.uri.pathSegments.last.replaceAll('.json', ''))
        .toList();
    ids.sort((left, right) => right.compareTo(left));
    return ids.take(limit).toList(growable: false);
  }

  @override
  Future<void> deleteNamespace() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
