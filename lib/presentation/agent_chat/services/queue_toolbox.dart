import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/services/anlas_calculator.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/models/queue/replication_task.dart';
import '../../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../../data/models/queue/replication_task_status.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../../providers/subscription_provider.dart';
import 'defined_agent_tool.dart';
import 'queue_toolbox_serialization.dart';
import 'toolbox_json.dart';

enum QueueControlPreparationKind { start, resume }

class QueueControlPreparation {
  QueueControlPreparation({
    required this.kind,
    required this.taskIds,
    required this.taskFingerprints,
    required this.estimatedAnlas,
  }) : id = const Uuid().v4(),
       createdAt = DateTime.now();

  final String id;
  final DateTime createdAt;
  final QueueControlPreparationKind kind;
  final List<String> taskIds;
  final List<String> taskFingerprints;
  final int estimatedAnlas;
}

class QueueControlRuntime {
  final Map<String, QueueControlPreparation> _values = {};

  QueueControlPreparation add(QueueControlPreparation value) {
    _values[value.id] = value;
    return value;
  }

  QueueControlPreparation? take(String id) => _values.remove(id);

  QueueControlPreparation? get(String id) => _values[id];
}

/// Full lifecycle controls for the application's persistent generation queue.
class QueueToolbox {
  QueueToolbox(this._ref, this._runtime);

  final Ref _ref;
  final QueueControlRuntime _runtime;

  List<AgentTool> tools() => [
    _inspectQueue(),
    _inspectTask(),
    _reorder(),
    _deleteTask(),
    _prepareControl(),
    _start(),
    _pause(),
    _resume(),
    _stop(),
    _retryFailed(),
    _retryAllFailed(),
    _clearFailed(),
    _clearCompleted(),
  ];

  DefinedAgentTool _inspectQueue() => DefinedAgentTool(
    name: 'inspect_generation_queue',
    label: 'Inspect Generation Queue',
    description:
        'Inspect queue execution state and safe summaries of pending, failed, and completed tasks.',
    parameters: toolboxObject(
      properties: {
        'include_completed': {'type': 'boolean'},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
      },
    ),
    executeFn: (_, params) async {
      final queue = _ref.read(replicationQueueNotifierProvider);
      final execution = _ref.read(queueExecutionNotifierProvider);
      final limit = (params['limit'] as int? ?? 50).clamp(1, 100);
      return agentToolJsonResult({
        'ok': true,
        'execution': queueExecutionJson(execution),
        'capacity': kMaxQueueCapacity,
        'remaining_capacity': queue.remainingCapacity,
        'pending': [
          for (final task in queue.tasks.take(limit)) replicationTaskJson(task),
        ],
        'failed': [
          for (final task in queue.failedTasks.take(limit))
            replicationTaskJson(task),
        ],
        if (params['include_completed'] == true)
          'completed': [
            for (final task in queue.completedTasks.reversed.take(limit))
              replicationTaskJson(task),
          ],
      });
    },
  );

  DefinedAgentTool _inspectTask() => DefinedAgentTool(
    name: 'inspect_generation_queue_task',
    label: 'Inspect Generation Queue Task',
    description:
        'Inspect one pending, running, failed, or completed queue task.',
    parameters: _taskIdSchema,
    executeFn: (_, params) async {
      final task = _findTask(params['task_id'] as String);
      return task == null
          ? agentToolError('not_found', 'Queue task not found.')
          : agentToolJsonResult({
              'ok': true,
              'task': replicationTaskJson(task, full: true),
            });
    },
  );

