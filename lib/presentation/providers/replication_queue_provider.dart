import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/app_state_storage.dart';
import '../../core/storage/crash_recovery_service.dart';
import '../../core/storage/replication_queue_storage.dart';
import '../../data/models/queue/replication_task.dart';

part 'replication_queue_provider.g.dart';

/// 队列容量限制
const int kMaxQueueCapacity = 50;

/// 复刻队列状态
class ReplicationQueueState {
  final List<ReplicationTask> tasks;
  final bool isLoading;

  const ReplicationQueueState({
    this.tasks = const [],
    this.isLoading = false,
  });

  ReplicationQueueState copyWith({
    List<ReplicationTask>? tasks,
    bool? isLoading,
  }) {
    return ReplicationQueueState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
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
}

/// 复刻队列状态管理 Provider
///
/// 管理复刻任务队列，包括添加、删除、重排序等操作
/// 使用 keepAlive: true 确保状态在页面切换时保持
@Riverpod(keepAlive: true)
class ReplicationQueueNotifier extends _$ReplicationQueueNotifier {
  late final ReplicationQueueStorage _storage;
  late final AppStateStorage _appStateStorage;
  late final CrashRecoveryService _crashRecoveryService;

  @override
  ReplicationQueueState build() {
    _storage = ref.read(replicationQueueStorageProvider);
    _appStateStorage = ref.read(appStateStorageProvider);
    _crashRecoveryService = ref.read(crashRecoveryServiceProvider);
    // 异步加载持久化数据
    _loadFromStorage();
    return const ReplicationQueueState(isLoading: true);
  }

