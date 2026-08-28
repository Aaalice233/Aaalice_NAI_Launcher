import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/merge.dart';
import '../../../core/cloud_sync/operation.dart';
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
    required this.afterSuccessfulWrite,
    required this.persistSyncState,
  });

  final SyncCoordinator? Function() coordinator;
  final CloudSyncStateReader readState;
  final CloudSyncStateWriter writeState;
  final CloudSyncErrorRecorder recordError;
  final bool Function() readPendingFfdkjIntent;
  final Future<void> Function() afterSuccessfulWrite;
  final Future<void> Function(String revision, DateTime lastSync)
  persistSyncState;

  Future<void> previewInitial() async {
    readState().ensureNoPendingPreview();
    final preview = await buildCloudSyncPreview(_requireCoordinator());
    final state = readState();
    writeState(
      state.copyWith(
        remoteRevision: preview.remoteRevision,
        conflicts: preview.conflicts,
        pendingPreview: CloudSyncPreviewView(
          title: 'Initial merge',
          changes: preview.changes,
        ),
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
      final outcome = switch (direction) {
        CloudSyncInitialAction.upload => await coordinator.uploadLocal(
          token: operation,
          onProgress: _updateProgress,
        ),
        CloudSyncInitialAction.download => await coordinator.downloadRemote(
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
      };
      final history = readState().supportsHistory
          ? await coordinator.history()
          : const <SnapshotHistoryEntry>[];
      final lastSync = DateTime.now().toUtc();
      final state = readState();
      writeState(
        state.copyWith(
          activityStatus: CloudSyncActivityStatus.idle,
          lastSync: lastSync,
          remoteRevision: outcome.snapshotId,
          clearProgress: true,
          conflicts: const [],
          snapshots: history
              .map(
                (entry) => CloudSyncSnapshotView(
                  id: entry.id,
                  createdAt: entry.createdAt,
                  summary: '${entry.objectCount} objects',
                ),
              )
              .toList(),
          clearPendingPreview: true,
          pendingFfdkjInstall: readPendingFfdkjIntent(),
        ),
      );
      await persistSyncState(outcome.snapshotId, lastSync);
      if (direction != CloudSyncInitialAction.download) {
        await afterSuccessfulWrite();
      }
    } catch (error) {
      recordError(error, resetActivity: true);
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
      final outcome = await coordinator.synchronize(
        token: operation,
        onProgress: _updateProgress,
        resolve: (conflict) => switch (choices[conflict.id]) {
          CloudSyncConflictChoice.local => ConflictChoice.local,
          CloudSyncConflictChoice.remote => ConflictChoice.remote,
          CloudSyncConflictChoice.keepBoth => ConflictChoice.keepBoth,
          null => ConflictChoice.defer,
        },
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
      await afterSuccessfulWrite();
    } catch (error) {
      recordError(error, resetActivity: true);
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
      final preview = await coordinator.previewRestore(
        snapshotId,
        token: operation,
        onProgress: _updateProgress,
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
            title: snapshotId,
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
      final outcome = await coordinator.restore(
        snapshotId,
        token: operation,
        onProgress: _updateProgress,
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
      await afterSuccessfulWrite();
    } catch (error) {
      recordError(error, resetActivity: true);
      rethrow;
    }
  }

  SyncCoordinator _requireCoordinator() =>
      coordinator() ?? (throw StateError('Cloud sync is not connected.'));

  void _start({bool clearError = true}) {
    final state = readState();
    writeState(
      state.copyWith(
        activityStatus: CloudSyncActivityStatus.syncing,
        clearError: clearError,
      ),
    );
  }

  void _updateProgress(SyncProgress progress) {
    final state = readState();
    writeState(state.copyWith(progress: mapCloudSyncProgress(progress)));
  }
}
