import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/replication_queue_storage.dart';
import '../../core/storage/queue_state_storage.dart';
import '../../data/models/queue/replication_task.dart';
import '../../data/models/queue/replication_task_status.dart';
import '../router/app_router.dart';

part 'replication_queue_provider.g.dart';

/// 队列容量限制
const int kMaxQueueCapacity = 50;

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

  /// 是否全选
  bool get isAllSelected =>
      tasks.isNotEmpty && selectedTaskIds.length == tasks.length;
}

/// 复刻队列状态管理 Provider
///
/// 管理复刻任务队列，包括添加、删除、重排序等操作
/// 使用 keepAlive: true 确保状态在页面切换时保持
@Riverpod(keepAlive: true)
class ReplicationQueueNotifier extends _$ReplicationQueueNotifier {
  late final ReplicationQueueStorage _storage;
  late final QueueStateStorage _stateStorage;

  @override
  ReplicationQueueState build() {
    _storage = ref.read(replicationQueueStorageProvider);
    _stateStorage = ref.read(queueStateStorageProvider);
    // 同步加载持久化数据（Hive Box 已在 main.dart 中预先打开）
    return _loadFromStorageSync();
  }

  /// 同步加载队列数据
  ReplicationQueueState _loadFromStorageSync() {
    try {
      final tasks = _storage.load();
      final failedTasks = _stateStorage.loadFailedTasks();

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

  /// 保存队列到存储
  Future<void> _saveToStorage() async {
    await _storage.save(state.tasks);
  }

  /// 保存失败任务到存储
  Future<void> _saveFailedTasks() async {
    await _stateStorage.saveFailedTasks(state.failedTasks);
  }

  /// 添加单个任务到队列
  ///
  /// 返回 true 表示添加成功，false 表示队列已满
  Future<bool> add(ReplicationTask task) async {
    if (state.isFull) {
      return false;
    }
    state = state.copyWith(
      tasks: [...state.tasks, task],
    );
    await _saveToStorage();

    // 添加任务时重置悬浮球关闭状态，确保悬浮球可见
    ref.read(floatingButtonClosedProvider.notifier).state = false;

    return true;
  }

  /// 批量添加任务到队列
  ///
  /// 返回实际添加的数量
  Future<int> addAll(List<ReplicationTask> tasks) async {
    if (tasks.isEmpty) return 0;

    final remaining = state.remainingCapacity;
    if (remaining <= 0) return 0;

    final toAdd = tasks.take(remaining).toList();
    state = state.copyWith(
      tasks: [...state.tasks, ...toAdd],
    );
    await _saveToStorage();

    // 添加任务时重置悬浮球关闭状态，确保悬浮球可见
    ref.read(floatingButtonClosedProvider.notifier).state = false;

    return toAdd.length;
  }

  /// 移除指定任务
  Future<void> remove(String taskId) async {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
      selectedTaskIds: state.selectedTaskIds.difference({taskId}),
    );
    await _saveToStorage();
  }

  /// 重新排序任务
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= state.tasks.length ||
        newIndex < 0 ||
        newIndex > state.tasks.length) {
      return;
    }

    final tasks = List<ReplicationTask>.from(state.tasks);
    final task = tasks.removeAt(oldIndex);

