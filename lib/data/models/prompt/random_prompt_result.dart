import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../character/character_prompt.dart';

part 'random_prompt_result.freezed.dart';
part 'random_prompt_result.g.dart';

/// 随机提示词生成结果
///
/// 复刻 NovelAI 官网的返回格式：
/// - 无角色场景：[mainPrompt] (包含 "no humans")
/// - 有角色场景：[mainPrompt, character1, character2, ...]
///
/// 参考: docs/NAI随机提示词功能分析.md
@freezed
class RandomPromptResult with _$RandomPromptResult {
  const RandomPromptResult._();

  const factory RandomPromptResult({
    /// 主提示词（背景、场景、风格等共享元素）
    required String mainPrompt,

    /// 生成的角色列表
    @Default([]) List<GeneratedCharacter> characters,

    /// 是否为无人物场景
    @Default(false) bool noHumans,

    /// 使用的随机种子
    int? seed,

    /// 生成模式（官网/自定义）
    @Default(RandomGenerationMode.naiOfficial) RandomGenerationMode mode,
  }) = _RandomPromptResult;

  factory RandomPromptResult.fromJson(Map<String, dynamic> json) =>
      _$RandomPromptResultFromJson(json);

  /// 创建无人物场景结果
  factory RandomPromptResult.noHuman({
    required String prompt,
    int? seed,
  }) {
    return RandomPromptResult(
      mainPrompt: prompt,
      noHumans: true,
      seed: seed,
    );
  }

  /// 创建单角色场景结果
  factory RandomPromptResult.singleCharacter({
    required String mainPrompt,
    required GeneratedCharacter character,
    int? seed,
  }) {
    return RandomPromptResult(
      mainPrompt: mainPrompt,
      characters: [character],
      seed: seed,
    );
  }

  /// 创建多角色场景结果
  factory RandomPromptResult.multiCharacter({
    required String mainPrompt,
    required List<GeneratedCharacter> characters,
    int? seed,
  }) {
    return RandomPromptResult(
      mainPrompt: mainPrompt,
      characters: characters,
      seed: seed,
    );
  }

  /// 获取角色数量
  int get characterCount => characters.length;

  /// 是否有角色
  bool get hasCharacters => characters.isNotEmpty;

  /// 转换为 NAI 格式的数组
  /// 格式：[主提示词, 角色1提示词, 角色2提示词, ...]
  List<String> toNaiFormat() {
    if (noHumans || characters.isEmpty) {
      return [mainPrompt];
    }
    return [mainPrompt, ...characters.map((c) => c.prompt)];
  }

  /// 转换为 CharacterPrompt 列表（用于同步到 CharacterPromptNotifier）
  List<CharacterPrompt> toCharacterPrompts() {
    return characters.asMap().entries.map((entry) {
      final index = entry.key;
      final char = entry.value;
      return CharacterPrompt(
        id: 'random_${index}_${DateTime.now().millisecondsSinceEpoch}',
        name: '角色 ${index + 1}',
        gender: char.gender,
        prompt: char.prompt,
        negativePrompt: char.negativePrompt,
        enabled: true,
      );
    }).toList();
  }

  /// 获取合并后的完整提示词（用于传统单提示词模式）
  String get mergedPrompt {
    if (noHumans || characters.isEmpty) {
      return mainPrompt;
    }
    final allPrompts = [mainPrompt, ...characters.map((c) => c.prompt)];
    return allPrompts.join(', ');
  }
}

/// 生成的角色信息
@freezed
class GeneratedCharacter with _$GeneratedCharacter {
  const GeneratedCharacter._();

  const factory GeneratedCharacter({
    /// 角色提示词
    required String prompt,

    /// 负面提示词
    /// 默认值来自 NAI 官网：lowres, aliasing,
    @Default('lowres, aliasing, ') String negativePrompt,

    /// 角色性别
    @Default(CharacterGender.female) CharacterGender gender,

    /// 角色位置（0-1 归一化坐标）
    /// 官网随机生成默认为中心 (0, 0)
    @Default(0.0) double centerX,
    @Default(0.0) double centerY,
  }) = _GeneratedCharacter;

  factory GeneratedCharacter.fromJson(Map<String, dynamic> json) =>
      _$GeneratedCharacterFromJson(json);

  /// 创建女性角色
  factory GeneratedCharacter.female(String prompt) {
    return GeneratedCharacter(
      prompt: prompt,
      gender: CharacterGender.female,
    );
  }

  /// 创建男性角色
  factory GeneratedCharacter.male(String prompt) {
    return GeneratedCharacter(
      prompt: prompt,
      gender: CharacterGender.male,
    );
  }
}

/// 随机生成模式
enum RandomGenerationMode {
  /// 官网模式（复刻 NovelAI 算法）
  @JsonValue('nai_official')
  naiOfficial,

  /// 自定义模式（使用用户自定义预设）
  @JsonValue('custom')
  custom,

  /// 混合模式（可部分自定义）
  @JsonValue('hybrid')
  hybrid,
}

/// RandomGenerationMode 扩展
extension RandomGenerationModeX on RandomGenerationMode {
  /// 获取图标
  IconData get icon => switch (this) {
        RandomGenerationMode.naiOfficial => Icons.auto_awesome,
        RandomGenerationMode.custom => Icons.tune,
        RandomGenerationMode.hybrid => Icons.merge_type,
      };

  /// 获取名称
  String getName(dynamic l10n) => switch (this) {
        RandomGenerationMode.naiOfficial => l10n.randomMode_naiOfficial,
        RandomGenerationMode.custom => l10n.randomMode_custom,
        RandomGenerationMode.hybrid => l10n.randomMode_hybrid,
      };

  /// 获取描述
  String getDescription(dynamic l10n) => switch (this) {
        RandomGenerationMode.naiOfficial => l10n.randomMode_naiOfficialDesc,
        RandomGenerationMode.custom => l10n.randomMode_customDesc,
        RandomGenerationMode.hybrid => l10n.randomMode_hybridDesc,
      };
}
