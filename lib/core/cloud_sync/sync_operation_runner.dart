import 'backend/cloud_sync_backend.dart';
import 'data_source.dart';
import 'journal.dart';
import 'models.dart';
import 'operation.dart';
import 'snapshot_uploader.dart';
import 'sync_types.dart';
import 'telemetry_log.dart';

class SyncOperationRunner {
  const SyncOperationRunner({
    required this.backend,
    required this.dataSource,
    required this.journalStore,
    required this.now,
  });

  final CloudSyncBackend backend;
  final CloudSyncDataSource dataSource;
  final JournalStore journalStore;
  final DateTime Function() now;

  Future<SyncJournal> prepare({
    required String operationId,
    required JournalOperation operation,
    required String snapshotId,
    required CloudSyncSnapshotData target,
    required CloudSyncSnapshotData? recoveryPoint,
    required String? expectedRevision,
    required bool uploadRequired,
  }) => journalStore.runExclusive(() async {
    if (await journalStore.read() != null) {
      throw StateError('A cloud sync operation is pending recovery.');
    }
    final appliesLocally = operation != JournalOperation.uploadLocal;
    if (appliesLocally != (recoveryPoint != null)) {
      throw ArgumentError(
        appliesLocally
            ? 'A local recovery point is required.'
            : 'Upload-only operations must not create a recovery point.',
        'recoveryPoint',
      );
    }
    await dataSource.stage(operationId, target, recoveryPoint: recoveryPoint);
    final fingerprint = await dataSource.stagedFingerprint(operationId);
    final journal = SyncJournal(
      operationId: operationId,
      operation: operation,
      phase: JournalPhase.prepared,
      updatedAt: now().toUtc(),
      snapshotId: snapshotId,
      targetFingerprint: fingerprint,
      expectedRevision: expectedRevision,
      uploadRequired: uploadRequired,
    );
    await journalStore.write(journal);
    return journal;
  });

  Future<CloudSyncSnapshotData> run(
    SyncJournal journal, {
    required OperationToken token,
    required bool recovering,
    SyncProgressCallback? onProgress,
  }) async {
    if (!identical(OperationToken.current, token)) {
      return token.runInScope(
        () => run(
          journal,
          token: token,
          recovering: recovering,
          onProgress: onProgress,
        ),
      );
    }
    var current = journal;
    var baseSaved = false;
    try {
      final target = await dataSource.readStaged(current.operationId);
      if (await dataSource.stagedFingerprint(current.operationId) !=
          current.targetFingerprint) {
        throw const CloudFormatException('staged target fingerprint mismatch');
      }
      if (current.uploadRequired &&
          current.phase.index <= JournalPhase.committingHead.index) {
        current =
            await ResumableSnapshotUploader(
              backend: backend,
              dataSource: dataSource,
              now: now,
            ).resume(
              journal: current,
              snapshot: target,
              token: token,
              checkpoint: journalStore.write,
              onProgress: onProgress,
            );
      }
      if (current.appliesLocally) {
        if (recovering && current.phase == JournalPhase.applyStarted) {
          await dataSource.rollbackForRecovery(current.operationId);
        }
        if (current.phase != JournalPhase.savingBase) {
          await _assertRemoteGuard(current);
          current = current.copyWith(
            phase: JournalPhase.applyStarted,
            now: now(),
          );
          await journalStore.write(current);
          onProgress?.call(const SyncProgress(phase: SyncPhase.applying));
          await token.checkpoint();
          await dataSource.apply(current.operationId);
          await _assertRemoteGuard(current);
        }
      }
      current = current.copyWith(phase: JournalPhase.savingBase, now: now());
      await journalStore.write(current);
      onProgress?.call(const SyncProgress(phase: SyncPhase.saving));
      await dataSource.saveBase(target, current.snapshotId);
      baseSaved = true;
      await _complete(current);
      onProgress?.call(const SyncProgress(phase: SyncPhase.completed));
      return target;
    } catch (error, stackTrace) {
      final durable = await journalStore.read() ?? current;
      _logOperationFailure(error, durable);
      if (baseSaved || _mustRemainRecoverable(error, durable)) rethrow;
      await _rollbackAndClean(durable, error, stackTrace, onProgress);
      rethrow;
    }
  }

