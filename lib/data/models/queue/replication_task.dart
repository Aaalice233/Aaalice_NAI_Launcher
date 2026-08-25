import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import '../character/character_prompt.dart';
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

/// 队列任务中的角色提示词快照。
///
/// 仅持久化生成所需字段，避免把角色编辑器的名称、缩略图和临时 ID 耦合到
/// 队列 JSON。缺少坐标时按 [CharacterPrompt] 的 AI 选位语义恢复。
@freezed
class ReplicationCharacterPromptSnapshot
    with _$ReplicationCharacterPromptSnapshot {
  const ReplicationCharacterPromptSnapshot._();

  const factory ReplicationCharacterPromptSnapshot({
    required String prompt,
    @Default('') String negativePrompt,
    @Default(true) bool enabled,
    double? positionX,
    double? positionY,
  }) = _ReplicationCharacterPromptSnapshot;

  factory ReplicationCharacterPromptSnapshot.fromCharacterPrompt(
    CharacterPrompt character,
  ) {
    final position = character.positionMode == CharacterPositionMode.custom
        ? character.customPosition
        : null;
    return ReplicationCharacterPromptSnapshot(
      prompt: character.prompt,
      negativePrompt: character.negativePrompt,
      enabled: character.enabled,
      positionX: position?.column,
      positionY: position?.row,
    );
  }

  factory ReplicationCharacterPromptSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => _$ReplicationCharacterPromptSnapshotFromJson(json);

  CharacterPrompt toCharacterPrompt({required String id, required int index}) {
    final hasCustomPosition = positionX != null && positionY != null;
    return CharacterPrompt(
      id: id,
      name: 'Character ${index + 1}',
      prompt: prompt,
      negativePrompt: negativePrompt,
      positionMode: hasCustomPosition
          ? CharacterPositionMode.custom
          : CharacterPositionMode.aiChoice,
      customPosition: hasCustomPosition
          ? CharacterPosition(
              mode: CharacterPositionMode.custom,
              row: positionY!,
              column: positionX!,
            )
          : null,
      enabled: enabled,
    );
  }
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

    /// 执行时是否用任务快照替换生成页当前负向提示词。
    ///
    /// 旧任务默认沿用生成页设置；从带完整生成参数的画廊来源创建的任务会显式启用。
    @Default(false) bool applyNegativePrompt,

    /// 缩略图 URL（用于队列预览）
    String? thumbnailUrl,

    /// 任务来源
    @Default(ReplicationTaskSource.online) ReplicationTaskSource source,

    /// 创建时间
    required DateTime createdAt,

    /// 可选的角色提示词快照。
    ///
    /// `null` 表示旧任务未携带角色信息，执行时保留当前角色；显式列表（包括
    /// 空列表）表示执行时替换当前角色。
    @JsonKey(includeIfNull: false)
    List<ReplicationCharacterPromptSnapshot>? characterPrompts,

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
    bool applyNegativePrompt = false,
    String? thumbnailUrl,
    ReplicationTaskSource source = ReplicationTaskSource.online,
    int? seed,
    String? sampler,
    int? steps,
    double? cfgScale,
    String? model,
    int? width,
    int? height,
    List<ReplicationCharacterPromptSnapshot>? characterPrompts,
  }) {
    return ReplicationTask(
      id: const Uuid().v4(),
      prompt: prompt,
      negativePrompt: negativePrompt,
      applyNegativePrompt: applyNegativePrompt,
      thumbnailUrl: thumbnailUrl,
      source: source,
      createdAt: DateTime.now(),
      characterPrompts: characterPrompts,
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
