import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/replication_queue_blob_store_provider.dart';
import '../../core/storage/replication_queue_storage.dart';
import '../../core/storage/queue_state_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/replication_task_generation_snapshot.dart';
import '../../data/models/queue/replication_task_status.dart';
import '../../data/services/replication_queue_enqueue_result.dart';
import '../../data/services/replication_queue_persistence.dart';

export '../../data/services/replication_queue_enqueue_result.dart';
export '../../data/services/replication_queue_persistence.dart'
    show ReplicationQueueWriteException;

part 'replication_queue_provider.g.dart';

/// 队列容量限制
const int kMaxQueueCapacity = 50;

/// [ReplicationQueueNotifier.duplicateTask] 的结果。
enum DuplicateTaskStatus {
  added,
  queueFull,
  notFound,
  nothingToGenerate,
  invalidSnapshot,

  saveFailed,

  /// 队列保存失败，但副本已被执行引擎开始执行，没有撤回。
  startedBeforeSaved,
}

typedef DuplicateTaskResult = ({
  DuplicateTaskStatus result,
  EnqueueResult? enqueue,
});

/// 复刻队列状态
class ReplicationQueueState {
  final List<ReplicationTask> tasks;
  final List<ReplicationTask> failedTasks;
  final List<ReplicationTask> completedTasks;
  final bool isLoading;
  final bool isSelectionMode;
  final Set<String> selectedTaskIds;

  const ReplicationQueueState({
    this.tasks = const [],
    this.failedTasks = const [],
    this.completedTasks = const [],
    this.isLoading = false,
    this.isSelectionMode = false,
    this.selectedTaskIds = const {},
  });

  ReplicationQueueState copyWith({
    List<ReplicationTask>? tasks,
    List<ReplicationTask>? failedTasks,
    List<ReplicationTask>? completedTasks,
    bool? isLoading,
    bool? isSelectionMode,
    Set<String>? selectedTaskIds,
  }) {
    return ReplicationQueueState(
      tasks: tasks ?? this.tasks,
      failedTasks: failedTasks ?? this.failedTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      isLoading: isLoading ?? this.isLoading,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedTaskIds: selectedTaskIds ?? this.selectedTaskIds,
    );
  }

  /// 队列是否为空
  bool get isEmpty => tasks.isEmpty;

  /// 队列是否已满
  bool get isFull => tasks.length >= kMaxQueueCapacity;

  /// 队列数量
  int get count => tasks.length;

  /// 剩余容量
  int get remainingCapacity => kMaxQueueCapacity - tasks.length;

  /// 是否有失败任务
  bool get hasFailedTasks => failedTasks.isNotEmpty;

  /// 失败任务数量
  int get failedCount => failedTasks.length;

  /// 完成任务数量
  int get completedCount => completedTasks.length;

  /// 选中的任务数量
  int get selectedCount => selectedTaskIds.length;

  Iterable<ReplicationTask> get selectableTasks =>
      tasks.where((task) => task.status == ReplicationTaskStatus.pending);

  /// 是否全选
  bool get isAllSelected {
    final selectableIds = selectableTasks.map((task) => task.id).toSet();
    return selectableIds.isNotEmpty &&
        selectedTaskIds.containsAll(selectableIds) &&
        selectedTaskIds.length == selectableIds.length;
  }
}

/// 复刻队列状态管理 Provider
///
/// 管理复刻任务队列，包括添加、删除、重排序等操作
/// 使用 keepAlive: true 确保状态在页面切换时保持
@Riverpod(keepAlive: true)
class ReplicationQueueNotifier extends _$ReplicationQueueNotifier {
  late final ReplicationQueuePersistence _persistence;
  final List<_EnqueueWatch> _enqueueWatches = [];
  int _clearRevision = 0;

  @override
  ReplicationQueueState build() {
    _persistence = ReplicationQueuePersistence(
      queueStorage: ref.read(replicationQueueStorageProvider),
      stateStorage: ref.read(queueStateStorageProvider),
      blobStore: ref.read(replicationQueueBlobStoreProvider),
      liveState: () => (tasks: state.tasks, failedTasks: state.failedTasks),
    );
    ref.onDispose(_persistence.dispose);
    // 同步加载持久化数据（Hive Box 已在启动 Splash 阶段打开并完成快照迁移）
    return _loadFromStorageSync();
  }