  DefinedAgentTool _reorder() => DefinedAgentTool(
    name: 'reorder_generation_queue_task',
    label: 'Reorder Generation Queue Task',
    description: 'Move a pending queue task to a new zero-based queue index.',
    parameters: toolboxObject(
      properties: {
        'task_id': {'type': 'string'},
        'new_index': {'type': 'integer', 'minimum': 0},
      },
      required: const ['task_id', 'new_index'],
    ),
    executeFn: (_, params) async {
      final state = _ref.read(replicationQueueNotifierProvider);
      final oldIndex = state.tasks.indexWhere(
        (task) => task.id == params['task_id'],
      );
      if (oldIndex < 0) {
        return agentToolError('not_found', 'Queue task not found.');
      }
      final moved = await _ref
          .read(replicationQueueNotifierProvider.notifier)
          .reorder(oldIndex, params['new_index'] as int);
      return moved
          ? agentToolJsonResult({
              'ok': true,
              'task_id': params['task_id'],
              'new_index': params['new_index'],
            })
          : agentToolError(
              'not_pending',
              'Only pending tasks can be reordered.',
            );
    },
  );

  DefinedAgentTool _deleteTask() => DefinedAgentTool(
    name: 'delete_generation_queue_task',
    label: 'Delete Generation Queue Task',
    description: 'Delete one pending task. Running tasks cannot be deleted.',
    parameters: _taskIdSchema,
    executeFn: (_, params) async {
      final id = params['task_id'] as String;
      final removed = await _ref
          .read(replicationQueueNotifierProvider.notifier)
          .remove(id);
      return removed
          ? agentToolJsonResult({'ok': true, 'task_id': id})
          : agentToolError('not_pending', 'Pending queue task not found.');
    },
  );

  DefinedAgentTool _prepareControl() => DefinedAgentTool(
    name: 'prepare_generation_queue_execution',
    label: 'Prepare Generation Queue Execution',
    description:
        'Prepare queue start or resume and return an exact current estimated Anlas total. No task is started.',
    parameters: toolboxObject(
      properties: {
        'action': {
          'type': 'string',
          'enum': QueueControlPreparationKind.values
              .map((value) => value.name)
              .toList(),
        },
      },
      required: const ['action'],
    ),
    executeFn: (_, params) async {
      final kind = QueueControlPreparationKind.values.firstWhere(
        (value) => value.name == params['action'],
      );
      final tasks = _ref
          .read(replicationQueueNotifierProvider)
          .tasks
          .where((task) => task.status == ReplicationTaskStatus.pending)
          .toList();
      if (tasks.isEmpty) {
        return agentToolError('queue_empty', 'Queue is empty.');
      }
      late final int estimate;
      try {
        estimate = _estimate(tasks);
      } on FormatException catch (error) {
        return agentToolError(
          'invalid_queue_snapshot',
          'A queued generation snapshot is invalid: $error',
        );
      }
      if (estimate == AnlasCalculator.invalidCost) {
        return agentToolError('invalid_cost', 'Unable to estimate queue cost.');
      }
      final preparation = _runtime.add(
        QueueControlPreparation(
          kind: kind,
          taskIds: tasks.map((task) => task.id).toList(),
          taskFingerprints: tasks.map(_taskFingerprint).toList(),
          estimatedAnlas: estimate,
        ),
      );
      return agentToolJsonResult({
        'ok': true,
        'queue_preparation_id': preparation.id,
        'action': kind.name,
        'task_count': tasks.length,
        'estimated_anlas': estimate,
        'confirmation_required': true,
      });
    },
  );

  DefinedAgentTool _start() => _confirmedControl(
    name: 'start_generation_queue',
    label: 'Start Generation Queue',
    kind: QueueControlPreparationKind.start,
    action: () async {
      final result = await _ref
          .read(queueExecutionNotifierProvider.notifier)
          .startQueue();
      return switch (result) {
        QueueStartResult.started => null,
        QueueStartResult.empty => 'queue_empty',
        QueueStartResult.busy => 'queue_busy',
        QueueStartResult.authRequired => 'authentication_required',
      };
    },
  );