  /// 从存储加载队列
  Future<void> _loadFromStorage() async {
    try {
      final tasks = await _storage.load();
      state = state.copyWith(
        tasks: tasks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// 保存队列到存储
  Future<void> _saveToStorage() async {
    await _storage.save(state.tasks);
  }

  /// 检查并恢复崩溃前的队列状态
  ///
  /// 在应用启动时调用，检测是否有未完成的队列任务需要恢复
  /// 返回 true 表示成功恢复，false 表示没有可恢复的状态
  Future<bool> checkAndRecover() async {
    try {
      // 分析崩溃情况
      final analysis = await _crashRecoveryService.analyzeCrash();

      if (!analysis.hasCrashDetected || !analysis.canRecover) {
        return false;
      }

      final recoveryPoint = analysis.recoveryPoint;
      if (recoveryPoint?.sessionState == null) {
        return false;
      }

      // 记录恢复尝试
      await _crashRecoveryService.logRecoveryAttempt(
        success: false,
        recoveredState: recoveryPoint!.sessionState,
      );

      // 恢复队列执行状态到 AppStateStorage
      final sessionState = recoveryPoint.sessionState!;

      // 如果队列在崩溃时正在执行，恢复队列任务列表
      if (sessionState.hasActiveQueueExecution) {
        // 重新加载队列数据
        await _loadFromStorage();

        // 记录恢复成功
        await _crashRecoveryService.logRecoveryAttempt(
          success: true,
          recoveredState: sessionState,
        );

        return true;
      }

      return false;
    } catch (e) {
      // 恢复失败时记录
      await _crashRecoveryService.logRecoveryAttempt(
        success: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 记录队列执行开始
  ///
  /// 在队列开始执行时调用，用于崩溃恢复
  Future<void> recordQueueExecutionStart({
    required String taskId,
    required int currentIndex,
  }) async {
    try {
      // 更新应用状态存储
      await _appStateStorage.recordQueueExecutionStart(
        taskId: taskId,
        currentIndex: currentIndex,
        totalTasks: state.tasks.length,
      );

      // 创建崩溃恢复日志
      final sessionState = await _appStateStorage.loadSessionState();
      if (sessionState != null) {
        await _crashRecoveryService.logQueueStart(sessionState);
      }
    } catch (e) {
      // 静默处理，不影响主流程
    }
  }

  /// 记录队列执行进度
  ///
  /// 在每个任务完成时调用
  Future<void> recordQueueProgress({
    required int currentIndex,
    String? currentTaskId,
  }) async {
    try {
      // 更新应用状态存储
      await _appStateStorage.updateQueueExecutionProgress(
        currentIndex: currentIndex,
        currentTaskId: currentTaskId,
      );

      // 记录进度到崩溃恢复日志
      final sessionState = await _appStateStorage.loadSessionState();
      if (sessionState != null) {
        await _crashRecoveryService.logQueueProgress(
          sessionState,
          message: 'Task $currentIndex/${state.tasks.length}',
        );
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 记录队列执行完成
  ///
  /// 在队列执行完成或出错时调用
  Future<void> recordQueueExecutionEnd({bool success = true}) async {
    try {
      if (success) {
        await _appStateStorage.clearQueueExecutionState();

        // 记录完成到崩溃恢复日志
        final sessionState = await _appStateStorage.loadSessionState();
        if (sessionState != null) {
          await _crashRecoveryService.logQueueComplete(sessionState);
        }
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 创建恢复点
  ///
  /// 在关键操作前调用，保存当前队列状态的完整快照
  Future<void> createCheckpoint({String? operationName}) async {
    try {
      final sessionState = await _appStateStorage.loadSessionState();
      if (sessionState != null) {
        await _crashRecoveryService.createCheckpoint(
          sessionState,
          operationName: operationName,
        );
      }
    } catch (e) {
      // 静默处理
    }
  }

  /// 添加单个任务到队列
  ///
  /// 返回 true 表示添加成功，false 表示队列已满
  Future<bool> add(ReplicationTask task) async {
    if (state.isFull) {
      return false;
    }

    // 创建恢复点
    await createCheckpoint(operationName: 'add_task');

    state = state.copyWith(
      tasks: [...state.tasks, task],
    );
    await _saveToStorage();
    return true;
  }

  /// 批量添加任务到队列
  ///
  /// 返回实际添加的数量
  Future<int> addAll(List<ReplicationTask> tasks) async {
    if (tasks.isEmpty) return 0;

    final remaining = state.remainingCapacity;
    if (remaining <= 0) return 0;

    // 创建恢复点
    await createCheckpoint(operationName: 'add_all_tasks');

    final toAdd = tasks.take(remaining).toList();
    state = state.copyWith(
      tasks: [...state.tasks, ...toAdd],
    );
    await _saveToStorage();
    return toAdd.length;
  }

  /// 移除指定任务
  Future<void> remove(String taskId) async {
    // 创建恢复点
    await createCheckpoint(operationName: 'remove_task');

    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
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

    // 创建恢复点
    await createCheckpoint(operationName: 'reorder_tasks');

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
    // 创建恢复点
    await createCheckpoint(operationName: 'clear_queue');

    state = state.copyWith(tasks: []);
    await _storage.clear();
    await _appStateStorage.clearQueueExecutionState();
  }

  /// 获取队列中的下一个任务（不移除）
  ReplicationTask? getNext() {
    if (state.isEmpty) return null;
    return state.tasks.first;
  }

  /// 标记任务已完成（移除第一个任务）
  Future<void> markCompleted() async {
    if (state.isEmpty) return;
    state = state.copyWith(
      tasks: state.tasks.sublist(1),
    );
    await _saveToStorage();
  }

  /// 设置加载状态（用于持久化加载）
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// 从持久化数据恢复队列
  void restore(List<ReplicationTask> tasks) {
    state = state.copyWith(
      tasks: tasks.take(kMaxQueueCapacity).toList(),
      isLoading: false,
    );
  }

  /// 恢复队列从崩溃前的状态
  ///
  /// 需要配合 SessionState 使用
  Future<void> restoreFromCrashState({
    required int startIndex,
    List<ReplicationTask>? recoveredTasks,
  }) async {
    try {
      if (recoveredTasks != null && recoveredTasks.isNotEmpty) {
        // 如果提供了恢复的任务列表，使用它
        final filteredTasks = recoveredTasks.skip(startIndex).toList();
        if (filteredTasks.length > kMaxQueueCapacity) {
          state = state.copyWith(
            tasks: filteredTasks.take(kMaxQueueCapacity).toList(),
          );
        } else {
          state = state.copyWith(tasks: filteredTasks);
        }
        await _saveToStorage();
      }

      // 记录恢复完成
      await recordQueueExecutionEnd(success: true);
    } catch (e) {
      // 恢复失败时继续执行
    }
  }
}
