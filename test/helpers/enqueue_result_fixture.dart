import 'dart:io';

import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

enum EnqueueFixture {
  saved,
  full,
  withdrawn,
  started,
  failed,
  removed,
  unsaved,
  unexpected;

  EnqueueResult resolve(List<ReplicationTask> tasks) {
    if (this == unexpected) throw StateError('private enqueue error');
    final ids = [for (final task in tasks) task.id];
    if (this == saved) return EnqueueResult.saved(ids);
    if (this == full) return const EnqueueResult.saved([]);
    return EnqueueResult.settled(
      queuedTaskIds: const [],
      startedTaskIds: this == started ? [ids.first] : const [],
      failedTaskIds: this == failed ? ids : const [],
      withdrawnTaskIds: switch (this) {
        withdrawn || unsaved => ids,
        started => ids.skip(1).toList(),
        _ => const [],
      },
      removedTaskIds: this == removed ? ids : const [],
      indexSaved: this != unsaved,
      failure: ReplicationQueueWriteException(
        'Failed to save the queue index',
        const FileSystemException('private file error'),
      ),
    );
  }
}

class ResultQueueNotifier extends ReplicationQueueNotifier {
  ResultQueueNotifier(this.fixture);

  final EnqueueFixture fixture;
  List<ReplicationTask> received = [];

  @override
  ReplicationQueueState build() => const ReplicationQueueState();

  @override
  Future<EnqueueResult> add(ReplicationTask task) => addAll([task]);

  @override
  Future<EnqueueResult> addAll(List<ReplicationTask> tasks) async {
    received = tasks;
    return fixture.resolve(tasks);
  }

  @override
  Future<DuplicateTaskResult> duplicateTask(String taskId) async {
    final enqueue = fixture.resolve([ReplicationTask.create(prompt: 'copy')]);
    return (
      result: switch (enqueue.outcome) {
        EnqueueOutcome.saved =>
          enqueue.accepted == 0
              ? DuplicateTaskStatus.queueFull
              : DuplicateTaskStatus.added,
        EnqueueOutcome.withdrawn => DuplicateTaskStatus.saveFailed,
        EnqueueOutcome.startedBeforeSaved =>
          DuplicateTaskStatus.startedBeforeSaved,
      },
      enqueue: enqueue,
    );
  }
}
