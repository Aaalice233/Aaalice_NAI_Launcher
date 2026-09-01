import 'dart:convert';
import 'dart:math';

import 'backend/cloud_sync_backend.dart';
import 'data_source.dart';
import 'journal.dart';
import 'merge.dart';
import 'models.dart';
import 'operation.dart';
import 'object_codec.dart';
import 'record_merge.dart';
import 'snapshot_transfer.dart';
import 'sync_operation_runner.dart';
import 'sync_types.dart';

export 'sync_types.dart';

class SyncCoordinator {
  SyncCoordinator({
    required this.backend,
    required this.dataSource,
    required this.codec,
    required this.journalStore,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final CloudObjectCodec codec;
  final JournalStore journalStore;
  final DateTime Function() _now;
  final Random _random;

  CloudSnapshotTransfer get _transfer => CloudSnapshotTransfer(
    backend: backend,
    dataSource: dataSource,
    codec: codec,
    now: _now,
  );

  SyncOperationRunner get _runner => SyncOperationRunner(
    backend: backend,
    dataSource: dataSource,
    codec: codec,
    journalStore: journalStore,
    now: _now,
  );

  Future<SyncPreview> preview({
    ConflictResolver<CloudSyncRecord>? resolve,
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    onProgress?.call(const SyncProgress(phase: SyncPhase.preparing));
    final local = await dataSource.captureLocal();
    final base =
        await dataSource.readBase() ?? const CloudSyncSnapshotData.empty();
    final remoteHead = await backend.readHead();
    await cancellation.checkpoint();
    if (remoteHead == null) {
      return SyncPreview(
        localSnapshot: local,
        snapshot: local,
        conflicts: const [],
        remoteRevision: null,
        remoteSnapshotId: null,
        remoteSnapshot: null,
      );
    }
    final head = SnapshotHead.decode(remoteHead.bytes);
    final remote = await _transfer.downloadHead(head, cancellation, onProgress);
    final merged = await const CloudRecordMerger().merge(
      base: base,
      local: local,
      remote: remote,
      resolve: resolve,
      conflictCopier: dataSource is CloudSyncConflictRecordCopier
          ? dataSource as CloudSyncConflictRecordCopier
          : null,
    );
    return SyncPreview(
      localSnapshot: local,
      snapshot: merged.snapshot,
      conflicts: merged.conflicts,
      remoteRevision: remoteHead.revision,
      remoteSnapshotId: head.snapshotId,
      remoteSnapshot: remote,
    );
  }

  Future<SyncOutcome> synchronize({
    ConflictResolver<CloudSyncRecord>? resolve,
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    await _recoverPending(cancellation, onProgress);
    final plan = await preview(
      resolve: resolve,
      token: cancellation,
      onProgress: onProgress,
    );
    if (!plan.canApply) throw DeferredSyncConflictException(plan.conflicts);
    final matches =
        plan.remoteSnapshot != null &&
        _sameSnapshot(plan.snapshot, plan.remoteSnapshot!);
    final snapshotId = matches ? plan.remoteSnapshotId! : _newId('snapshot');
    final journal = await _runner.prepare(
      operationId: _newId('op'),
      operation: JournalOperation.synchronize,
      snapshotId: snapshotId,
      target: plan.snapshot,
      expectedRevision: plan.remoteRevision,
      uploadRequired: !matches,
    );
    final target = await _runner.run(
      journal,
      token: cancellation,
      recovering: false,
      onProgress: onProgress,
    );
    return SyncOutcome(
      snapshotId: snapshotId,
      uploaded: !matches,
      snapshot: target,
    );
  }

  Future<void> discardPending() => _runner.discardPending();

  Future<void> recoverPending({
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) => _runner.recoverPending(token: token, onProgress: onProgress);

  Future<List<SnapshotHistoryEntry>> history({
    int limit = 20,
    OperationToken? token,
  }) async {
    final cancellation = token ?? OperationToken();
    final ids = await backend.listSnapshotIds(limit: limit);
    final entries = <SnapshotHistoryEntry>[];
    for (final id in ids) {
      await cancellation.checkpoint();
      final read = await backend.readSnapshotManifest(id);
      if (read == null) {
        throw const CloudFormatException('history manifest is missing');
      }
      final manifest = SnapshotManifest.decode(
        await codec.decode(read.bytes, objectId: id, kind: 'manifest'),
      );
      if (manifest.snapshotId != id) {
        throw const CloudFormatException('history manifest identity mismatch');
      }
      entries.add(
        SnapshotHistoryEntry(
          id: id,
          createdAt: manifest.createdAt,
          objectCount: manifest.objects.length,
        ),
      );
    }
    return entries;
  }

  Future<RestorePreview> previewRestore(
    String snapshotId, {
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    final target = await _transfer.downloadId(
      snapshotId,
      cancellation,
      onProgress,
    );
    final local = await dataSource.captureLocal();
    final changes = <SnapshotChange>[];
    final ids = {...local.records.keys, ...target.records.keys}.toList()
      ..sort();
    for (final id in ids) {
      final before = local.records[id];
      final after = target.records[id];
      if (before == after) continue;
      if (after == null || after.deleted) {
        if (before != null && !before.deleted) {
          changes.add(
            SnapshotChange(
              id: id,
              kind: SnapshotChangeKind.deleted,
              record: before,
            ),
          );
        }
      } else {
        changes.add(
          SnapshotChange(
            id: id,
            kind: before == null || before.deleted
                ? SnapshotChangeKind.added
                : SnapshotChangeKind.modified,
            record: after,
          ),
        );
      }
    }
    return RestorePreview(snapshotId: snapshotId, changes: changes);
  }

  Future<SyncOutcome> restore(
    String oldSnapshotId, {
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    await _recoverPending(cancellation, onProgress);
    final head = await backend.readHead();
    final restored = await _transfer.downloadId(
      oldSnapshotId,
      cancellation,
      onProgress,
    );
    final newId = _newId('snapshot');
    final journal = await _runner.prepare(
      operationId: _newId('restore'),
      operation: JournalOperation.restore,
      snapshotId: newId,
      target: restored,
      expectedRevision: head?.revision,
      uploadRequired: true,
    );
    final target = await _runner.run(
      journal,
      token: cancellation,
      recovering: false,
      onProgress: onProgress,
    );
    return SyncOutcome(snapshotId: newId, uploaded: true, snapshot: target);
  }

  Future<SyncOutcome> uploadLocal({
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    await _recoverPending(cancellation, onProgress);
    onProgress?.call(const SyncProgress(phase: SyncPhase.preparing));
    final head = await backend.readHead();
    final local = await dataSource.captureLocal();
    final snapshotId = _newId('snapshot');
    final journal = await _runner.prepare(
      operationId: _newId('upload'),
      operation: JournalOperation.uploadLocal,
      snapshotId: snapshotId,
      target: local,
      expectedRevision: head?.revision,
      uploadRequired: true,
    );
    final target = await _runner.run(
      journal,
      token: cancellation,
      recovering: false,
      onProgress: onProgress,
    );
    return SyncOutcome(
      snapshotId: snapshotId,
      uploaded: true,
      snapshot: target,
    );
  }

  Future<SyncOutcome> downloadRemote({
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    await _recoverPending(cancellation, onProgress);
    final headRead = await backend.readHead();
    if (headRead == null) throw StateError('Remote snapshot is missing.');
    final head = SnapshotHead.decode(headRead.bytes);
    final snapshot = await _transfer.downloadHead(
      head,
      cancellation,
      onProgress,
    );
    final journal = await _runner.prepare(
      operationId: _newId('download'),
      operation: JournalOperation.downloadRemote,
      snapshotId: head.snapshotId,
      target: snapshot,
      expectedRevision: headRead.revision,
      uploadRequired: false,
    );
    final target = await _runner.run(
      journal,
      token: cancellation,
      recovering: false,
      onProgress: onProgress,
    );
    return SyncOutcome(
      snapshotId: head.snapshotId,
      uploaded: false,
      snapshot: target,
    );
  }

  Future<void> _recoverPending(
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    if (await journalStore.read() == null) return;
    await recoverPending(token: token, onProgress: onProgress);
  }

  bool _sameSnapshot(CloudSyncSnapshotData left, CloudSyncSnapshotData right) {
    if (left.records.length != right.records.length) return false;
    for (final entry in left.records.entries) {
      if (right.records[entry.key] != entry.value) return false;
    }
    return true;
  }

  String _newId(String prefix) {
    final timestamp = _now().toUtc().microsecondsSinceEpoch;
    final entropy = List.generate(8, (_) => _random.nextInt(256));
    return '$prefix-$timestamp-${base64Url.encode(entropy).replaceAll('=', '')}';
  }
}