  Future<void> _assertRemoteGuard(SyncJournal journal) async {
    final remote = await backend.readHead();
    if (journal.uploadRequired) {
      if (remote == null) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Remote HEAD disappeared before the local apply.',
        );
      }
      final head = SnapshotHead.decode(remote.bytes);
      if (head.snapshotId != journal.snapshotId ||
          head.manifestSha256 != journal.manifestSha256) {
        throw const CloudBackendException(
          CloudBackendErrorKind.conflict,
          'Remote HEAD advanced before the local apply.',
        );
      }
      return;
    }
    if (remote?.revision != journal.expectedRevision) {
      throw const CloudBackendException(
        CloudBackendErrorKind.conflict,
        'Remote HEAD advanced before the local apply.',
      );
    }
  }

  Future<void> discardPending() async {
    final journal = await journalStore.read();
    if (journal == null) return;
    if (journal.phase == JournalPhase.completed) {
      await dataSource.completeOperation(journal.operationId);
      await journalStore.delete();
      return;
    }
    if (journal.appliesLocally &&
        journal.phase.index >= JournalPhase.applyStarted.index &&
        journal.phase.index <= JournalPhase.savingBase.index) {
      await dataSource.rollbackForRecovery(journal.operationId);
    }
    if (journal.phase == JournalPhase.savingBase) {
      await dataSource.restoreBaseForRecovery(journal.operationId);
    }
    await dataSource.rollback(journal.operationId);
    await journalStore.delete();
  }

  Future<void> recoverPending({
    OperationToken? token,
    SyncProgressCallback? onProgress,
  }) async {
    final journal = await journalStore.read();
    if (journal == null) return;
    if (journal.phase == JournalPhase.completed) {
      await dataSource.completeOperation(journal.operationId);
      await journalStore.delete();
      return;
    }
    if (journal.phase == JournalPhase.rollbackStarted) {
      if (journal.appliesLocally) {
        await dataSource.rollbackForRecovery(journal.operationId);
      }
      await dataSource.rollback(journal.operationId);
      await journalStore.delete();
      return;
    }
    await run(
      journal,
      token: token ?? OperationToken(),
      recovering: true,
      onProgress: onProgress,
    );
  }

  Future<void> _complete(SyncJournal journal) async {
    await journalStore.write(
      journal.copyWith(phase: JournalPhase.completed, now: now()),
    );
    await dataSource.completeOperation(journal.operationId);
    await journalStore.delete();
  }

  Future<void> _rollbackAndClean(
    SyncJournal journal,
    Object original,
    StackTrace stackTrace,
    SyncProgressCallback? onProgress,
  ) async {
    onProgress?.call(const SyncProgress(phase: SyncPhase.rollingBack));
    final rollback = journal.copyWith(
      phase: JournalPhase.rollbackStarted,
      error: original,
      stackTrace: stackTrace,
      now: now(),
    );
    await journalStore.write(rollback);
    try {
      if (journal.appliesLocally &&
          journal.phase.index >= JournalPhase.applyStarted.index) {
        await dataSource.rollbackForRecovery(journal.operationId);
      }
      await dataSource.rollback(journal.operationId);
      await journalStore.write(
        rollback.copyWith(phase: JournalPhase.completed, now: now()),
      );
      await journalStore.delete();
    } catch (rollbackError) {
      throw CloudSyncRollbackException(original, rollbackError);
    }
  }
}

void _logOperationFailure(Object error, SyncJournal journal) {
  final details = error is CloudBackendException
      ? 'kind=${error.kind.name}, status=${error.statusCode ?? 'none'}, '
            'message=${error.message}'
      : 'type=${error.runtimeType}';
  logCloudSyncMetrics(
    'Cloud sync operation failed: operation=${journal.operation.name}, '
    'phase=${journal.phase.name}, $details',
  );
}

bool _mustRemainRecoverable(Object error, SyncJournal journal) {
  if (journal.phase == JournalPhase.completed) return true;
  if (error is CloudBackendException &&
      (error.kind == CloudBackendErrorKind.network ||
          error.kind == CloudBackendErrorKind.invalidResponse)) {
    return true;
  }
  if (error is OperationCancelledException &&
      journal.uploadRequired &&
      (journal.phase == JournalPhase.committingHead ||
          journal.phase == JournalPhase.applyStarted ||
          journal.phase == JournalPhase.savingBase)) {
    return true;
  }
  // A base write or process-adjacent local IO failure is safely replayable.
  return journal.phase == JournalPhase.savingBase &&
      error is! OperationCancelledException;
}
