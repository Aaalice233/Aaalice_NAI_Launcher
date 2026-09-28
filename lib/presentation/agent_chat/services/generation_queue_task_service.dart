import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import 'defined_agent_tool.dart';
import 'generation_preparation_runtime.dart';
import 'generation_tool_results.dart';

class GenerationQueueTaskService {
  GenerationQueueTaskService(
    this._ref, {
    required int maxQueueSnapshotBytes,
    required int maxPersistedQueueSnapshotBytes,
  }) : _maxQueueSnapshotBytes = maxQueueSnapshotBytes,
       _maxPersistedQueueSnapshotBytes = maxPersistedQueueSnapshotBytes;
  final Ref _ref;
  final int _maxQueueSnapshotBytes;
  final int _maxPersistedQueueSnapshotBytes;
  Future<AgentToolResult> queueTask(
    Map<String, dynamic> _, {
    required GenerationPreparation prepared,
  }) async {
    final base = prepared.params;
    final prompt = base.prompt.trim();
    if (prompt.isEmpty) {
      return generationErrorResult('Parameter "prompt" is required.');
    }
    final requestedCount = prepared.count;
    if (requestedCount < 1 || requestedCount > kMaxQueueCapacity) {
      return generationErrorResult(
        'Parameter "count" must be between 1 and $kMaxQueueCapacity.',
      );
    }
    final remaining = _ref
        .read(replicationQueueNotifierProvider)
        .remainingCapacity;
    if (remaining <= 0) {
      return generationErrorResult(
        'Queue is full (capacity $kMaxQueueCapacity). Clear or complete tasks first.',
      );
    }
    if (remaining < requestedCount) {
      return generationErrorResult(
        'Queue has room for $remaining task(s), but this confirmed preparation '
        'requires $requestedCount. Prepare again for the current capacity.',
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
    final generationSnapshot = ReplicationTaskGenerationSnapshot.encode(
      queuedParams,
      batchSize: prepared.batchSize,
    );
    final snapshotBytes = utf8.encode(jsonEncode(generationSnapshot)).length;
    final existingSnapshotBytes = _ref
        .read(replicationQueueNotifierProvider)
        .tasks
        .map((task) => task.generationSnapshot)
        .whereType<Map<String, dynamic>>()
        .fold<int>(
          0,
          (total, snapshot) => total + utf8.encode(jsonEncode(snapshot)).length,
        );
    if (snapshotBytes > _maxQueueSnapshotBytes ||
        existingSnapshotBytes + snapshotBytes * count >
            _maxPersistedQueueSnapshotBytes) {
      return agentToolError(
        'queue_snapshot_too_large',
        'The complete generation snapshot is too large to persist safely. '
            'Reduce the task count or the number and size of image references.',
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
      final added = await _ref
          .read(replicationQueueNotifierProvider.notifier)
          .addAll(tasks);
      if (added == 0) {
        return generationErrorResult(
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
      return generationTextResult(
        jsonEncode({
          'ok': true,
          'added': added,
          if (added < requestedCount) 'requested': requestedCount,
          'queue_pending': queue.count,
          'queue_started': started,
        }),
      );
    } catch (e) {
      return generationErrorResult('Failed to enqueue: $e');
    }
  }

  // -------------------------------------------------------------------------
  // get_generation_status
  // -------------------------------------------------------------------------
}
