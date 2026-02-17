import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'replication_task_status.dart';

part 'replication_task.freezed.dart';
part 'replication_task.g.dart';

/// 复刻任务来源
enum ReplicationTaskSource {
  /// 在线画廊（Danbooru）
  online,

  /// 本地画廊
  local,
}

/// 复刻任务数据模型
///
/// 用于存储队列中的复刻任务，包含提示词和元数据
@freezed
class ReplicationTask with _$ReplicationTask {
  const ReplicationTask._();

  const factory ReplicationTask({
    /// 唯一标识符 (UUID)
    required String id,

    /// 正向提示词
    required String prompt,

    /// 负向提示词
    @Default('') String negativePrompt,

    /// 缩略图 URL（用于队列预览）
    String? thumbnailUrl,

    /// 任务来源
    @Default(ReplicationTaskSource.online) ReplicationTaskSource source,

    /// 创建时间
    required DateTime createdAt,

    // === 扩展字段 ===

    /// 任务状态
    @Default(ReplicationTaskStatus.pending) ReplicationTaskStatus status,

    /// 随机种子
    int? seed,

    /// 采样器
    String? sampler,

    /// 采样步数
    int? steps,

    /// CFG Scale
    double? cfgScale,

    /// 模型名称
    String? model,

    /// 图像宽度
    int? width,

    /// 图像高度
    int? height,

    /// 错误信息
    String? errorMessage,

    /// 重试次数
    @Default(0) int retryCount,

    /// 开始执行时间
    DateTime? startedAt,

    /// 完成时间
    DateTime? completedAt,
  }) = _ReplicationTask;

  /// 创建新的复刻任务
  factory ReplicationTask.create({
    required String prompt,
    String negativePrompt = '',
    String? thumbnailUrl,
    ReplicationTaskSource source = ReplicationTaskSource.online,
    int? seed,
    String? sampler,
    int? steps,
    double? cfgScale,
    String? model,
    int? width,
    int? height,
  }) {
    return ReplicationTask(
      id: const Uuid().v4(),
      prompt: prompt,
      negativePrompt: negativePrompt,
      thumbnailUrl: thumbnailUrl,
      source: source,
      createdAt: DateTime.now(),
      seed: seed,
      sampler: sampler,
      steps: steps,
      cfgScale: cfgScale,
      model: model,
      width: width,
      height: height,
    );
  }

  factory ReplicationTask.fromJson(Map<String, dynamic> json) =>
      _$ReplicationTaskFromJson(json);
}

/// 复刻任务列表 wrapper（用于 Hive JSON 存储）
@freezed
class ReplicationTaskList with _$ReplicationTaskList {
  const factory ReplicationTaskList({
    @Default([]) List<ReplicationTask> tasks,
  }) = _ReplicationTaskList;

  factory ReplicationTaskList.fromJson(Map<String, dynamic> json) =>
      _$ReplicationTaskListFromJson(json);
}
