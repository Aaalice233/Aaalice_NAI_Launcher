import 'package:freezed_annotation/freezed_annotation.dart';

import '../queue/replication_task.dart';

part 'session_state.freezed.dart';
part 'session_state.g.dart';

/// 队列执行会话状态
enum SessionStatus {
  /// 空闲状态
  idle,

  /// 正在运行
  running,

  /// 已暂停
  paused,

  /// 已完成
  completed,

  /// 执行出错
  error,
}

/// 会话状态数据模型
///
/// 用于持久化队列执行状态，支持断点续传和恢复
@freezed
class SessionState with _$SessionState {
  const SessionState._();

  const factory SessionState({
    /// 会话唯一标识符
    required String id,

    /// 会话名称（用于显示）
    required String name,

    /// 当前执行状态
    @Default(SessionStatus.idle) SessionStatus status,

    /// 当前执行的任务索引
    @Default(0) int currentTaskIndex,

    /// 任务列表
    @Default([]) List<ReplicationTask> tasks,

    /// 错误信息（当状态为 error 时）
    String? errorMessage,

    /// 创建时间
    required DateTime createdAt,

    /// 最后更新时间
    required DateTime updatedAt,

    /// 完成时间
    DateTime? completedAt,
  }) = _SessionState;

  /// 创建新的会话
  factory SessionState.create({
    required String name,
    List<ReplicationTask> tasks = const [],
  }) {
    final now = DateTime.now();
    return SessionState(
      id: now.millisecondsSinceEpoch.toString(),
      name: name,
      status: SessionStatus.idle,
      currentTaskIndex: 0,
      tasks: tasks,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 从 JSON 反序列化
  factory SessionState.fromJson(Map<String, dynamic> json) =>
      _$SessionStateFromJson(json);

  /// 获取当前任务
  ReplicationTask? get currentTask {
    if (tasks.isEmpty || currentTaskIndex >= tasks.length) {
      return null;
    }
    return tasks[currentTaskIndex];
  }

  /// 获取剩余任务数
  int get remainingTasks => tasks.length - currentTaskIndex;

  /// 获取已完成任务数
  int get completedTasks => currentTaskIndex;

  /// 获取进度百分比 (0-100)
  int get progressPercentage {
    if (tasks.isEmpty) return 0;
    return ((currentTaskIndex / tasks.length) * 100).round();
  }

  /// 是否还有更多任务
  bool get hasMoreTasks => currentTaskIndex < tasks.length;

  /// 是否正在运行
  bool get isRunning => status == SessionStatus.running;

  /// 是否已完成
  bool get isCompleted => status == SessionStatus.completed;

  /// 是否出错
  bool get isError => status == SessionStatus.error;
}

/// 会话状态列表 wrapper（用于 Hive JSON 存储）
@freezed
class SessionStateList with _$SessionStateList {
  const factory SessionStateList({
    @Default([]) List<SessionState> sessions,
  }) = _SessionStateList;

  factory SessionStateList.fromJson(Map<String, dynamic> json) =>
      _$SessionStateListFromJson(json);
}
