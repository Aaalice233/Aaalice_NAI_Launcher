import 'dart:convert';
import 'dart:math';

import 'backend/cloud_sync_backend.dart';
import 'data_source.dart';
import 'journal.dart';
import 'merge.dart';
import 'models.dart';
import 'operation.dart';
import 'record_merge.dart';
import 'snapshot_transfer.dart';
import 'sync_operation_runner.dart';
import 'sync_types.dart';

export 'sync_types.dart';

class SyncCoordinator {
  SyncCoordinator({
    required this.backend,
    required this.dataSource,
    required this.journalStore,
    DateTime Function()? now,
    Random? random,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final JournalStore journalStore;
  final DateTime Function() _now;
  final Random _random;
  _PendingSyncPreview? _pendingSyncPreview;
  final Map<String, _PendingRestorePreview> _restorePreviews = {};

  CloudSnapshotTransfer get _transfer =>
      CloudSnapshotTransfer(backend: backend, dataSource: dataSource);

  SyncOperationRunner get _runner => SyncOperationRunner(
    backend: backend,
    dataSource: dataSource,
    journalStore: journalStore,
    now: _now,
  );

  Future<SyncPreview> preview({
    ConflictResolver<CloudSyncRecord>? resolve,
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final cancellation = token ?? OperationToken();
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => preview(
          resolve: resolve,
          token: cancellation,
          onProgress: onProgress,
        ),
      );
    }
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final local = await dataSource.captureLocal();
    final base =
        await dataSource.readBase() ?? const CloudSyncSnapshotData.empty();
    final remoteHead = await backend.readHead();
    await cancellation.checkpoint();
    if (remoteHead == null) {
      _pendingSyncPreview = _PendingSyncPreview(
        local: local,
        base: base,
        remoteRevision: null,
        remoteHead: null,
        remote: null,
      );
      await _saveSyncPreview(_pendingSyncPreview!);
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
    final inputs = _PendingSyncPreview(
      local: local,
      base: base,
      remoteRevision: remoteHead.revision,
      remoteHead: head,
      remote: remote,
    );
    _pendingSyncPreview = inputs;
    await _saveSyncPreview(inputs);
    final merged = await _mergePreview(inputs, resolve);
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
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => synchronize(
          resolve: resolve,
          token: cancellation,
          onProgress: onProgress,
        ),
      );
    }
    await _recoverPending(cancellation, onProgress);
    final plan = await _previewForSynchronization(
      resolve: resolve,
      token: cancellation,
      onProgress: onProgress,
    );
    if (!plan.canApply) throw DeferredSyncConflictException(plan.conflicts);
    final matches =
        plan.remoteSnapshot != null &&
        _sameSnapshot(plan.snapshot, plan.remoteSnapshot!);
    final snapshotId = matches ? plan.remoteSnapshotId! : _newId('snapshot');
    _pendingSyncPreview = null;
    final journal = await _runner.prepare(
      operationId: _newId('op'),
      operation: JournalOperation.synchronize,
      snapshotId: snapshotId,
      target: plan.snapshot,
      recoveryPoint: await _buildRecoveryPoint(
        local: plan.localSnapshot,
        target: plan.snapshot,
      ),
      expectedRevision: plan.remoteRevision,
      uploadRequired: !matches,
    );
    await _deleteSyncPreview();
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

  Future<SyncPreview> _previewForSynchronization({
    ConflictResolver<CloudSyncRecord>? resolve,
    required OperationToken token,
    SyncProgressCallback? onProgress,
  }) async {
    final cached = _pendingSyncPreview ?? await _readSyncPreview();
    if (cached == null) {
      return preview(resolve: resolve, token: token, onProgress: onProgress);
    }
    _pendingSyncPreview = cached;
    final remoteHead = await backend.readHead();
    if (remoteHead?.revision != cached.remoteRevision) {
      _pendingSyncPreview = null;
      await _deleteSyncPreview();
      throw const CloudPreviewStaleException();
    }
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final local = await dataSource.captureLocal();
    await token.checkpoint();
    if (!_sameSnapshot(local, cached.local)) {
      _pendingSyncPreview = null;
      await _deleteSyncPreview();
      throw const CloudPreviewStaleException();
    }
    final remote = cached.remote;
    if (remote == null) {
      return SyncPreview(
        localSnapshot: local,
        snapshot: local,
        conflicts: const [],
        remoteRevision: null,
        remoteSnapshotId: null,
        remoteSnapshot: null,
      );
    }
    final merged = await _mergePreview(cached, resolve);
    return SyncPreview(
      localSnapshot: local,
      snapshot: merged.snapshot,
      conflicts: merged.conflicts,
      remoteRevision: cached.remoteRevision,
      remoteSnapshotId: cached.remoteHead!.snapshotId,
      remoteSnapshot: remote,
    );
  }

  Future<CloudRecordMergeResult> _mergePreview(
    _PendingSyncPreview inputs,
    ConflictResolver<CloudSyncRecord>? resolve,
  ) => const CloudRecordMerger().merge(
    base: inputs.base,
    local: inputs.local,
    remote: inputs.remote!,
    resolve: resolve,
    conflictCopier: dataSource is CloudSyncConflictRecordCopier
        ? dataSource as CloudSyncConflictRecordCopier
        : null,
  );

  Future<void> discardPending() async {
    await _runner.discardPending();
    _pendingSyncPreview = null;
    _restorePreviews.clear();
    await _deleteSyncPreview();
    await _deleteRestorePreviews();
  }

  Future<void> recoverPending({
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) {
    final cancellation = token ?? OperationToken();
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => recoverPending(token: cancellation, onProgress: onProgress),
      );
    }
    return _runner.recoverPending(token: cancellation, onProgress: onProgress);
  }

