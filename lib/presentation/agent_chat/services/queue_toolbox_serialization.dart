import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../providers/queue_execution_provider.dart';

Map<String, dynamic> queueExecutionJson(QueueExecutionState state) => {
  'status': state.status.name,
  'current_task_id': state.currentTaskId,
  'completed_count': state.completedCount,
  'failed_count': state.failedCount,
  'skipped_count': state.skippedCount,
  'total_tasks_in_session': state.totalTasksInSession,
  'progress': state.progress,
};

/// 快照部分只读索引里的引用，不读图片文件。
Map<String, dynamic> replicationTaskJson(
  ReplicationTask task, {
  bool full = false,
}) => {
  'task_id': task.id,
  'status': task.status.name,
  'prompt': task.prompt,
  if (full) 'negative_prompt': task.negativePrompt,
  'source': task.source.name,
  'created_at': task.createdAt.toIso8601String(),
  'model': task.model,
  'sampler': task.sampler,
  'steps': task.steps,
  'scale': task.cfgScale,
  'seed': task.seed,
  'width': task.width,
  'height': task.height,
  'retry_count': task.retryCount,
  'error': task.errorMessage,
  if (task.generationSnapshot != null)
    'generation_snapshot': ReplicationTaskGenerationSnapshot.describe(
      task.generationSnapshot!,
    ),
  'characters': [
    for (final character in task.characterPrompts ?? const [])
      {
        'prompt': character.prompt,
        'negative_prompt': character.negativePrompt,
        'enabled': character.enabled,
        'position_x': character.positionX,
        'position_y': character.positionY,
      },
  ],
};
