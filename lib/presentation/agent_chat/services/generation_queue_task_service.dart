import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import 'defined_agent_tool.dart';
import 'generation_preparation_runtime.dart';

class GenerationQueueTaskService {
  GenerationQueueTaskService(this._ref);
  final Ref _ref;
  Future<AgentToolResult> queueTask(
    Map<String, dynamic> _, {
    required GenerationPreparation prepared,
  }) async {
    final base = prepared.params;
    final prompt = base.prompt.trim();
    if (prompt.isEmpty) {
      return agentToolError(
        'missing_prompt',
        'Parameter "prompt" is required.',
      );
    }
    final requestedCount = prepared.count;
    if (requestedCount < 1 || requestedCount > kMaxQueueCapacity) {
      return agentToolError(
        'invalid_count',
        'Parameter "count" must be between 1 and $kMaxQueueCapacity.',
      );
    }
    final count = requestedCount;
    final autoStart = prepared.autoStart;
    final negativePrompt = base.negativePrompt;
    final characterPrompts = base.characters
        .map(
          (character) => ReplicationCharacterPromptSnapshot(
            prompt: character.prompt,
            negativePrompt: character.negativePrompt,
            positionX: base.useCoords ? character.positionX : null,
            positionY: base.useCoords ? character.positionY : null,
          ),
        )
        .toList(growable: false);
    final queuedParams = base.copyWith(
      prompt: prompt,
      negativePrompt: negativePrompt,
      nSamples: 1,
    );
    // Agent 提交方必须显式给出聚焦状态，否则执行时会继承生成页残留的聚焦选区
    final generationSnapshot = await ReplicationTaskGenerationSnapshot.encode(
      queuedParams,
      batchSize: prepared.batchSize,
      focused: const QueuedFocusedInpaint.disabled(),
    );
    // 先按当前容量整批拒绝；addAll 落盘图片期间队列仍可能被填满，结果里如实报告部分入队
    final remaining = _ref
        .read(replicationQueueNotifierProvider)
        .remainingCapacity;
    if (remaining <= 0) {
      return agentToolError(
        'queue_full',
        'Queue is full (capacity $kMaxQueueCapacity). Clear or complete tasks first.',
      );
    }
    if (remaining < requestedCount) {
      return agentToolError(
        'queue_capacity_insufficient',
        'Queue has room for $remaining task(s), but this confirmed preparation '
            'requires $requestedCount. Prepare again for the current capacity.',
      );
    }
    final tasks = List.generate(count, (_) {
      return ReplicationTask.create(
        prompt: prompt,
        negativePrompt: negativePrompt,
        applyNegativePrompt: true,
        characterPrompts: characterPrompts,
        generationSnapshot: generationSnapshot,
        source: ReplicationTaskSource.local,
        seed: base.seed,
        sampler: base.sampler,
        steps: base.steps,
        cfgScale: base.scale,
        model: base.model,
        width: base.width,
        height: base.height,
      );
    });
    try {
      final result = await _ref
          .read(replicationQueueNotifierProvider.notifier)
          .addAll(tasks);
      if (result.outcome != EnqueueOutcome.saved) return _unsaved(result);
      final added = result.queuedTaskIds.length;
      if (added == 0) {
        return agentToolError(
          'queue_full',
          'Queue is full (capacity $kMaxQueueCapacity). Clear or complete tasks first.',
        );
      }
      String started = 'not started';
      if (autoStart) {
        final result = await _ref
            .read(queueExecutionNotifierProvider.notifier)
            .startQueue();
        started = switch (result) {
          QueueStartResult.started => 'started',
          QueueStartResult.busy => 'busy (already running)',
          QueueStartResult.empty => 'empty',
          QueueStartResult.authRequired => 'authentication required',
        };
      }
      final queue = _ref.read(replicationQueueNotifierProvider);
      return agentToolJsonResult({
        'ok': true,
        'added': added,
        if (added < requestedCount) ...{
          'requested': requestedCount,
          'partial': true,
          'note':
              'The queue filled up while this request was being stored; '
              'only $added of $requestedCount task(s) were queued.',
        },
        'queue_pending': queue.count,
        'queue_started': started,
      });
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to enqueue a generation task',
        '${error.runtimeType}',
        stackTrace,
        'GenerationQueueTaskService',
      );
      return agentToolError(
        'queue_enqueue_failed',
        'Failed to enqueue (${error.runtimeType}).',
      );
    }
  }

  // 已开始的任务没有撤回，再次提交就是重复生成；没发出请求的任务不能说会扣点
  AgentToolResult _unsaved(EnqueueResult result) {
    final started = result.startedTaskIds;
    final failed = result.failedTaskIds;
    final queued = result.queuedTaskIds.length;
    final withdrawn = result.withdrawnTaskIds.length;
    final removed = result.removedTaskIds.length;
    final nothingKept = started.isEmpty && failed.isEmpty && queued == 0;
    final message = [
      if (result.failure case final failure?)
        'Saving the queue failed (${failure.causeType}).',
      if (nothingKept) 'No task was queued.',
      if (started.isNotEmpty)
        '${started.length} task(s) had already started executing or finished '
            'and were not withdrawn: ${started.join(', ')}. '
            'Do not submit them again.',
      if (failed.isNotEmpty)
        '${failed.length} task(s) failed before the queue was saved; inspect '
            'the queue or failed pool: ${failed.join(', ')}.',
      if (queued > 0) '$queued task(s) were saved in the queue.',
      if (withdrawn > 0) '$withdrawn task(s) were withdrawn and will not run.',
      if (removed > 0)
        '$removed task(s) were removed from the queue before the save '
            'finished.',
      if (!result.indexSaved)
        'The queue index is still not saved: after a restart, withdrawn or '
            'removed tasks may reappear and started tasks may be missing. '
            'Inspect the queue before submitting again.'
      else if (nothingKept)
        'Submitting again is safe.'
      else if (withdrawn > 0)
        'Only the withdrawn task(s) can be submitted again.',
    ].join(' ');
    return agentToolError(
      started.isEmpty
          ? 'queue_enqueue_failed'
          : 'queue_enqueue_started_unsaved',
      message,
      details: {
        'started_task_ids': started,
        'failed_task_ids': failed,
        'started_count': started.length,
        'failed_count': failed.length,
        'queued_task_ids': result.queuedTaskIds,
        'withdrawn_task_ids': result.withdrawnTaskIds,
        'removed_task_ids': result.removedTaskIds,
        'queued_count': queued,
        'withdrawn_count': withdrawn,
        'removed_count': removed,
        'index_saved': result.indexSaved,
      },
    );
  }

  // -------------------------------------------------------------------------
  // get_generation_status
  // -------------------------------------------------------------------------
}
