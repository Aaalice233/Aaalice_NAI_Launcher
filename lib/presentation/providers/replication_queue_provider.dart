import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  @override
  ReplicationQueueState build() {
    _storage = ref.read(replicationQueueStorageProvider);
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
    return toAdd.length;
  }

  /// 移除指定任务
  Future<void> remove(String taskId) async {
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
    state = state.copyWith(tasks: []);
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
}
