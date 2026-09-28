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
    'generation_snapshot': _generationSnapshotSummary(task.generationSnapshot!),
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

Map<String, dynamic> _generationSnapshotSummary(Map<String, dynamic> snapshot) {
  try {
    final params = ReplicationTaskGenerationSnapshot.decode(snapshot);
    return {
      'schema_version': snapshot['schemaVersion'],
      'valid': true,
      'action': params.action.name,
      'model': params.model,
      'width': params.width,
      'height': params.height,
      'steps': params.steps,
      'sampler': params.sampler,
      'scale': params.scale,
      'seed': params.seed,
      'has_source_image': params.sourceImage != null,
      'has_mask_image': params.maskImage != null,
      'vibe_reference_count': params.vibeReferencesV4.length,
      'precise_reference_count': params.preciseReferences.length,
      'character_count': params.characters.length,
    };
  } on FormatException catch (error) {
    return {
      'schema_version': snapshot['schemaVersion'],
      'valid': false,
      'error': '$error',
    };
  }
}
