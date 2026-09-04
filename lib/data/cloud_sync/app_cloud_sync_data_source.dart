import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';
import '../../core/cloud_sync/record_merge.dart';
import '../../core/cloud_sync/telemetry_log.dart';
import 'cloud_sync_data_adapter.dart';
import 'cloud_sync_data_adapter_registry.dart';
import 'cloud_sync_operation_storage.dart';
import 'portable_record_codec.dart';
import 'verified_blob_store.dart';
import 'portable_sync_record.dart';

class AppCloudSyncDataSource
    implements
        CloudSyncDataSource,
        CloudSyncPayloadMaterializer,
        CloudSyncLocalPayloadResolver,
        CloudSyncPreviewStore,
        CloudObjectVerificationDataSource,
        CloudSyncRecoveryPointBuilder,
        CloudSyncConflictRecordCopier {
  AppCloudSyncDataSource({
    required CloudSyncDataAdapterRegistry registry,
    required Directory root,
    this.chunkSize = maxCloudRecordPayloadBytes,
  }) : _registry = registry,
       _root = root,
       _blobs = VerifiedBlobStore(root) {
    if (chunkSize <= 0 || chunkSize > maxCloudRecordPayloadBytes) {
      throw ArgumentError.value(
        chunkSize,
        'chunkSize',
        'Must fit inside one cloud object',
      );
    }
    _operations = CloudSyncOperationStorage(root, _blobs);
  }

  final CloudSyncDataAdapterRegistry _registry;
  final Directory _root;
  final int chunkSize;
  final VerifiedBlobStore _blobs;
  late final CloudSyncOperationStorage _operations;
  final Expando<bool> _preparedSnapshots = Expando<bool>();
  final Expando<Future<DecodedPortableSnapshot>> _decodedSnapshots =
      Expando<Future<DecodedPortableSnapshot>>();
  final Map<String, CloudSyncSnapshotData> _stagedSnapshots = {};
  final Map<String, CloudSyncSnapshotData> _recoverySnapshots = {};
  Future<void>? _startupMaintenance;

  static const _maxVerificationCacheBytes = 16 * 1024 * 1024;
  static const _maxVerificationCacheEntries = 100000;

  PortableRecordCodec get _codec => PortableRecordCodec(stableId: _stableId);

  Future<DecodedPortableSnapshot> _decodeSnapshot(
    CloudSyncSnapshotData snapshot,
  ) => _decodedSnapshots[snapshot] ??= _codec.decode(snapshot);

  Directory get _base => Directory('${_root.path}/base');
  File get _verificationCache =>
      File('${_root.path}/verified-remote-objects.json');
  Directory _stage(String id) => _operations.stage(id);
  Directory _recovery(String id) => _operations.recovery(id);
  Directory _baseRecovery(String id) => _operations.baseRecovery(id);
  Directory get _syncPreview => Directory('${_root.path}/previews/sync');
  Directory _restorePreview(String id) {
    _validatePreviewId(id);
    return Directory('${_root.path}/previews/restore/$id');
  }

  @override
  Future<void> saveSyncPreview(CloudSyncPreparedPreview preview) =>
      _exclusivePreview(() => _saveSyncPreview(preview));

  Future<void> _saveSyncPreview(CloudSyncPreparedPreview preview) async {
    final root = _syncPreview;
    final metadata = File('${root.path}/preview.json');
    if (await metadata.exists()) await metadata.delete();
    await _operations.writeSnapshot(
      Directory('${root.path}/local'),
      preview.local,
    );
    await _operations.writeSnapshot(
      Directory('${root.path}/base'),
      preview.base,
    );
    final remote = preview.remote;
    if (remote != null) {
      await _operations.writeSnapshot(Directory('${root.path}/remote'), remote);
    } else {
      final remoteDirectory = Directory('${root.path}/remote');
      if (await remoteDirectory.exists()) {
        await remoteDirectory.delete(recursive: true);
      }
    }
    await _writePreviewMetadata(metadata, {
      'version': 1,
      'remoteRevision': preview.remoteRevision,
      'remoteHead': preview.remoteHead == null
          ? null
          : base64Encode(preview.remoteHead!.encode()),
      'hasRemote': remote != null,
    });
  }

  @override
  Future<CloudSyncPreparedPreview?> readSyncPreview() =>
      _exclusivePreview(_readSyncPreview);

  Future<CloudSyncPreparedPreview?> _readSyncPreview() async {
    final root = _syncPreview;
    final metadata = await _readPreviewMetadata(
      File('${root.path}/preview.json'),
    );
    if (metadata == null) return null;
    if (metadata.keys.toSet().difference({
          'version',
          'remoteRevision',
          'remoteHead',
          'hasRemote',
        }).isNotEmpty ||
        metadata['version'] != 1 ||
        metadata['remoteRevision'] is! String? ||
        metadata['remoteHead'] is! String? ||
        metadata['hasRemote'] is! bool) {
      throw const CloudFormatException('invalid sync preview metadata');
    }
    final hasRemote = metadata['hasRemote'] as bool;
    final headText = metadata['remoteHead'] as String?;
    final head = headText == null
        ? null
        : SnapshotHead.decode(base64Decode(headText));
    if (hasRemote != (head != null)) {
      throw const CloudFormatException('invalid sync preview remote state');
    }
    final local = await _operations.readSnapshot(
      Directory('${root.path}/local'),
    );
    final base = await _operations.readSnapshot(Directory('${root.path}/base'));
    final remote = hasRemote
        ? await _operations.readSnapshot(Directory('${root.path}/remote'))
        : null;
    if (local == null || base == null || (hasRemote && remote == null)) {
      throw const CloudFormatException('sync preview descriptor is missing');
    }
    return CloudSyncPreparedPreview(
      local: local,
      base: base,
      remoteRevision: metadata['remoteRevision'] as String?,
      remoteHead: head,
      remote: remote,
    );
  }

  @override
  Future<void> deleteSyncPreview() => _exclusivePreview(_deleteSyncPreview);

  Future<void> _deleteSyncPreview() async {
    if (await _syncPreview.exists()) {
      await _syncPreview.delete(recursive: true);
    }
  }

  @override
  Future<void> saveRestorePreview(
    String snapshotId,
    CloudSyncPreparedRestore preview,
  ) => _exclusivePreview(() => _saveRestorePreview(snapshotId, preview));

  Future<void> _saveRestorePreview(
    String snapshotId,
    CloudSyncPreparedRestore preview,
  ) async {
    final root = _restorePreview(snapshotId);
    final metadata = File('${root.path}/preview.json');
    if (await metadata.exists()) await metadata.delete();
    await _operations.writeSnapshot(
      Directory('${root.path}/local'),
      preview.local,
    );
    await _operations.writeSnapshot(
      Directory('${root.path}/target'),
      preview.target,
    );
    await _writePreviewMetadata(metadata, {
      'version': 2,
      'snapshotId': snapshotId,
      'remoteRevision': preview.remoteRevision,
    });
  }

  @override
  Future<CloudSyncPreparedRestore?> readRestorePreview(String snapshotId) =>
      _exclusivePreview(() => _readRestorePreview(snapshotId));

  Future<CloudSyncPreparedRestore?> _readRestorePreview(
    String snapshotId,
  ) async {
    final root = _restorePreview(snapshotId);
    final metadata = await _readPreviewMetadata(
      File('${root.path}/preview.json'),
    );
    if (metadata == null) return null;
    if (metadata.keys.toSet().difference({
          'version',
          'snapshotId',
          'remoteRevision',
        }).isNotEmpty ||
        metadata.keys.length != 3 ||
        metadata['version'] != 2 ||
        metadata['snapshotId'] != snapshotId ||
        (metadata['remoteRevision'] != null &&
            metadata['remoteRevision'] is! String)) {
      throw const CloudFormatException('invalid restore preview metadata');
    }
    final local = await _operations.readSnapshot(
      Directory('${root.path}/local'),
    );
    final target = await _operations.readSnapshot(
      Directory('${root.path}/target'),
    );
    if (local == null || target == null) {
      throw const CloudFormatException('restore preview descriptor is missing');
    }
    return CloudSyncPreparedRestore(
      local: local,
      target: target,
      remoteRevision: metadata['remoteRevision'] as String?,
    );
  }

  @override
  Future<void> deleteRestorePreviews() =>
      _exclusivePreview(_deleteRestorePreviews);

  Future<void> _deleteRestorePreviews() async {
    final root = Directory('${_root.path}/previews/restore');
    if (await root.exists()) await root.delete(recursive: true);
  }

  @override
  Future<CloudSyncSnapshotData> captureLocal() async {
    await (_startupMaintenance ??= _collectStartupGarbage());
    final records = <CloudSyncRecord>[];
    final currentIds = <String>{};
    await for (final portable in _registry.exportRecords()) {
      final metadata = await _encodePortable(portable, records);
      currentIds.add(metadata.id);
      records.add(metadata);
    }
    final base = await readBase();
    if (base != null) {
      final decodedBase = await _decodeSnapshot(base);
      for (final record in base.records.values) {
        if (record.kind != 'metadata') continue;
        final portable = decodedBase.records[record.id]!;
        if (!_registry.knownAdapterIds.contains(portable.adapterId)) {
          records.add(record);
          for (final chunkId in decodedBase.metadataChunks[record.id]!) {
            records.add(base.records[chunkId]!);
          }
          continue;
        }
        if (currentIds.contains(record.id)) {
          continue;
        }
        records.add(await _encodePortable(_tombstoneFor(portable), records));
      }
    }
    final snapshot = CloudSyncSnapshotData(records);
    _preparedSnapshots[snapshot] = true;
    return snapshot;
  }

  Future<CloudSyncRecord> _encodePortable(
    PortableSyncRecord record,
    List<CloudSyncRecord> output,
  ) async {
    final stableId = _stableId(record.adapterId, record.id);
    final chunkIds = <String>[];
    var length = 0;
    if (record.resource != null && !record.deleted) {
      var pending = BytesBuilder(copy: false);
      var index = 0;
      await for (final input in record.resource!.openRead()) {
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
    final metadata = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 2,
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
                  'chunks': chunkIds,
                },
        }),
      ),
    );
    if (record.deleted) {
      return CloudSyncRecord(
        id: stableId,
        kind: 'metadata',
        binary: false,
        deleted: true,
        tombstoneIdentity: PortableRecordCodec.tombstoneIdentity(record),
      );
    }
    return CloudSyncRecord(
      id: stableId,
      kind: 'metadata',
      binary: record.resource != null,
      deleted: false,
      payload: await _blobs.putBytes(metadata),
    );
  }

  Future<String> _writeCaptureChunk(
    String stableId,
    int index,
    Uint8List bytes,
    List<CloudSyncRecord> output,
  ) async {
    final id = '$stableId.c$index';
    output.add(
      CloudSyncRecord(
        id: id,
        kind: 'resource',
        binary: true,
        deleted: false,
        payload: await _blobs.putBytes(bytes),
      ),
    );
    return id;
  }

  @override
  Future<CloudSyncSnapshotData?> readBase() => _operations.readSnapshot(_base);

  @override
  Future<CloudSyncPayload> materializeRemotePayload(
    List<int> bytes, {
    required int expectedLength,
    required String expectedSha256,
  }) => _blobs.putStream(
    () => Stream<List<int>>.value(bytes),
    expectedLength: expectedLength,
    expectedSha256: expectedSha256,
  );

  @override
  Future<CloudSyncPayload?> resolveLocalPayload({
    required int expectedLength,
    required String expectedSha256,
  }) => _blobs.tryOpen(length: expectedLength, sha256: expectedSha256);

  @override
  Future<CloudSyncSnapshotData> buildRecoveryPoint({
    required CloudSyncSnapshotData local,
    required CloudSyncSnapshotData target,
  }) async {
    await _decodeSnapshot(local);
    final decodedTarget = await _decodeSnapshot(target);
    final recovery = <CloudSyncRecord>[...local.records.values];
    for (final targetRecord in target.records.values) {
      if (targetRecord.kind != 'metadata' ||
          local.records.containsKey(targetRecord.id)) {
        continue;
      }
      final portable = decodedTarget.records[targetRecord.id]!;
      // Unknown/opaque adapters are preserved in merged snapshots but must
      // never be interpreted as locally owned records during rollback.
      if (!_registry.adapterIds.contains(portable.adapterId)) continue;
      recovery.add(await _encodePortable(_tombstoneFor(portable), recovery));
    }
    final snapshot = CloudSyncSnapshotData(recovery);
    _preparedSnapshots[target] = true;
    _preparedSnapshots[snapshot] = true;
    return snapshot;
  }

  @override
  Future<void> stage(
    String operationId,
    CloudSyncSnapshotData snapshot, {
    CloudSyncSnapshotData? recoveryPoint,
  }) async {
    if (_preparedSnapshots[snapshot] != true ||
        (recoveryPoint != null && _preparedSnapshots[recoveryPoint] != true)) {
      throw const CloudFormatException('snapshot was not prepared');
    }
    await _decodeSnapshot(snapshot);
    if (recoveryPoint != null) await _decodeSnapshot(recoveryPoint);
    try {
      final base = await readBase();
      if (base == null) {
        await _operations.writeArtifact(operationId, 'base-absent', const [1]);
      } else {
        final baseSnapshotId = await _operations.readSnapshotId(_base);
        if (baseSnapshotId == null) {
          throw const CloudFormatException('base snapshot id is missing');
        }
        await _operations.writeSnapshot(
          _baseRecovery(operationId),
          base,
          snapshotId: baseSnapshotId,
        );
      }
      if (recoveryPoint != null) {
        await _operations.writeSnapshot(_recovery(operationId), recoveryPoint);
      }
      // The target ref is the operation's final publication point. A failed
      // recovery descriptor can therefore never make staging appear READY.
      await _operations.writeSnapshot(_stage(operationId), snapshot);
      _stagedSnapshots[operationId] = snapshot;
      if (recoveryPoint != null) {
        _recoverySnapshots[operationId] = recoveryPoint;
      }
    } catch (error, stackTrace) {
      _stagedSnapshots.remove(operationId);
      _recoverySnapshots.remove(operationId);
      await _operations.deleteOperation(operationId);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<CloudSyncSnapshotData> readStaged(String operationId) async {
    final cached = _stagedSnapshots[operationId];
    if (cached != null) return cached;
    final snapshot = await _operations.readSnapshot(_stage(operationId));
    if (snapshot == null) {
      throw const CloudFormatException('staged target is not READY');
    }
    await _decodeSnapshot(snapshot);
    _stagedSnapshots[operationId] = snapshot;
    return snapshot;
  }

  @override
  Future<String> stagedFingerprint(String operationId) async {
    await readStaged(operationId);
    return _operations.fingerprint(operationId);
  }

  @override
  Future<void> apply(String operationId) async {
    final snapshot = await readStaged(operationId);
    final baseline = await _readRecovery(operationId);
    await _registry.apply(await _portableRecords(snapshot, baseline: baseline));
  }

  Future<List<PortableSyncRecord>> _portableRecords(
    CloudSyncSnapshotData snapshot, {
    CloudSyncSnapshotData? baseline,
  }) async {
    final decoded = await _decodeSnapshot(snapshot);
    final records = decoded.records.entries
        .where(
          (entry) =>
              _registry.adapterIds.contains(entry.value.adapterId) &&
              (entry.value.deleted ||
                  !_sameRecord(
                    baseline?.records[entry.key],
                    snapshot.records[entry.key]!,
                  )),
        )
        .map((entry) => entry.value)
        .toList();
    if (baseline == null) return records;

    final decodedBaseline = await _decodeSnapshot(baseline);
    for (final entry in decodedBaseline.records.entries) {
      final portable = entry.value;
      if (decoded.records.containsKey(entry.key) ||
          portable.deleted ||
          !_registry.adapterIds.contains(portable.adapterId)) {
        continue;
      }
      records.add(_tombstoneFor(portable));
    }
    return records;
  }

  PortableSyncRecord _tombstoneFor(PortableSyncRecord source) {
    final adapter = _registry.adapter(source.adapterId);
    if (adapter is! ValidatingCloudSyncDataAdapter) {
      throw CloudFormatException(
        'adapter ${source.adapterId} cannot create a tombstone',
      );
    }
    final data = adapter.tombstoneData(source);
    ValidatingCloudSyncDataAdapter.rejectSecrets(data);
    return PortableSyncRecord(
      adapterId: source.adapterId,
      id: source.id,
      kind: source.kind,
      data: data,
      deleted: true,
    );
  }

  bool _sameRecord(CloudSyncRecord? left, CloudSyncRecord right) {
    if (left == null) return false;
    final leftPayload = left.payload;
    final rightPayload = right.payload;
    return left.id == right.id &&
        left.kind == right.kind &&
        left.binary == right.binary &&
        left.deleted == right.deleted &&
        left.tombstoneIdentity == right.tombstoneIdentity &&
        leftPayload?.length == rightPayload?.length &&
        leftPayload?.sha256 == rightPayload?.sha256;
  }

  Future<CloudSyncSnapshotData?> _readRecovery(String operationId) async {
    final cached = _recoverySnapshots[operationId];
    if (cached != null) return cached;
    final snapshot = await _operations.readSnapshot(_recovery(operationId));
    if (snapshot == null) return null;
    await _decodeSnapshot(snapshot);
    _recoverySnapshots[operationId] = snapshot;
    return snapshot;
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
    final decoded = await _decodeSnapshot(sourceSnapshot);
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
    return output;
  }

  @override
  Future<CloudSyncSnapshotData> finalizeMergedSnapshot(
    CloudSyncSnapshotData snapshot,
  ) async {
    final decoded = await _codec.decode(snapshot, rejectOrphans: false);
    final records = <String, CloudSyncRecord>{};
    for (final entry in decoded.records.entries) {
      final portable = entry.value;
      if (portable.deleted) {
        final encoded = await _encodePortable(portable, const []);
        records[encoded.id] = encoded;
        continue;
      }
      final metadata = snapshot.records[entry.key]!;
      records[metadata.id] = metadata;
      for (final chunkId in decoded.metadataChunks[entry.key]!) {
        records[chunkId] = snapshot.records[chunkId]!;
      }
    }
    final finalized = CloudSyncSnapshotData(records.values);
    _preparedSnapshots[finalized] = true;
    return finalized;
  }

  @override
  Future<void> rollback(String operationId) => completeOperation(operationId);

  @override
  Future<void> rollbackForRecovery(String operationId) async {
    final recovery = await _readRecovery(operationId);
    if (recovery != null) {
      CloudSyncSnapshotData? failedTarget;
      try {
        failedTarget = await readStaged(operationId);
      } on CloudFormatException {
        // A damaged target must not prevent restoring the independently
        // verified recovery snapshot.
      } on FileSystemException {
        // Recovery has its own verified descriptor and does not depend on the
        // failed target remaining readable.
      }
      await _registry.apply(
        await _portableRecords(recovery, baseline: failedTarget),
      );
    }
  }

  @override
  Future<void> restoreBaseForRecovery(String operationId) async {
    final previous = await _operations.readSnapshot(_baseRecovery(operationId));
    if (previous != null) {
      final snapshotId = await _operations.readSnapshotId(
        _baseRecovery(operationId),
      );
      if (snapshotId == null) {
        throw const CloudFormatException(
          'base recovery snapshot id is missing',
        );
      }
      await saveBase(previous, snapshotId);
      return;
    }
    final absentMarker = await _operations.readArtifact(
      operationId,
      'base-absent',
    );
    if (absentMarker == null ||
        absentMarker.length != 1 ||
        absentMarker.single != 1) {
      throw const CloudFormatException('base recovery state is missing');
    }
    await _operations.deleteSnapshot(_base);
  }

  @override
  Future<Map<String, String>> readVerifiedCloudObjects() async {
    try {
      final file = _verificationCache;
      if (!await file.exists()) return const {};
      if (await file.length() > _maxVerificationCacheBytes) {
        throw const FormatException('verification cache is too large');
      }
      final value = jsonDecode(await file.readAsString());
      if (value is! Map<String, dynamic> ||
          value.length != 2 ||
          value['version'] != 1 ||
          value['objects'] is! Map) {
        throw const FormatException('invalid verification cache');
      }
      final objects = <String, String>{};
      for (final entry in (value['objects'] as Map).entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.key as String) ||
            (entry.value as String).isEmpty ||
            (entry.value as String).length > 1024) {
          throw const FormatException('invalid verification cache entry');
        }
        objects[entry.key as String] = entry.value as String;
        if (objects.length > _maxVerificationCacheEntries) {
          throw const FormatException('too many verification cache entries');
        }
      }
      return Map.unmodifiable(objects);
    } catch (error) {
      logCloudSyncMetrics(
        'Ignoring invalid cloud object verification cache: '
        'type=${error.runtimeType}',
      );
      return const {};
    }
  }

  @override
  Future<void> writeVerifiedCloudObjects(Map<String, String> revisions) async {
    try {
      final entries = revisions.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key));
      if (entries.length > _maxVerificationCacheEntries) {
        entries.removeRange(0, entries.length - _maxVerificationCacheEntries);
      }
      final bytes = utf8.encode(
        jsonEncode({
          'version': 1,
          'objects': {for (final entry in entries) entry.key: entry.value},
        }),
      );
      if (bytes.length > _maxVerificationCacheBytes) {
        throw const FormatException('verification cache is too large');
      }
      final destination = _verificationCache;
      await destination.parent.create(recursive: true);
      final temporary = File('${destination.path}.tmp');
      if (await temporary.exists()) await temporary.delete();
      await temporary.writeAsBytes(bytes, flush: true);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
    } catch (error) {
      logCloudSyncMetrics(
        'Unable to persist cloud object verification cache: '
        'type=${error.runtimeType}',
      );
    }
  }

  @override
  Future<void> saveBase(
    CloudSyncSnapshotData snapshot,
    String snapshotId,
  ) async {
    await _decodeSnapshot(snapshot);
    await _operations.writeSnapshot(_base, snapshot, snapshotId: snapshotId);
  }

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

  Future<void> _collectStartupGarbage() async {
    await _operations.collectUnreferencedBlobs();
  }

  Future<void> _writePreviewMetadata(
    File destination,
    Map<String, Object?> value,
  ) async {
    await destination.parent.create(recursive: true);
    final temporary = File('${destination.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(destination.path);
  }

  Future<Map<String, dynamic>?> _readPreviewMetadata(File file) async {
    if (!await file.exists()) return null;
    if (await file.length() > 64 * 1024) {
      throw const CloudFormatException('preview metadata is too large');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const CloudFormatException('invalid preview metadata');
    }
    return value;
  }

  Future<T> _exclusivePreview<T>(Future<T> Function() action) =>
      _operations.runExclusiveMutation(action);

  void _validatePreviewId(String value) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,200}$').hasMatch(value)) {
      throw const CloudFormatException('invalid preview snapshot id');
    }
  }

  @override
  Future<void> completeOperation(String operationId) async {
    await _operations.deleteOperation(operationId);
    _stagedSnapshots.remove(operationId);
    _recoverySnapshots.remove(operationId);
  }

  String _stableId(String adapterId, String id) =>
      'r-${sha256.convert(utf8.encode('$adapterId\u0000$id'))}';
}