  Future<List<SnapshotHistoryEntry>> history({
    int limit = 20,
    OperationToken? token,
  }) async {
    final cancellation = token ?? OperationToken();
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => history(limit: limit, token: cancellation),
      );
    }
    final ids = await backend.listSnapshotIds(limit: limit);
    final entries = <SnapshotHistoryEntry>[];
    for (final id in ids) {
      await cancellation.checkpoint();
      final read = await backend.readSnapshotManifest(id);
      if (read == null) {
        throw const CloudFormatException('history manifest is missing');
      }
      final manifest = SnapshotManifest.decode(read.bytes);
      if (manifest.snapshotId != id) {
        throw const CloudFormatException('history manifest identity mismatch');
      }
      entries.add(
        SnapshotHistoryEntry(
          id: id,
          createdAt: manifest.createdAt,
          objectCount: manifest.records
              .where((record) => !record.deleted)
              .length,
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
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => previewRestore(
          snapshotId,
          token: cancellation,
          onProgress: onProgress,
        ),
      );
    }
    final head = await backend.readHead();
    final target = await _transfer.downloadId(
      snapshotId,
      cancellation,
      onProgress,
    );
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final local = await dataSource.captureLocal();
    _restorePreviews
      ..clear()
      ..[snapshotId] = _PendingRestorePreview(
        target: target,
        local: local,
        remoteRevision: head?.revision,
      );
    await _deleteRestorePreviews();
    await _saveRestorePreview(snapshotId, _restorePreviews[snapshotId]!);
    final changes = <SnapshotChange>[];
    final ids = {...local.records.keys, ...target.records.keys}.toList()
      ..sort();
    for (final id in ids) {
      final before = local.records[id];
      final after = target.records[id];
      if (_sameRecord(before, after)) continue;
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
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () =>
            restore(oldSnapshotId, token: cancellation, onProgress: onProgress),
      );
    }
    await _recoverPending(cancellation, onProgress);
    final head = await backend.readHead();
    final preview =
        _restorePreviews.remove(oldSnapshotId) ??
        await _readRestorePreview(oldSnapshotId);
    if (preview != null && preview.remoteRevision != head?.revision) {
      await _deleteRestorePreviews();
      throw const CloudPreviewStaleException();
    }
    final restored =
        preview?.target ??
        await _transfer.downloadId(oldSnapshotId, cancellation, onProgress);
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final recoveryPoint = await dataSource.captureLocal();
    if (preview != null && !_sameSnapshot(recoveryPoint, preview.local)) {
      await _deleteRestorePreviews();
      throw const CloudPreviewStaleException();
    }
    final newId = _newId('snapshot');
    final journal = await _runner.prepare(
      operationId: _newId('restore'),
      operation: JournalOperation.restore,
      snapshotId: newId,
      target: restored,
      recoveryPoint: await _buildRecoveryPoint(
        local: recoveryPoint,
        target: restored,
      ),
      expectedRevision: head?.revision,
      uploadRequired: true,
    );
    await _deleteRestorePreviews();
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
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => uploadLocal(token: cancellation, onProgress: onProgress),
      );
    }
    await _recoverPending(cancellation, onProgress);
    onProgress?.call(const SyncProgress(phase: SyncPhase.preparing));
    final head = await backend.readHead();
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final local = await dataSource.captureLocal();
    final snapshotId = _newId('snapshot');
    final journal = await _runner.prepare(
      operationId: _newId('upload'),
      operation: JournalOperation.uploadLocal,
      snapshotId: snapshotId,
      target: local,
      recoveryPoint: null,
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
    if (!identical(OperationToken.current, cancellation)) {
      return cancellation.runInScope(
        () => downloadRemote(token: cancellation, onProgress: onProgress),
      );
    }
    await _recoverPending(cancellation, onProgress);
    final headRead = await backend.readHead();
    if (headRead == null) throw StateError('Remote snapshot is missing.');
    final head = SnapshotHead.decode(headRead.bytes);
    final snapshot = await _transfer.downloadHead(
      head,
      cancellation,
      onProgress,
    );
    final currentHead = await backend.readHead();
    await cancellation.checkpoint();
    if (currentHead?.revision != headRead.revision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Remote HEAD advanced while downloading the snapshot.',
      );
    }
    onProgress?.call(const SyncProgress(phase: SyncPhase.scanning));
    onProgress?.call(const SyncProgress(phase: SyncPhase.hashing));
    final recoveryPoint = await dataSource.captureLocal();
    final journal = await _runner.prepare(
      operationId: _newId('download'),
      operation: JournalOperation.downloadRemote,
      snapshotId: head.snapshotId,
      target: snapshot,
      recoveryPoint: await _buildRecoveryPoint(
        local: recoveryPoint,
        target: snapshot,
      ),
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

  Future<void> _saveSyncPreview(_PendingSyncPreview preview) async {
    final store = dataSource;
    if (store is! CloudSyncPreviewStore) return;
    await (store as CloudSyncPreviewStore).saveSyncPreview(
      CloudSyncPreparedPreview(
        local: preview.local,
        base: preview.base,
        remoteRevision: preview.remoteRevision,
        remoteHead: preview.remoteHead,
        remote: preview.remote,
      ),
    );
  }

  Future<_PendingSyncPreview?> _readSyncPreview() async {
    final store = dataSource;
    if (store is! CloudSyncPreviewStore) return null;
    final preview = await (store as CloudSyncPreviewStore).readSyncPreview();
    if (preview == null) return null;
    return _PendingSyncPreview(
      local: preview.local,
      base: preview.base,
      remoteRevision: preview.remoteRevision,
      remoteHead: preview.remoteHead,
      remote: preview.remote,
    );
  }

  Future<void> _deleteSyncPreview() async {
    final store = dataSource;
    if (store is CloudSyncPreviewStore) {
      await (store as CloudSyncPreviewStore).deleteSyncPreview();
    }
  }

  Future<void> _saveRestorePreview(
    String snapshotId,
    _PendingRestorePreview preview,
  ) async {
    final store = dataSource;
    if (store is! CloudSyncPreviewStore) return;
    await (store as CloudSyncPreviewStore).saveRestorePreview(
      snapshotId,
      CloudSyncPreparedRestore(
        local: preview.local,
        target: preview.target,
        remoteRevision: preview.remoteRevision,
      ),
    );
  }

  Future<_PendingRestorePreview?> _readRestorePreview(String snapshotId) async {
    final store = dataSource;
    if (store is! CloudSyncPreviewStore) return null;
    final preview = await (store as CloudSyncPreviewStore).readRestorePreview(
      snapshotId,
    );
    if (preview == null) return null;
    return _PendingRestorePreview(
      local: preview.local,
      target: preview.target,
      remoteRevision: preview.remoteRevision,
    );
  }

  Future<void> _deleteRestorePreviews() async {
    final store = dataSource;
    if (store is CloudSyncPreviewStore) {
      await (store as CloudSyncPreviewStore).deleteRestorePreviews();
    }
  }

  Future<CloudSyncSnapshotData> _buildRecoveryPoint({
    required CloudSyncSnapshotData local,
    required CloudSyncSnapshotData target,
  }) {
    final source = dataSource;
    if (source is CloudSyncRecoveryPointBuilder) {
      return (source as CloudSyncRecoveryPointBuilder).buildRecoveryPoint(
        local: local,
        target: target,
      );
    }
    return Future.value(local);
  }

  Future<void> _recoverPending(
    OperationToken token,
    SyncProgressCallback? onProgress,
  ) async {
    if (await journalStore.read() == null) return;
    await recoverPending(token: token, onProgress: onProgress);
    // Recovery can change the persisted base without changing local records or
    // remote HEAD. Cached merge inputs are therefore no longer trustworthy.
    _pendingSyncPreview = null;
    _restorePreviews.clear();
    await _deleteSyncPreview();
    await _deleteRestorePreviews();
  }

  bool _sameSnapshot(CloudSyncSnapshotData left, CloudSyncSnapshotData right) {
    if (left.records.length != right.records.length) return false;
    for (final entry in left.records.entries) {
      if (!_sameRecord(entry.value, right.records[entry.key])) return false;
    }
    return true;
  }

  bool _sameRecord(CloudSyncRecord? left, CloudSyncRecord? right) =>
      left == null
      ? right == null
      : right != null &&
            right.id == left.id &&
            right.kind == left.kind &&
            right.binary == left.binary &&
            right.deleted == left.deleted &&
            right.tombstoneIdentity == left.tombstoneIdentity &&
            right.payload?.length == left.payload?.length &&
            right.payload?.sha256 == left.payload?.sha256;

  String _newId(String prefix) {
    final timestamp = _now().toUtc().microsecondsSinceEpoch;
    final entropy = List.generate(8, (_) => _random.nextInt(256));
    return '$prefix-$timestamp-${base64Url.encode(entropy).replaceAll('=', '')}';
  }
}

final class _PendingSyncPreview {
  const _PendingSyncPreview({
    required this.local,
    required this.base,
    required this.remoteRevision,
    required this.remoteHead,
    required this.remote,
  });

  final CloudSyncSnapshotData local;
  final CloudSyncSnapshotData base;
  final String? remoteRevision;
  final SnapshotHead? remoteHead;
  final CloudSyncSnapshotData? remote;
}

final class _PendingRestorePreview {
  const _PendingRestorePreview({
    required this.target,
    required this.local,
    required this.remoteRevision,
  });

  final CloudSyncSnapshotData target;
  final CloudSyncSnapshotData local;
  final String? remoteRevision;
}
