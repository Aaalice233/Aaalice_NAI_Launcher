import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/merge.dart';
import '../../../core/cloud_sync/operation.dart';
import '../../../core/cloud_sync/telemetry.dart';
import 'cloud_sync_conflict_mapper.dart';
import 'cloud_sync_progress_mapper.dart';
import 'cloud_sync_ui_provider.dart';

typedef CloudSyncStateReader = CloudSyncUiState Function();
typedef CloudSyncStateWriter = void Function(CloudSyncUiState state);
typedef CloudSyncErrorRecorder =
    void Function(Object error, {bool resetActivity});

/// Executes coordinator-backed preview, transfer, merge, and restore flows.
/// Connection setup, credentials, and lifecycle remain owned by the
/// application service.
class CloudSyncOperationRunner {
  const CloudSyncOperationRunner({
    required this.coordinator,
    required this.readState,
    required this.writeState,
    required this.recordError,
    required this.readPendingFfdkjIntent,
    required this.persistSyncState,
  });

  final SyncCoordinator? Function() coordinator;
  final CloudSyncStateReader readState;
  final CloudSyncStateWriter writeState;
  final CloudSyncErrorRecorder recordError;
  final bool Function() readPendingFfdkjIntent;
  final Future<void> Function(String revision, DateTime lastSync)
  persistSyncState;

  Future<void> previewInitial() async {
    readState().ensureNoPendingPreview();
    final preview = await _trace(
      'previewInitial',
      () => buildCloudSyncPreview(_requireCoordinator()),
    );
    final state = readState();
    writeState(
      state.copyWith(
        remoteRevision: preview.remoteRevision,
        conflicts: preview.conflicts,
        pendingPreview: CloudSyncPreviewView(changes: preview.changes),
      ),
    );
  }

