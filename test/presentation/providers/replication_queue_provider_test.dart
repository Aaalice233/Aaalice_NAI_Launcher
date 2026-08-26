import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';

void main() {
  test(
    'character and negative-only codex tasks survive queue operations',
    () async {
      final queueStorage = _MemoryReplicationQueueStorage();
      final stateStorage = _MemoryQueueStateStorage();
      final container = ProviderContainer(
        overrides: [
          replicationQueueStorageProvider.overrideWithValue(queueStorage),
          queueStateStorageProvider.overrideWithValue(stateStorage),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        replicationQueueNotifierProvider.notifier,
      );
      final task = ReplicationTask.create(
        prompt: '',
        negativePrompt: 'lowres',
        applyNegativePrompt: true,
        characterPrompts: const [
          ReplicationCharacterPromptSnapshot(prompt: '1girl, red hair'),
        ],
      );

      expect(await notifier.add(task), isTrue);
      expect(await notifier.duplicateTask(task.id), isTrue);

      var state = container.read(replicationQueueNotifierProvider);
      expect(state.tasks, hasLength(2));
      final duplicate = state.tasks.last;
      expect(duplicate.applyNegativePrompt, isTrue);
      expect(duplicate.negativePrompt, 'lowres');
      expect(duplicate.characterPrompts?.single.prompt, '1girl, red hair');

      await notifier.moveToFailedPool(task.id);
      state = container.read(replicationQueueNotifierProvider);
      expect(state.failedTasks.single.id, task.id);

      await notifier.retryFailedTask(task.id);
      state = container.read(replicationQueueNotifierProvider);
      expect(state.failedTasks, isEmpty);
      expect(state.tasks.first.id, task.id);
    },
  );
}

class _MemoryReplicationQueueStorage extends ReplicationQueueStorage {
  List<ReplicationTask> tasks = [];

  @override
  List<ReplicationTask> load() => List.of(tasks);

  @override
  Future<void> save(List<ReplicationTask> tasks) async {
    this.tasks = List.of(tasks);
  }
}

class _MemoryQueueStateStorage extends QueueStateStorage {
  List<ReplicationTask> failedTasks = [];

  @override
  List<ReplicationTask> loadFailedTasks() => List.of(failedTasks);

  @override
  Future<void> saveFailedTasks(List<ReplicationTask> tasks) async {
    failedTasks = List.of(tasks);
  }
}
