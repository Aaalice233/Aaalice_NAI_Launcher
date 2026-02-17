import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_task.freezed.dart';
part 'tag_task.g.dart';

/// 标签任务状态
/// 任务生命周期：pending → running → completed/failed/cancelled
enum TagTaskStatus {
  /// 等待中 - 任务已创建，等待执行
  pending,

  /// 运行中 - 任务正在执行
  running,

  /// 已完成 - 任务成功完成
  completed,

  /// 失败 - 任务执行失败
  failed,

  /// 已取消 - 任务被取消
  cancelled,
}

/// 标签任务类型
enum TagTaskType {
  /// 常规标签任务
  regular,

  /// 艺术家标签任务
  artist,
}

/// 标签任务模型
/// 用于管理标签同步任务的状态机
@freezed
class TagTask with _$TagTask {
  const TagTask._();

  const factory TagTask({
    /// 任务唯一标识符
    required String id,

    /// 任务类型
    required TagTaskType type,

    /// 任务状态
    @Default(TagTaskStatus.pending) TagTaskStatus status,

    /// 取消令牌，用于取消网络请求
    @JsonKey(fromJson: _cancelTokenFromJson, toJson: _cancelTokenToJson)
    CancelToken? cancelToken,

    /// 任务进度 (0.0 - 1.0)
    @Default(0.0) double progress,

    /// 错误信息
    String? error,

    /// 任务创建时间
    DateTime? createdAt,

    /// 任务开始时间
    DateTime? startedAt,

    /// 任务完成时间
    DateTime? completedAt,
  }) = _TagTask;

  factory TagTask.fromJson(Map<String, dynamic> json) =>
      _$TagTaskFromJson(json);

  /// 获取显示名称
  String get displayName {
    switch (type) {
      case TagTaskType.regular:
        return '常规标签同步';
      case TagTaskType.artist:
        return '艺术家标签同步';
    }
  }

  /// 获取状态显示文本
  String get statusDisplayName {
    switch (status) {
      case TagTaskStatus.pending:
        return '排队中';
      case TagTaskStatus.running:
        return '同步中';
      case TagTaskStatus.completed:
        return '已完成';
      case TagTaskStatus.failed:
        return '失败';
      case TagTaskStatus.cancelled:
        return '已取消';
    }
  }

  /// 任务是否活跃（ pending 或 running）
  bool get isActive =>
      status == TagTaskStatus.pending || status == TagTaskStatus.running;

  /// 任务是否已完成（ completed, failed, 或 cancelled）
  bool get isCompleted =>
      status == TagTaskStatus.completed ||
      status == TagTaskStatus.failed ||
      status == TagTaskStatus.cancelled;

  /// 取消任务
  void cancel([String reason = '用户取消']) {
    cancelToken?.cancel(reason);
  }
}

/// CancelToken 的 JSON 序列化辅助函数
/// CancelToken 不能真正序列化，这里返回 null
CancelToken? _cancelTokenFromJson(dynamic json) => null;

dynamic _cancelTokenToJson(CancelToken? token) => null;

/// 标签任务列表扩展
extension TagTaskListExtension on List<TagTask> {
  /// 获取正在运行的任务
  List<TagTask> get runningTasks =>
      where((t) => t.status == TagTaskStatus.running).toList();

  /// 获取等待中的任务
  List<TagTask> get pendingTasks =>
      where((t) => t.status == TagTaskStatus.pending).toList();

  /// 获取活跃的任务
  List<TagTask> get activeTasks =>
      where((t) => t.isActive).toList();

  /// 按状态过滤任务
  List<TagTask> whereStatus(TagTaskStatus status) =>
      where((t) => t.status == status).toList();

  /// 按类型过滤任务
  List<TagTask> whereType(TagTaskType type) =>
      where((t) => t.type == type).toList();
}
