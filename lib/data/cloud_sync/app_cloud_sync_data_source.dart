import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';
import '../../core/cloud_sync/record_merge.dart';
import 'cloud_sync_data_adapter.dart';
import 'cloud_sync_data_adapter_registry.dart';
import 'cloud_sync_operation_storage.dart';
import 'portable_record_codec.dart';
import 'portable_sync_record.dart';

class AppCloudSyncDataSource
    implements
        CloudSyncDataSource,
        CloudSyncPayloadMaterializer,
        CloudSyncConflictRecordCopier {
  AppCloudSyncDataSource({
    required CloudSyncDataAdapterRegistry registry,
    required Directory root,
    this.chunkSize = maxCloudRecordPayloadBytes,
  }) : _registry = registry,
       _root = root {
    if (chunkSize <= 0 || chunkSize > maxCloudRecordPayloadBytes) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'Must fit inside one encrypted cloud object',
      );
    }
  }

  final CloudSyncDataAdapterRegistry _registry;
  final Directory _root;
  final int chunkSize;

  PortableRecordCodec get _codec => PortableRecordCodec(stableId: _stableId);

  Directory get _base => Directory('${_root.path}/base');
  Directory get _capture => Directory('${_root.path}/capture');
  Directory get _remote => Directory('${_root.path}/remote-materialized');
  CloudSyncOperationStorage get _operations => CloudSyncOperationStorage(_root);
  Directory _stage(String id) => _operations.stage(id);
  Directory _recovery(String id) => _operations.recovery(id);

  @override
  Future<CloudSyncSnapshotData> captureLocal() async {
    if (await _capture.exists()) await _capture.delete(recursive: true);
    await _capture.create(recursive: true);
    final records = <CloudSyncRecord>[];
    final currentIds = <String>{};
    await for (final portable in _registry.exportRecords()) {
      final metadata = await _encodePortable(portable, records);
      currentIds.add(metadata.id);
      records.add(metadata);
    }
    final base = await readBase();
    if (base != null) {
      final decodedBase = await _codec.decode(base);
      for (final record in base.records.values) {
        if (record.kind != 'metadata') continue;
        final portable = decodedBase.records[record.id]!;
        if (!_registry.adapterIds.contains(portable.adapterId)) {
          records.add(record);
          for (final chunkId in decodedBase.metadataChunks[record.id]!) {
            records.add(base.records[chunkId]!);
          }
          continue;
        }
        if (currentIds.contains(record.id)) {
          continue;
        }
        records.add(
          await _encodePortable(
            PortableSyncRecord(
              adapterId: portable.adapterId,
              id: portable.id,
              kind: portable.kind,
              data: portable.data,
              deleted: true,
            ),
            records,
          ),
        );
      }
    }
    return CloudSyncSnapshotData(records);
  }

  Future<CloudSyncRecord> _encodePortable(
    PortableSyncRecord record,
    List<CloudSyncRecord> output,
  ) async {
    final stableId = _stableId(record.adapterId, record.id);
    final chunkIds = <String>[];
    var length = 0;
    Digest? resourceDigest;
    final digestSink = sha256.startChunkedConversion(
      ChunkedConversionSink.withCallback((values) {
        resourceDigest = values.single;
      }),
    );
    if (record.resource != null && !record.deleted) {
      var pending = BytesBuilder(copy: false);
      var index = 0;
      await for (final input in record.resource!.openRead()) {
        digestSink.add(input);
        var offset = 0;
        while (offset < input.length) {
          final take = (chunkSize - pending.length).clamp(
            0,
            input.length - offset,
          );
          pending.add(input.sublist(offset, offset + take));
          offset += take;
          length += take;
          if (pending.length == chunkSize) {
            chunkIds.add(
              await _writeCaptureChunk(
                stableId,
                index++,
                pending.takeBytes(),
                output,
              ),
            );
            pending = BytesBuilder(copy: false);
          }
        }
      }
      if (pending.length != 0) {
        chunkIds.add(
          await _writeCaptureChunk(
            stableId,
            index,
            pending.takeBytes(),
            output,
          ),
        );
      }
      if (length != record.resource!.length) {
        throw const CloudFormatException('portable resource length mismatch');
      }
    }
    digestSink.close();
    final metadata = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'adapterId': record.adapterId,
          'portableId': record.id,
          'kind': record.kind,
          'data': record.data,
          'deleted': record.deleted,
          'resource': record.resource == null
              ? null
              : {
                  'path': record.resource!.relativePath,
                  'mediaType': record.resource!.mediaType,
                  'length': length,
                  'sha256': resourceDigest.toString(),
                  'chunks': chunkIds,
                },
        }),
      ),
    );
    return CloudSyncRecord(
      id: stableId,
      kind: 'metadata',
      binary: record.resource != null,
      deleted: record.deleted,
      bytes: metadata,
    );
  }

  Future<String> _writeCaptureChunk(
    String stableId,
    int index,
    Uint8List bytes,
    List<CloudSyncRecord> output,
  ) async {
    final id = '$stableId.c$index';
    final file = File('${_capture.path}/$id.payload');
    await file.writeAsBytes(bytes, flush: true);
    output.add(
      CloudSyncRecord(
        id: id,
        kind: 'resource',
        binary: true,
        deleted: false,
        payload: CloudSyncPayload(
          length: bytes.length,
          sha256: sha256.convert(bytes).toString(),
          openRead: file.openRead,
        ),
      ),
    );
    return id;
  }

  @override
  Future<CloudSyncSnapshotData?> readBase() => _operations.readSnapshot(_base);

  @override
  Future<void> beginRemoteMaterialization(String snapshotId) async {
    if (await _remote.exists()) await _remote.delete(recursive: true);
    await _remote.create(recursive: true);
  }

  @override
  Future<CloudSyncRecord> materializeRemoteRecord(
    CloudSyncRecord record,
  ) async {
    final bytes = await record.readBytes();
    if (bytes == null) return record;
    final file = File('${_remote.path}/${record.id}.payload');
    await file.writeAsBytes(bytes, flush: true);
    return CloudSyncRecord(
      id: record.id,
      kind: record.kind,
      binary: record.binary,
      deleted: record.deleted,
      payload: CloudSyncPayload(
        length: bytes.length,
        sha256: record.payload!.sha256,
        openRead: file.openRead,
      ),
    );
  }

  @override
  Future<void> stage(String operationId, CloudSyncSnapshotData snapshot) async {
    // Decode and validate the complete graph before writing staging or a
    // recovery point. No adapter has been allowed to mutate at this point.
    await _codec.decode(snapshot);
    await _operations.writeSnapshot(_stage(operationId), snapshot);
    final local = await captureLocal();
    final recovery = <CloudSyncRecord>[...local.records.values];
    final decodedTarget = await _codec.decode(snapshot);
    for (final target in snapshot.records.values) {
      if (target.kind != 'metadata' || local.records.containsKey(target.id)) {
        continue;
      }
      final portable = decodedTarget.records[target.id]!;
      recovery.add(
        await _encodePortable(
          PortableSyncRecord(
            adapterId: portable.adapterId,
            id: portable.id,
            kind: portable.kind,
            data: portable.data,
            deleted: true,
          ),
          recovery,
        ),
      );
    }
    await _operations.writeSnapshot(
      _recovery(operationId),
      CloudSyncSnapshotData(recovery),
    );
  }

  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) async {
    final snapshot = await _operations.readSnapshot(_stage(operationId));
    if (snapshot == null) {
      throw const CloudFormatException('staged target is not READY');
    }
    await _codec.decode(snapshot);
    return snapshot;
  }

  @override
  Future<String> stagedFingerprint(String operationId) async {
    await readStaged(operationId);
    return _operations.fingerprint(operationId);
  }

  @override
  Future<void> apply(String operationId) async {
    final snapshot = await _operations.readSnapshot(_stage(operationId));
    if (snapshot == null) throw StateError('Staged cloud snapshot is missing');
    await _registry.apply(await _portableRecords(snapshot));
  }

  Future<List<PortableSyncRecord>> _portableRecords(
    CloudSyncSnapshotData snapshot,
  ) async {
    final decoded = await _codec.decode(snapshot);
    return decoded.records.values
        .where((record) => _registry.adapterIds.contains(record.adapterId))
        .toList();
  }

  @override
  Future<List<CloudSyncRecord>> copyConflictRecord({
    required CloudSyncRecord source,
    required String requestedId,
    required CloudSyncSnapshotData sourceSnapshot,
  }) async {
    if (source.kind != 'metadata') {
      throw const CloudFormatException('only metadata can own a conflict copy');
    }
    final decoded = await _codec.decode(sourceSnapshot);
    final portable = decoded.records[source.id];
    if (portable == null) {
      throw const CloudFormatException('conflict metadata is missing');
    }
    final registeredAdapter = _registry.adapter(portable.adapterId);
    if (registeredAdapter is! CloudSyncConflictCopyAdapter) {
      throw CloudFormatException(
        'adapter ${portable.adapterId} cannot keep both records',
      );
    }
    final adapter = registeredAdapter as CloudSyncConflictCopyAdapter;
    final suffix = sha256
        .convert(utf8.encode(requestedId))
        .toString()
        .substring(0, 12);
    final reserve = '-copy-$suffix'.length;
    final prefix = portable.id.length > 191 - reserve
        ? portable.id.substring(0, 191 - reserve)
        : portable.id;
    final copy = adapter.copyForConflict(
      portable,
      newPortableId: '$prefix-copy-$suffix',
    );
    final output = <CloudSyncRecord>[];
    output.add(await _encodePortable(copy, output));
    // captureLocal replaces its streaming scratch directory. Conflict copies
    // are bounded to individual cloud chunks and must survive a subsequent
    // recovery capture performed by stage().
    return Future.wait(
      output.map((record) async {
        final bytes = await record.readBytes();
        return CloudSyncRecord(
          id: record.id,
          kind: record.kind,
          binary: record.binary,
          deleted: record.deleted,
          bytes: bytes,
        );
      }),
    );
  }

  @override
  Future<CloudSyncSnapshotData> finalizeMergedSnapshot(
    CloudSyncSnapshotData snapshot,
  ) async {
    final decoded = await _codec.decode(snapshot, rejectOrphans: false);
    final keep = <String>{
      ...decoded.records.keys,
      ...decoded.metadataChunks.values.expand((ids) => ids),
    };
    return CloudSyncSnapshotData(
      snapshot.records.values.where((record) => keep.contains(record.id)),
    );
  }

  @override
  Future<void> rollback(String operationId) async {
    await rollbackForRecovery(operationId);
    await _operations.deleteOperation(operationId);
  }

  @override
  Future<void> rollbackForRecovery(String operationId) async {
    final recovery = await _operations.readSnapshot(_recovery(operationId));
    if (recovery != null) {
      await _registry.apply(await _portableRecords(recovery));
    }
  }

  @override
  Future<void> saveBase(CloudSyncSnapshotData snapshot, String snapshotId) =>
      _operations.writeSnapshot(_base, snapshot, snapshotId: snapshotId);

  @override
  Future<void> writeUploadArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) => _operations.writeArtifact(operationId, name, bytes);

  @override
  Future<List<int>?> readUploadArtifact(String operationId, String name) =>
      _operations.readArtifact(operationId, name);

  @override
  Future<void> deleteUploadArtifact(String operationId, String name) =>
      _operations.deleteArtifact(operationId, name);

  @override
  Future<void> completeOperation(String operationId) =>
      _operations.deleteOperation(operationId);

  String _stableId(String adapterId, String id) =>
      'r-${sha256.convert(utf8.encode('$adapterId\u0000$id'))}';
}