  /// 同步加载队列数据
  ReplicationQueueState _loadFromStorageSync() {
    try {
      final (:tasks, :failedTasks) = _persistence.load();

      // 加载时将所有 running 状态的任务重置为 pending
      // （因为应用重启后实际上没有任务在运行）
      final restoredTasks = tasks.map((task) {
        if (task.status == ReplicationTaskStatus.running) {
          return task.copyWith(status: ReplicationTaskStatus.pending);
        }
        return task;
      }).toList();

      return ReplicationQueueState(
        tasks: restoredTasks,
        failedTasks: failedTasks,
        isLoading: false,
      );
    } catch (e) {
      return const ReplicationQueueState(isLoading: false);
    }
  }

  /// 序列化持久化写入，避免运行状态变化与清空操作并发时旧快照回写。
  Future<void> _saveToStorage() =>
      _persistence.saveTasks(List<ReplicationTask>.unmodifiable(state.tasks));

  Future<void> _saveFailedTasks() => _persistence.saveFailedTasks(
    List<ReplicationTask>.unmodifiable(state.failedTasks),
  );

  /// 存储失败按实际去向返回，其余错误撤回始终待执行的任务并补写索引后原样抛出。
  Future<EnqueueResult> add(ReplicationTask task) async {
    if (state.isFull) return const EnqueueResult.saved([]);
    return _enqueue([task]);
  }

  /// 批量添加任务到队列，超出剩余容量的部分不接收；结果语义同 [add]。
  Future<EnqueueResult> addAll(List<ReplicationTask> tasks) async {
    final remaining = state.remainingCapacity;
    if (tasks.isEmpty || remaining <= 0) return const EnqueueResult.saved([]);
    return _enqueue(tasks.take(remaining).toList());
  }

  /// 先落盘快照图片再进入状态；图片落盘失败时状态不变。
  Future<EnqueueResult> _enqueue(List<ReplicationTask> tasks) async {
    if (!ReplicationQueuePersistence.needsIntern(tasks)) return _append(tasks);
    final clearRevision = _clearRevision;
    final InternedTasks interned;
    try {
      interned = await _persistence.intern(tasks);
    } on ReplicationQueueWriteException catch (failure) {
      return EnqueueResult.withdrawn([
        for (final task in tasks) task.id,
      ], failure);
    }
    try {
      if (clearRevision != _clearRevision) {
        return EnqueueResult.settled(
          queuedTaskIds: const [],
          startedTaskIds: const [],
          failedTaskIds: const [],
          withdrawnTaskIds: [for (final task in tasks) task.id],
          removedTaskIds: const [],
          indexSaved: true,
          failure: null,
        );
      }
      // 落盘期间队列可能已被其他入口填满
      return await _append(
        interned.tasks.take(state.remainingCapacity).toList(),
      );
    } finally {
      _persistence.release(interned);
    }
  }

  Future<EnqueueResult> _append(List<ReplicationTask> tasks) async {
    if (tasks.isEmpty) return const EnqueueResult.saved([]);
    return _saveEnqueued(tasks, () => [...state.tasks, ...tasks]);
  }

  Future<EnqueueResult> _saveEnqueued(
    List<ReplicationTask> added,
    List<ReplicationTask> Function() tasksWithAdded,
  ) async {
    final ids = [for (final task in added) task.id];
    final watch = _EnqueueWatch(ids.toSet());
    _enqueueWatches.add(watch);
    try {
      // 先登记再进状态：状态通知会同步触发监听方，执行引擎可能立刻改动这些任务
      state = state.copyWith(tasks: tasksWithAdded());
      final (:held, :error, :stackTrace) = await _persistence.saveTasksTracking(
        List<ReplicationTask>.unmodifiable(state.tasks),
        watch.taskIds,
      );
      if (held.length == ids.length) {
        if (error == null || error is ReplicationQueueWriteException) {
          return EnqueueResult.saved(ids);
        }
        Error.throwWithStackTrace(error, stackTrace!);
      }
      final groups = _classifyUnsaved(ids, held, watch.leftPending);
      final withdrawn = groups.withdrawn.toSet();
      state = state.copyWith(
        tasks: state.tasks
            .where((task) => !withdrawn.contains(task.id))
            .toList(),
        selectedTaskIds: state.selectedTaskIds.difference(withdrawn),
      );
      final (error: resaveError, stackTrace: resaveStackTrace) =
          await _resaveAfterFailedEnqueue();
      if (error != null && error is! ReplicationQueueWriteException) {
        Error.throwWithStackTrace(error, stackTrace!);
      }
      if (resaveError != null &&
          resaveError is! ReplicationQueueWriteException) {
        Error.throwWithStackTrace(resaveError, resaveStackTrace!);
      }
      return EnqueueResult.settled(
        queuedTaskIds: groups.queued,
        startedTaskIds: groups.started,
        failedTaskIds: groups.failed,
        withdrawnTaskIds: groups.withdrawn,
        removedTaskIds: groups.removed,
        indexSaved: resaveError == null,
        failure: error as ReplicationQueueWriteException?,
      );
    } finally {
      _enqueueWatches.remove(watch);
    }
  }

