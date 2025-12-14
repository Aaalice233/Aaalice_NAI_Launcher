import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/prompt/random_prompt_result.dart';

part 'random_mode_provider.g.dart';

/// 随机生成模式 Provider
///
/// 管理用户选择的随机提示词生成模式
@Riverpod(keepAlive: true)
class RandomModeNotifier extends _$RandomModeNotifier {
  @override
  RandomGenerationMode build() {
    // 默认使用官网模式
    return RandomGenerationMode.naiOfficial;
  }

  /// 设置生成模式
  void setMode(RandomGenerationMode mode) {
    state = mode;
  }

  /// 切换到官网模式
  void useNaiOfficial() {
    state = RandomGenerationMode.naiOfficial;
  }

  /// 切换到自定义模式
  void useCustom() {
    state = RandomGenerationMode.custom;
  }

  /// 切换到混合模式
  void useHybrid() {
    state = RandomGenerationMode.hybrid;
  }

  /// 切换模式
  void toggle() {
    state = state == RandomGenerationMode.naiOfficial
        ? RandomGenerationMode.custom
        : RandomGenerationMode.naiOfficial;
  }
}

/// 便捷 Provider：是否为官网模式
@riverpod
bool isNaiOfficialMode(Ref ref) {
  return ref.watch(randomModeNotifierProvider) == RandomGenerationMode.naiOfficial;
}

/// 便捷 Provider：是否为自定义模式
@riverpod
bool isCustomMode(Ref ref) {
  return ref.watch(randomModeNotifierProvider) == RandomGenerationMode.custom;
}

/// 模式显示信息
extension RandomGenerationModeExtension on RandomGenerationMode {
  /// 获取显示名称
  String get displayName {
    return switch (this) {
      RandomGenerationMode.naiOfficial => '官网模式',
      RandomGenerationMode.custom => '自定义模式',
      RandomGenerationMode.hybrid => '混合模式',
    };
  }

  /// 获取英文显示名称
  String get displayNameEn {
    return switch (this) {
      RandomGenerationMode.naiOfficial => 'NAI Official',
      RandomGenerationMode.custom => 'Custom',
      RandomGenerationMode.hybrid => 'Hybrid',
    };
  }

  /// 获取描述
  String get description {
    return switch (this) {
      RandomGenerationMode.naiOfficial => '复刻 NovelAI 官方随机算法，支持多角色联动',
      RandomGenerationMode.custom => '使用自定义预设生成提示词',
      RandomGenerationMode.hybrid => '官网算法 + 自定义词库',
    };
  }

  /// 获取英文描述
  String get descriptionEn {
    return switch (this) {
      RandomGenerationMode.naiOfficial => 'Replicate NovelAI official algorithm with multi-character support',
      RandomGenerationMode.custom => 'Generate prompts using custom presets',
      RandomGenerationMode.hybrid => 'Official algorithm + Custom tag library',
    };
  }

  /// 获取图标名称
  String get iconName {
    return switch (this) {
      RandomGenerationMode.naiOfficial => 'auto_awesome',
      RandomGenerationMode.custom => 'tune',
      RandomGenerationMode.hybrid => 'merge_type',
    };
  }
}