  Future<void> runSync(
    OperationToken operation, {
    CloudSyncInitialAction? direction,
  }) async {
    final coordinator = _requireCoordinator();
    _start();
    try {
      final outcome = await _trace(
        'sync',
        () async => switch (direction) {
          CloudSyncInitialAction.upload => await coordinator.uploadLocal(
            token: operation,
            onProgress: _updateProgress,
          ),
          CloudSyncInitialAction.download => await coordinator.downloadRemote(
            token: operation,
            onProgress: _updateProgress,
          ),
          _ when readState().remoteExists != true =>
            await coordinator.uploadLocal(
              token: operation,
              onProgress: _updateProgress,
            ),
          _
              when readState().capabilityMode ==
                  CloudSyncCapabilityMode.manualBackupOnly =>
            await coordinator.uploadLocal(
              token: operation,
              onProgress: _updateProgress,
            ),
          _ => await coordinator.synchronize(
            token: operation,
            onProgress: _updateProgress,
          ),
        },
      );
      final lastSync = DateTime.now().toUtc();
      final state = readState();
      writeState(
        state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          lastSync: lastSync,
          remoteRevision: outcome.snapshotId,
          remoteExists: true,
          clearProgress: true,
          conflicts: const [],
          snapshots: outcome.uploaded
              ? _prependSnapshot(
                  state.snapshots,
                  CloudSyncSnapshotView(
                    id: outcome.snapshotId,
                    createdAt: lastSync,
                    objectCount: outcome.snapshot.records.length,
                  ),
                )
              : state.snapshots,
          clearPendingPreview: true,
          pendingFfdkjInstall: readPendingFfdkjIntent(),
        ),
      );
      await persistSyncState(outcome.snapshotId, lastSync);
    } catch (error) {
      _recordOperationError(error);
      rethrow;
    }
  }

  Future<void> loadHistory() async {
    final state = readState();
    if (!state.supportsHistory) return;
    try {
      final history = await _trace(
        'history',
        () => _requireCoordinator().history(),
      );
      writeState(
        readState().copyWith(
          snapshots: history
              .map(
                (entry) => CloudSyncSnapshotView(
                  id: entry.id,
                  createdAt: entry.createdAt,
                  objectCount: entry.objectCount,
                ),
              )
              .toList(growable: false),
          clearError: true,
        ),
      );
    } catch (error) {
      recordError(error, resetActivity: false);
      rethrow;
    }
  }

  Future<void> runResolvedMerge(
    OperationToken operation,
    Map<String, CloudSyncConflictChoice> choices,
  ) async {
    final coordinator = _requireCoordinator();
    _start();
    try {
      final outcome = await _trace(
        'resolvedMerge',
        () => coordinator.synchronize(
          token: operation,
          onProgress: _updateProgress,
          resolve: (conflict) => switch (choices[conflict.id]) {
            CloudSyncConflictChoice.local => ConflictChoice.local,
            CloudSyncConflictChoice.remote => ConflictChoice.remote,
            CloudSyncConflictChoice.keepBoth => ConflictChoice.keepBoth,
            null => ConflictChoice.defer,
          },
        ),
      );
      choices.clear();
      final lastSync = DateTime.now().toUtc();
      final state = readState();
      writeState(
        state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          lastSync: lastSync,
          remoteRevision: outcome.snapshotId,
          conflicts: const [],
          clearProgress: true,
          clearPendingPreview: true,
          pendingFfdkjInstall: readPendingFfdkjIntent(),
        ),
      );
      await persistSyncState(outcome.snapshotId, lastSync);
    } catch (error) {
      if (error is CloudPreviewStaleException) choices.clear();
      _recordOperationError(error);
      rethrow;
    }
  }

  Future<void> previewRestore(
    String snapshotId,
    OperationToken operation,
  ) async {
    readState().ensureNoPendingPreview();
    final coordinator = _requireCoordinator();
    _start(clearError: false);
    try {
      final preview = await _trace(
        'previewRestore',
        () => coordinator.previewRestore(
          snapshotId,
          token: operation,
          onProgress: _updateProgress,
        ),
      );
      final counts = <CloudSyncDataKind, List<int>>{};
      for (final change in preview.changes) {
        final kind = await cloudSyncRecordKind(change.record);
        final values = counts.putIfAbsent(kind, () => [0, 0, 0]);
        values[change.kind.index]++;
      }
      final state = readState();
      writeState(
        state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          clearProgress: true,
          pendingPreview: CloudSyncPreviewView(
            snapshotId: snapshotId,
            isRestore: true,
            changes: [
              for (final entry in counts.entries)
                CloudSyncChangeSummary(
                  kind: entry.key,
                  added: entry.value[0],
                  modified: entry.value[1],
                  deleted: entry.value[2],
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      recordError(error, resetActivity: true);
      rethrow;
    }
  }

  Future<void> restore(String snapshotId, OperationToken operation) async {
    final coordinator = _requireCoordinator();
    _start();
    try {
      final outcome = await _trace(
        'restore',
        () => coordinator.restore(
          snapshotId,
          token: operation,
          onProgress: _updateProgress,
        ),
      );
      final lastSync = DateTime.now().toUtc();
      final state = readState();
      writeState(
        state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          lastSync: lastSync,
          remoteRevision: outcome.snapshotId,
          clearProgress: true,
          clearPendingPreview: true,
          pendingFfdkjInstall: readPendingFfdkjIntent(),
        ),
      );
      await persistSyncState(outcome.snapshotId, lastSync);
    } catch (error) {
      _recordOperationError(error);
      rethrow;
    }
  }

  void _recordOperationError(Object error) {
    if (error is CloudPreviewStaleException) {
      writeState(
        readState().copyWith(conflicts: const [], clearPendingPreview: true),
      );
    }
    recordError(error, resetActivity: true);
  }

  static List<CloudSyncSnapshotView> _prependSnapshot(
    List<CloudSyncSnapshotView> existing,
    CloudSyncSnapshotView latest,
  ) => [
    latest,
    for (final snapshot in existing)
      if (snapshot.id != latest.id) snapshot,
  ];

  SyncCoordinator _requireCoordinator() =>
      coordinator() ?? (throw StateError('Cloud sync is not connected.'));

  void _start({bool clearError = true}) {
    final state = readState();
    writeState(
      state.copyWith(
        activityStatus: CloudSyncActivityStatus.syncing,
        progress: mapCloudSyncProgress(
          const SyncProgress(phase: SyncPhase.preparing),
        ),
        clearError: clearError,
      ),
    );
  }

  Future<T> _trace<T>(String operation, Future<T> Function() action) =>
      CloudSyncTelemetry.trace(
        operation,
        () {
          CloudSyncTelemetry.enterStage(SyncPhase.preparing.name);
          return action();
        },
        onComplete: (metrics) {
          writeState(
            readState().copyWith(
              metrics: CloudSyncMetricsView(
                elapsedMilliseconds: metrics.elapsed.inMilliseconds,
                requestCount: metrics.requestCount,
                bytesRead: metrics.bytesRead,
                bytesWritten: metrics.bytesWritten,
                hashPasses: metrics.hashPasses,
                payloadReads: metrics.payloadReads,
                localBytesRead: metrics.localBytesRead,
                localBytesWritten: metrics.localBytesWritten,
                flushes: metrics.flushes,
                stageMilliseconds: {
                  for (final entry in metrics.stageDurations.entries)
                    entry.key: entry.value.inMilliseconds,
                },
              ),
            ),
          );
        },
      );

  void _updateProgress(SyncProgress progress) {
    CloudSyncTelemetry.enterStage(progress.phase.name);
    final state = readState();
    writeState(state.copyWith(progress: mapCloudSyncProgress(progress)));
  }
}
