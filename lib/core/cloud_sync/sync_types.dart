import 'data_source.dart';
import 'merge.dart';
import 'operation.dart';

typedef SyncProgressCallback = void Function(SyncProgress progress);

class SyncPreview {
  const SyncPreview({
    required this.localSnapshot,
    required this.snapshot,
    required this.conflicts,
    required this.remoteRevision,
    required this.remoteSnapshotId,
    required this.remoteSnapshot,
  });

  final CloudSyncSnapshotData localSnapshot;
  final CloudSyncSnapshotData snapshot;
  final List<MergeConflict<CloudSyncRecord>> conflicts;
  final String? remoteRevision;
  final String? remoteSnapshotId;
  final CloudSyncSnapshotData? remoteSnapshot;

  bool get canApply => conflicts.isEmpty;
}

enum SnapshotChangeKind { added, modified, deleted }

class SnapshotChange {
  const SnapshotChange({
    required this.id,
    required this.kind,
    required this.record,
  });
  final String id;
  final SnapshotChangeKind kind;
  final CloudSyncRecord record;
}

class RestorePreview {
  const RestorePreview({required this.snapshotId, required this.changes});
  final String snapshotId;
  final List<SnapshotChange> changes;
}

class SyncOutcome {
  const SyncOutcome({
    required this.snapshotId,
    required this.uploaded,
    required this.snapshot,
  });
  final String snapshotId;
  final bool uploaded;
  final CloudSyncSnapshotData snapshot;
}

class DeferredSyncConflictException implements Exception {
  const DeferredSyncConflictException(this.conflicts);
  final List<MergeConflict<CloudSyncRecord>> conflicts;
  @override
  String toString() =>
      'DeferredSyncConflictException(${conflicts.length} conflicts)';
}

class CloudSyncRollbackException implements Exception {
  const CloudSyncRollbackException(this.originalError, this.rollbackError);
  final Object originalError;
  final Object rollbackError;
  @override
  String toString() =>
      'Cloud sync failed: $originalError; rollback also failed: $rollbackError';
}

class SnapshotHistoryEntry {
  const SnapshotHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.objectCount,
  });
  final String id;
  final DateTime createdAt;
  final int objectCount;
}