    // 如果是向后移动，需要减 1（因为已经移除了原位置的元素）
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    tasks.insert(adjustedIndex, task);

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
  }

  /// 清空队列
  Future<void> clear() async {
    state = state.copyWith(
      tasks: [],
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _storage.clear();
  }

  /// 获取队列中的下一个任务（不移除）
  ReplicationTask? getNext() {
    if (state.isEmpty) return null;
    return state.tasks.first;
  }

  /// 标记任务已完成（移除第一个任务）
  Future<void> markCompleted() async {
    if (state.isEmpty) return;

    final completedTask = state.tasks.first.copyWith(
      status: ReplicationTaskStatus.completed,
      completedAt: DateTime.now(),
    );

    state = state.copyWith(
      tasks: state.tasks.sublist(1),
      completedTasks: [...state.completedTasks.take(99), completedTask],
    );
    await _saveToStorage();
  }

  /// 更新任务状态
  Future<void> updateTaskStatus(
    String taskId,
    ReplicationTaskStatus status, {
    String? errorMessage,
  }) async {
    final tasks = state.tasks.map((t) {
      if (t.id == taskId) {
        return t.copyWith(
          status: status,
          errorMessage: errorMessage,
          startedAt: status == ReplicationTaskStatus.running
              ? DateTime.now()
              : t.startedAt,
          completedAt: status.isTerminal ? DateTime.now() : t.completedAt,
        );
      }
      return t;
    }).toList();

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
  }

  /// 更新任务
  Future<void> updateTask(ReplicationTask updatedTask) async {
    final tasks = state.tasks.map((t) {
      if (t.id == updatedTask.id) {
        return updatedTask;
      }
      return t;
    }).toList();

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
  }

  /// 将任务移到队首（置顶）
  Future<void> pinToTop(String taskId) async {
    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex <= 0) return; // 已经在队首或不存在

    final tasks = List<ReplicationTask>.from(state.tasks);
    final task = tasks.removeAt(taskIndex);
    tasks.insert(0, task);

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
  }

  /// 移入失败任务池
  Future<void> moveToFailedPool(String taskId) async {
    final task = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => ReplicationTask.create(prompt: ''),
    );

    if (task.prompt.isEmpty) return;

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

  /// 从失败池重试任务（移回队首）
  Future<void> retryFailedTask(String taskId) async {
    final task = state.failedTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => ReplicationTask.create(prompt: ''),
    );

    if (task.prompt.isEmpty || state.isFull) return;

    final retriedTask = task.copyWith(
      status: ReplicationTaskStatus.pending,
      retryCount: 0,
      errorMessage: null,
    );

    state = state.copyWith(
      tasks: [retriedTask, ...state.tasks],
      failedTasks: state.failedTasks.where((t) => t.id != taskId).toList(),
    );

    await _saveToStorage();
    await _saveFailedTasks();
  }

  /// 从失败池重新入队（移到队尾）
  Future<void> requeueFailedTask(String taskId) async {
    final task = state.failedTasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => ReplicationTask.create(prompt: ''),
    );

    if (task.prompt.isEmpty || state.isFull) return;

    final requeuedTask = task.copyWith(
      status: ReplicationTaskStatus.pending,
      retryCount: 0,
      errorMessage: null,
    );

    state = state.copyWith(
      tasks: [...state.tasks, requeuedTask],
      failedTasks: state.failedTasks.where((t) => t.id != taskId).toList(),
    );

    await _saveToStorage();
    await _saveFailedTasks();
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
    state = state.copyWith(
      isSelectionMode: false,
      selectedTaskIds: {},
    );
  }

  /// 切换任务选中状态
  void toggleTaskSelection(String taskId) {
    final newSelected = Set<String>.from(state.selectedTaskIds);
    if (newSelected.contains(taskId)) {
      newSelected.remove(taskId);
    } else {
      newSelected.add(taskId);
    }
    state = state.copyWith(selectedTaskIds: newSelected);
  }

  /// 全选
  void selectAll() {
    state = state.copyWith(
      selectedTaskIds: state.tasks.map((t) => t.id).toSet(),
    );
  }

  /// 反选
  void invertSelection() {
    final allIds = state.tasks.map((t) => t.id).toSet();
    final newSelected = allIds.difference(state.selectedTaskIds);
    state = state.copyWith(selectedTaskIds: newSelected);
  }

  /// 取消全选
  void clearSelection() {
    state = state.copyWith(selectedTaskIds: {});
  }

  /// 批量删除选中的任务
  Future<void> deleteSelected() async {
    if (state.selectedTaskIds.isEmpty) return;

    state = state.copyWith(
      tasks: state.tasks
          .where((t) => !state.selectedTaskIds.contains(t.id))
          .toList(),
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _saveToStorage();
  }

  /// 批量置顶选中的任务
  Future<void> pinSelectedToTop() async {
    if (state.selectedTaskIds.isEmpty) return;

    final selectedTasks =
        state.tasks.where((t) => state.selectedTaskIds.contains(t.id)).toList();
    final otherTasks = state.tasks
        .where((t) => !state.selectedTaskIds.contains(t.id))
        .toList();

    state = state.copyWith(
      tasks: [...selectedTasks, ...otherTasks],
      selectedTaskIds: {},
      isSelectionMode: false,
    );
    await _saveToStorage();
  }

  /// 复制任务
  Future<bool> duplicateTask(String taskId) async {
    if (state.isFull) return false;

    final task = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => ReplicationTask.create(prompt: ''),
    );

    if (task.prompt.isEmpty) return false;

    final newTask = ReplicationTask.create(
      prompt: task.prompt,
      negativePrompt: task.negativePrompt,
      thumbnailUrl: task.thumbnailUrl,
      source: task.source,
      seed: task.seed,
      sampler: task.sampler,
      steps: task.steps,
      cfgScale: task.cfgScale,
      model: task.model,
      width: task.width,
      height: task.height,
    );

    final taskIndex = state.tasks.indexWhere((t) => t.id == taskId);
    final tasks = List<ReplicationTask>.from(state.tasks);
    tasks.insert(taskIndex + 1, newTask);

    state = state.copyWith(tasks: tasks);
    await _saveToStorage();
    return true;
  }

  /// 设置加载状态（用于持久化加载）
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// 从持久化数据恢复队列
  void restore(List<ReplicationTask> tasks) {
    // 恢复时将所有 running 状态的任务重置为 pending
    // （因为应用重启后实际上没有任务在运行）
    final restoredTasks = tasks.take(kMaxQueueCapacity).map((task) {
      if (task.status == ReplicationTaskStatus.running) {
        return task.copyWith(status: ReplicationTaskStatus.pending);
      }
      return task;
    }).toList();

    state = state.copyWith(
      tasks: restoredTasks,
      isLoading: false,
    );
  }
}