  ({
    List<String> queued,
    List<String> started,
    List<String> failed,
    List<String> withdrawn,
    List<String> removed,
  })
  _classifyUnsaved(
    List<String> ids,
    Set<String> held,
    Set<String> leftPending,
  ) {
    final inQueue = {for (final task in state.tasks) task.id: task.status};
    final inFailedPool = {for (final task in state.failedTasks) task.id};
    final groups = (
      queued: <String>[],
      started: <String>[],
      failed: <String>[],
      withdrawn: <String>[],
      removed: <String>[],
    );
    for (final id in ids) {
      final status = inQueue[id];
      if (held.contains(id)) {
        groups.queued.add(id);
      } else if (inFailedPool.contains(id) ||
          status == ReplicationTaskStatus.failed) {
        groups.failed.add(id);
      } else if (leftPending.contains(id)) {
        groups.started.add(id);
      } else if (status != null) {
        groups.withdrawn.add(id);
      } else {
        groups.removed.add(id);
      }
    }
    return groups;
  }

  // 等待期间新发出的保存可能带着已撤回的任务落地，补写一次让索引与当前状态一致
  Future<({Object? error, StackTrace? stackTrace})>
  _resaveAfterFailedEnqueue() async {
    try {
      await _saveToStorage();
      return (error: null, stackTrace: null);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to save the queue after a failed enqueue',
        error is ReplicationQueueWriteException
            ? error.causeType
            : '${error.runtimeType}',
        error is ReplicationQueueWriteException ? error.stackTrace : stackTrace,
        'ReplicationQueue',
      );
      return (error: error, stackTrace: stackTrace);
    }
  }

  void _noteLeftPending(String taskId) {
    for (final watch in _enqueueWatches) {
      if (watch.taskIds.contains(taskId)) watch.leftPending.add(taskId);
    }
  }

  /// 移除指定的待执行任务。运行中的任务只能由执行引擎结算。
  Future<bool> remove(String taskId) async {
    final index = state.tasks.indexWhere((task) => task.id == taskId);
    if (index < 0 ||
        state.tasks[index].status == ReplicationTaskStatus.running) {
      return false;
    }

    state = state.copyWith(
      tasks: state.tasks.where((task) => task.id != taskId).toList(),
      selectedTaskIds: state.selectedTaskIds.difference({taskId}),
    );
    await _saveToStorage();
    return true;
  }

  /// 执行失败后的内部结算入口：在同一次状态更新里把运行中的任务移到队尾并恢复为待执行。
  ///
  /// 任务与它引用的图片始终留在状态里；保存失败时与其他变更一样保留内存状态并抛出。
  Future<bool> requeueRunningTaskForRetry(String taskId) async {
    final index = state.tasks.indexWhere((task) => task.id == taskId);
    if (index < 0 ||
        state.tasks[index].status != ReplicationTaskStatus.running) {
      return false;
    }

    final task = state.tasks[index];
    state = state.copyWith(
      tasks: [
        for (final queued in state.tasks)
          if (queued.id != taskId) queued,
        task.copyWith(
          status: ReplicationTaskStatus.pending,
          retryCount: 0,
          errorMessage: null,
          startedAt: null,
        ),
      ],
      selectedTaskIds: state.selectedTaskIds.difference({taskId}),
    );
    await _saveToStorage();
    return true;
  }

  /// 重新排序待执行任务；当前运行任务始终保留在其前方。
  Future<bool> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= state.tasks.length ||
        newIndex < 0 ||
        newIndex > state.tasks.length ||
        state.tasks[oldIndex].status != ReplicationTaskStatus.pending) {
      return false;
    }

    final tasks = List<ReplicationTask>.from(state.tasks);
    final task = tasks.removeAt(oldIndex);
    final runningPrefixLength = tasks
        .takeWhile((item) => item.status == ReplicationTaskStatus.running)
        .length;
    final insertionIndex = newIndex.clamp(runningPrefixLength, tasks.length);
    tasks.insert(insertionIndex, task);

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
    return true;
  }

  /// 清空队列
  Future<void> clear() async {
    _clearRevision++;
    state = state.copyWith(
      tasks: [],
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _persistence.clearTasks();
  }

  /// 获取队列中的下一个任务（不移除）
  ReplicationTask? getNext() {
    if (state.isEmpty) return null;
    return state.tasks.first;
  }

  /// 按 ID 原子结算任务，禁止在目标缺失时回退到队首。
  Future<bool> markCompleted(String taskId) async {
    final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0 ||
        state.tasks[taskIndex].status != ReplicationTaskStatus.running) {
      return false;
    }

    final completedTask = state.tasks[taskIndex].copyWith(
      status: ReplicationTaskStatus.completed,
      completedAt: DateTime.now(),
    );
    final remainingTasks = List<ReplicationTask>.from(state.tasks)
      ..removeAt(taskIndex);
    final completedTasks = [...state.completedTasks, completedTask];
    if (completedTasks.length > 100) {
      completedTasks.removeRange(0, completedTasks.length - 100);
    }

    state = state.copyWith(
      tasks: remainingTasks,
      completedTasks: completedTasks,
      selectedTaskIds: state.selectedTaskIds.difference({taskId}),
    );
    await _saveToStorage();
    return true;
  }

  void removeCompletedTask(String taskId) {
    state = state.copyWith(
      completedTasks: state.completedTasks
          .where((task) => task.id != taskId)
          .toList(),
    );
  }

  void clearCompletedTasks() {
    state = state.copyWith(completedTasks: const []);
  }

  /// 更新任务状态。
  Future<bool> updateTaskStatus(
    String taskId,
    ReplicationTaskStatus status, {
    String? errorMessage,
  }) async {
    final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0) return false;

    final tasks = List<ReplicationTask>.from(state.tasks);
    final task = tasks[taskIndex];
    if (status != ReplicationTaskStatus.pending) _noteLeftPending(taskId);
    tasks[taskIndex] = task.copyWith(
      status: status,
      errorMessage: errorMessage,
      startedAt: status == ReplicationTaskStatus.running
          ? DateTime.now()
          : status == ReplicationTaskStatus.pending
          ? null
          : task.startedAt,
      completedAt: status.isTerminal ? DateTime.now() : null,
    );

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
    return true;
  }

  /// 取消或终止执行时把仍锁定的运行任务恢复为可再次执行的待处理状态。
  Future<bool> resetRunningTask(String taskId) async {
    final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0 ||
        state.tasks[taskIndex].status != ReplicationTaskStatus.running) {
      return false;
    }

    final tasks = List<ReplicationTask>.from(state.tasks);
    tasks[taskIndex] = tasks[taskIndex].copyWith(
      status: ReplicationTaskStatus.pending,
      errorMessage: null,
      startedAt: null,
      completedAt: null,
    );
    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
    return true;
  }

  /// 更新待执行任务。执行快照启动后不可被编辑覆盖。
  Future<bool> updateTask(ReplicationTask updatedTask) async {
    final taskIndex = state.tasks.indexWhere(
      (task) => task.id == updatedTask.id,
    );
    if (taskIndex < 0 ||
        state.tasks[taskIndex].status != ReplicationTaskStatus.pending) {
      return false;
    }

    final previousTask = state.tasks[taskIndex];
    var generationSnapshot = updatedTask.generationSnapshot;
    if (generationSnapshot != null) {
      // 只有入队会落盘图片，编辑不能带入新的待落盘快照
      if (ReplicationTaskGenerationSnapshot.isPending(generationSnapshot)) {
        return false;
      }
      if (previousTask.prompt != updatedTask.prompt ||
          previousTask.negativePrompt != updatedTask.negativePrompt) {
        try {
          generationSnapshot = ReplicationTaskGenerationSnapshot.withTaskText(
            generationSnapshot,
            prompt: updatedTask.prompt,
            negativePrompt: updatedTask.negativePrompt,
          );
        } on FormatException {
          return false;
        }
      }
    }
    final tasks = List<ReplicationTask>.from(state.tasks);
    tasks[taskIndex] = updatedTask.copyWith(
      generationSnapshot: generationSnapshot,
      status: ReplicationTaskStatus.pending,
      startedAt: null,
      completedAt: null,
    );

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
    return true;
  }

  /// 将待执行任务移到运行任务之后的首位。
  Future<void> pinToTop(String taskId) async {
    final taskIndex = state.tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0 ||
        state.tasks[taskIndex].status != ReplicationTaskStatus.pending) {
      return;
    }

    final tasks = List<ReplicationTask>.from(state.tasks);
    final task = tasks.removeAt(taskIndex);
    final insertionIndex = tasks
        .takeWhile((item) => item.status == ReplicationTaskStatus.running)
        .length;
    if (taskIndex == insertionIndex) return;
    tasks.insert(insertionIndex, task);

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
  }

  /// 移入失败任务池
  Future<void> moveToFailedPool(String taskId) async {
    final task = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => ReplicationTask.create(prompt: ''),
    );

    if (!_hasGeneratableContent(task)) return;

    _noteLeftPending(taskId);
    final failedTask = task.copyWith(
      status: ReplicationTaskStatus.failed,
      completedAt: DateTime.now(),
    );

    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
      failedTasks: [...state.failedTasks, failedTask],
    );

    await _saveToStorage();
    await _saveFailedTasks();
  }

  /// 从失败池重试任务（移到当前运行任务之后）。
  Future<bool> retryFailedTask(String taskId) async {
    final taskIndex = state.failedTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0 || state.isFull) return false;

    final retriedTask = state.failedTasks[taskIndex].copyWith(
      status: ReplicationTaskStatus.pending,
      retryCount: 0,
      errorMessage: null,
      startedAt: null,
      completedAt: null,
    );
    if (!_hasGeneratableContent(retriedTask)) return false;

    final tasks = List<ReplicationTask>.from(state.tasks);
    final insertionIndex = tasks
        .takeWhile((item) => item.status == ReplicationTaskStatus.running)
        .length;
    tasks.insert(insertionIndex, retriedTask);
    state = state.copyWith(
      tasks: tasks,
      failedTasks: state.failedTasks
          .where((task) => task.id != taskId)
          .toList(),
    );

    await _saveToStorage();
    await _saveFailedTasks();
    return true;
  }

  /// 从失败池重新入队（移到队尾）。
  Future<bool> requeueFailedTask(String taskId) async {
    final taskIndex = state.failedTasks.indexWhere((task) => task.id == taskId);
    if (taskIndex < 0 || state.isFull) return false;

    final requeuedTask = state.failedTasks[taskIndex].copyWith(
      status: ReplicationTaskStatus.pending,
      retryCount: 0,
      errorMessage: null,
      startedAt: null,
      completedAt: null,
    );
    if (!_hasGeneratableContent(requeuedTask)) return false;

    state = state.copyWith(
      tasks: [...state.tasks, requeuedTask],
      failedTasks: state.failedTasks
          .where((task) => task.id != taskId)
          .toList(),
    );

    await _saveToStorage();
    await _saveFailedTasks();
    return true;
  }

  /// 清空失败任务池
  Future<void> clearFailedTasks() async {
    state = state.copyWith(failedTasks: []);
    await _saveFailedTasks();
  }

  /// 删除单个失败任务
  Future<void> removeFailedTask(String taskId) async {
    state = state.copyWith(
      failedTasks: state.failedTasks.where((t) => t.id != taskId).toList(),
    );
    await _saveFailedTasks();
  }

  // ========== 批量操作 ==========

  /// 进入/退出选择模式
  void toggleSelectionMode() {
    state = state.copyWith(
      isSelectionMode: !state.isSelectionMode,
      selectedTaskIds: state.isSelectionMode ? {} : state.selectedTaskIds,
    );
  }

  /// 退出选择模式
  void exitSelectionMode() {
    state = state.copyWith(isSelectionMode: false, selectedTaskIds: {});
  }

  /// 切换待执行任务的选中状态。
  void toggleTaskSelection(String taskId) {
    final task = state.tasks.cast<ReplicationTask?>().firstWhere(
      (item) => item?.id == taskId,
      orElse: () => null,
    );
    if (task?.status != ReplicationTaskStatus.pending) return;

    final newSelected = Set<String>.from(state.selectedTaskIds);
    if (newSelected.contains(taskId)) {
      newSelected.remove(taskId);
    } else {
      newSelected.add(taskId);
    }
    state = state.copyWith(selectedTaskIds: newSelected);
  }

  /// 全选待执行任务。
  void selectAll() {
    state = state.copyWith(
      selectedTaskIds: state.selectableTasks.map((task) => task.id).toSet(),
    );
  }

  /// 反选待执行任务。
  void invertSelection() {
    final allIds = state.selectableTasks.map((task) => task.id).toSet();
    final selectedIds = state.selectedTaskIds.intersection(allIds);
    final newSelected = allIds.difference(selectedIds);
    state = state.copyWith(selectedTaskIds: newSelected);
  }

  /// 取消全选
  void clearSelection() {
    state = state.copyWith(selectedTaskIds: {});
  }

  /// 批量删除选中的待执行任务。
  Future<void> deleteSelected() async {
    if (state.selectedTaskIds.isEmpty) return;

    state = state.copyWith(
      tasks: state.tasks
          .where(
            (task) =>
                task.status != ReplicationTaskStatus.pending ||
                !state.selectedTaskIds.contains(task.id),
          )
          .toList(),
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _saveToStorage();
  }

  /// 批量置顶选中的待执行任务，运行任务保持在最前方。
  Future<void> pinSelectedToTop() async {
    if (state.selectedTaskIds.isEmpty) return;

    final runningTasks = state.tasks
        .where((task) => task.status == ReplicationTaskStatus.running)
        .toList();
    final selectedTasks = state.tasks
        .where(
          (task) =>
              task.status == ReplicationTaskStatus.pending &&
              state.selectedTaskIds.contains(task.id),
        )
        .toList();
    final otherTasks = state.tasks
        .where(
          (task) =>
              task.status != ReplicationTaskStatus.running &&
              !selectedTasks.any((selected) => selected.id == task.id),
        )
        .toList();

    state = state.copyWith(
      tasks: [...runningTasks, ...selectedTasks, ...otherTasks],
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _saveToStorage();
  }

  /// 复制任务，紧跟在原任务之后；保存失败时按副本的去向返回，与 [add] 相同。
  Future<DuplicateTaskResult> duplicateTask(String taskId) async {
    if (state.isFull) {
      return (result: DuplicateTaskStatus.queueFull, enqueue: null);
    }

    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex < 0) {
      return (result: DuplicateTaskStatus.notFound, enqueue: null);
    }
    final task = state.tasks[taskIndex];

    if (!_hasGeneratableContent(task)) {
      return (result: DuplicateTaskStatus.nothingToGenerate, enqueue: null);
    }

    Map<String, dynamic>? generationSnapshot;
    if (task.generationSnapshot != null) {
      try {
        generationSnapshot = ReplicationTaskGenerationSnapshot.clone(
          task.generationSnapshot!,
        );
      } on FormatException {
        return (result: DuplicateTaskStatus.invalidSnapshot, enqueue: null);
      }
    }
    final newTask = ReplicationTask.create(
      prompt: task.prompt,
      negativePrompt: task.negativePrompt,
      applyNegativePrompt: task.applyNegativePrompt,
      thumbnailUrl: task.thumbnailUrl,
      source: task.source,
      seed: task.seed,
      sampler: task.sampler,
      steps: task.steps,
      cfgScale: task.cfgScale,
      model: task.model,
      width: task.width,
      height: task.height,
      characterPrompts: task.characterPrompts,
      generationSnapshot: generationSnapshot,
    );

    final enqueue = await _saveEnqueued([newTask], () {
      final tasks = List<ReplicationTask>.from(state.tasks);
      tasks.insert(taskIndex + 1, newTask);
      return tasks;
    });
    return (
      result: switch (enqueue.outcome) {
        EnqueueOutcome.saved => DuplicateTaskStatus.added,
        EnqueueOutcome.withdrawn => DuplicateTaskStatus.saveFailed,
        EnqueueOutcome.startedBeforeSaved =>
          DuplicateTaskStatus.startedBeforeSaved,
      },
      enqueue: enqueue,
    );
  }

  bool _hasGeneratableContent(ReplicationTask task) {
    if (task.prompt.trim().isNotEmpty) return true;
    if (task.applyNegativePrompt && task.negativePrompt.trim().isNotEmpty) {
      return true;
    }
    return task.characterPrompts?.any(
          (character) =>
              character.enabled &&
              (character.prompt.trim().isNotEmpty ||
                  character.negativePrompt.trim().isNotEmpty),
        ) ??
        false;
  }
}

class _EnqueueWatch {
  _EnqueueWatch(this.taskIds);

  final Set<String> taskIds;
  final Set<String> leftPending = {};
}