  DefinedAgentTool _pause() => DefinedAgentTool(
    name: 'pause_generation_queue',
    label: 'Pause Generation Queue',
    description: 'Pause queue execution after the active request settles.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      final execution = _ref.read(queueExecutionNotifierProvider);
      if (!execution.isRunning && !execution.isReady) {
        return agentToolError('not_running', 'Queue is not running.');
      }
      await _ref.read(queueExecutionNotifierProvider.notifier).pause();
      return agentToolJsonResult({'ok': true, 'status': 'paused'});
    },
  );

  DefinedAgentTool _resume() => _confirmedControl(
    name: 'resume_generation_queue',
    label: 'Resume Generation Queue',
    kind: QueueControlPreparationKind.resume,
    action: () async {
      if (!_ref.read(queueExecutionNotifierProvider).isPaused) {
        return 'not_paused';
      }
      await _ref.read(queueExecutionNotifierProvider.notifier).resume();
      return null;
    },
  );

  DefinedAgentTool _stop() => DefinedAgentTool(
    name: 'stop_generation_queue',
    label: 'Stop Generation Queue',
    description:
        'Stop queue execution and preserve remaining pending tasks for later.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      await _ref.read(queueExecutionNotifierProvider.notifier).stopExecution();
      return agentToolJsonResult({'ok': true, 'status': 'stopped'});
    },
  );

  DefinedAgentTool _retryFailed() => DefinedAgentTool(
    name: 'retry_failed_generation_queue_task',
    label: 'Retry Failed Generation Queue Task',
    description: 'Move one failed task back to the pending queue.',
    parameters: _taskIdSchema,
    executeFn: (_, params) async {
      final id = params['task_id'] as String;
      final retried = await _ref
          .read(queueExecutionNotifierProvider.notifier)
          .retryFailedTask(id);
      return retried
          ? agentToolJsonResult({'ok': true, 'task_id': id})
          : agentToolError(
              'not_found_or_full',
              'Failed task could not be retried.',
            );
    },
  );

  DefinedAgentTool _retryAllFailed() => DefinedAgentTool(
    name: 'retry_all_failed_generation_queue_tasks',
    label: 'Retry All Failed Queue Tasks',
    description:
        'Move failed tasks back to pending until queue capacity is full.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      final ids = _ref
          .read(replicationQueueNotifierProvider)
          .failedTasks
          .map((task) => task.id)
          .toList();
      var count = 0;
      for (final id in ids) {
        if (await _ref
            .read(queueExecutionNotifierProvider.notifier)
            .retryFailedTask(id)) {
          count++;
        }
      }
      return agentToolJsonResult({'ok': true, 'retried': count});
    },
  );

  DefinedAgentTool _clearFailed() => DefinedAgentTool(
    name: 'clear_failed_generation_queue_tasks',
    label: 'Clear Failed Queue Tasks',
    description: 'Permanently remove all failed task records.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      await _ref
          .read(queueExecutionNotifierProvider.notifier)
          .clearFailedTasks();
      return agentToolJsonResult({'ok': true});
    },
  );

  DefinedAgentTool _clearCompleted() => DefinedAgentTool(
    name: 'clear_completed_generation_queue_tasks',
    label: 'Clear Completed Queue Tasks',
    description:
        'Remove completed task records from the current runtime history.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      _ref
          .read(replicationQueueNotifierProvider.notifier)
          .clearCompletedTasks();
      return agentToolJsonResult({'ok': true});
    },
  );

  DefinedAgentTool _confirmedControl({
    required String name,
    required String label,
    required QueueControlPreparationKind kind,
    required Future<String?> Function() action,
  }) => DefinedAgentTool(
    name: name,
    label: label,
    description:
        'Execute a prepared queue action. confirmed must be explicitly true.',
    parameters: toolboxObject(
      properties: {
        'queue_preparation_id': {'type': 'string'},
        'confirmed': {'type': 'boolean', 'const': true},
      },
      required: const ['queue_preparation_id', 'confirmed'],
    ),
    executeFn: (_, params) async {
      if (params['confirmed'] != true) {
        return agentToolError(
          'confirmation_required',
          'confirmed must be true.',
        );
      }
      final preparation = _runtime.take(
        params['queue_preparation_id'] as String,
      );
      if (preparation == null || preparation.kind != kind) {
        return agentToolError(
          'preparation_not_found',
          'Prepare this queue action again.',
        );
      }
      final currentTasks = _ref
          .read(replicationQueueNotifierProvider)
          .tasks
          .where((task) => task.status == ReplicationTaskStatus.pending)
          .toList();
      if (!_sameList(
            currentTasks.map((task) => task.id).toList(),
            preparation.taskIds,
          ) ||
          !_sameList(
            currentTasks.map(_taskFingerprint).toList(),
            preparation.taskFingerprints,
          )) {
        return agentToolError(
          'queue_changed',
          'Queue changed after estimation; prepare it again.',
        );
      }
      final error = await action();
      return error == null
          ? agentToolJsonResult({
              'ok': true,
              'status': kind == QueueControlPreparationKind.start
                  ? 'running'
                  : 'resumed',
              'estimated_anlas': preparation.estimatedAnlas,
            })
          : agentToolError(error, 'Queue action could not be completed.');
    },
  );

  ReplicationTask? _findTask(String id) {
    final state = _ref.read(replicationQueueNotifierProvider);
    return [
      ...state.tasks,
      ...state.failedTasks,
      ...state.completedTasks,
    ].where((task) => task.id == id).firstOrNull;
  }

  String _taskFingerprint(ReplicationTask task) =>
      sha256.convert(utf8.encode(jsonEncode(task.toJson()))).toString();

  int _estimate(List<ReplicationTask> tasks) {
    final base = _ref.read(generationParamsNotifierProvider);
    final subscription = _ref.read(subscriptionNotifierProvider).subscription;
    final tier = subscription?.isOpus == true ? AnlasCalculator.opusTier : 0;
    var total = 0;
    for (final task in tasks) {
      final params = task.generationSnapshot == null
          ? base.copyWith(
              prompt: task.prompt,
              negativePrompt: task.applyNegativePrompt
                  ? task.negativePrompt
                  : base.negativePrompt,
              model: task.model ?? base.model,
              sampler: task.sampler ?? base.sampler,
              steps: task.steps ?? base.steps,
              scale: task.cfgScale ?? base.scale,
              seed: task.seed ?? -1,
              width: task.width ?? base.width,
              height: task.height ?? base.height,
              nSamples: 1,
            )
          : ReplicationTaskGenerationSnapshot.decode(
              task.generationSnapshot!,
            ).copyWith(
              prompt: task.prompt,
              negativePrompt: task.applyNegativePrompt
                  ? task.negativePrompt
                  : base.negativePrompt,
              nSamples: 1,
            );
      final cost = AnlasCalculator.calculateRequestCost(
        width: params.width,
        height: params.height,
        steps: params.steps,
        batchCount: 1,
        batchSize: _ref.read(imagesPerRequestProvider),
        smea: params.effectiveSmea,
        smeaDyn: params.effectiveSmeaDyn,
        model: params.model,
        subscriptionTier: tier,
        opusQuotaExhausted: subscription?.usage?.isNegative ?? false,
        strength: switch (params.action) {
          ImageGenerationAction.img2img => params.strength,
          ImageGenerationAction.infill => params.inpaintStrength,
          ImageGenerationAction.generate => 1,
        },
        extraPerSampleCost: AnlasCalculator.resolvePreciseReferenceExtraCost(
          params,
        ),
        extraPerRequestCost: AnlasCalculator.resolveVibeReferenceExtraCost(
          params,
        ),
        oneTimeCost: AnlasCalculator.resolveVibeEncodingCost(params),
      );
      if (cost == AnlasCalculator.invalidCost) return cost;
      total += cost;
    }
    return total;
  }
}

final _taskIdSchema = toolboxObject(
  properties: {
    'task_id': {'type': 'string'},
  },
  required: const ['task_id'],
);

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
