import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/model_capabilities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/random_preset.dart';
import '../../data/models/prompt/random_prompt_result.dart';
import '../../data/services/official_random_prompt_generator.dart';
import '../../data/services/random_prompt_generator.dart';
import '../../data/services/wordlist_service.dart';
import 'random_preset_provider.dart';

part 'prompt_config_provider.g.dart';

class UnsupportedRandomPromptModelException implements Exception {
  const UnsupportedRandomPromptModelException(this.model);

  static const errorCode = 'GENERATION_ERROR_UNSUPPORTED_RANDOM_MODEL';

  final String model;

  String get encodedMessage => '$errorCode|$model';

  @override
  String toString() => encodedMessage;
}

/// 根据当前选中的预设生成随机提示词。
@Riverpod(keepAlive: true)
class PromptConfigNotifier extends _$PromptConfigNotifier {
  @override
  void build() {}

  /// 统一随机提示词生成入口
  ///
  /// 默认预设始终执行官网 recipe；选中任意用户预设时，只使用该预设
  /// 自己的词库和配置。两条路径互斥，不再额外注入 catalog 或混合结果。
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async {
    final presetNotifier = ref.read(randomPresetNotifierProvider.notifier);
    await presetNotifier.whenLoaded;
    final presetState = ref.read(randomPresetNotifierProvider);
    if (presetState.error != null) {
      AppLogger.w(
        'random preset state failed to load: ${presetState.error}',
        'RandomGen',
      );
      throw StateError(presetState.error!);
    }

    final selectedPreset = presetState.selectedPreset;
    if (selectedPreset != null && !selectedPreset.isDefault) {
      return _generateCustomPresetPrompt(selectedPreset, seed: seed);
    }

    final capabilities = ModelCapabilityRegistry.tryOf(model);
    if (capabilities == null) {
      throw UnsupportedRandomPromptModelException(model);
    }
    return _generateOfficialPrompt(
      seed: seed,
      modelProfile: capabilities.randomPromptProfile,
    );
  }

  /// 官网预设生成
  Future<RandomPromptResult> _generateOfficialPrompt({
    int? seed,
    required RandomPromptProfile modelProfile,
  }) async {
    final generator = OfficialRandomPromptGenerator(
      ref.read(wordlistServiceProvider),
    );
    final result = await generator.generate(profile: modelProfile, seed: seed);
    AppLogger.d(
      'official ${modelProfile.name} result: '
          '${result.characterCount} characters',
      'RandomGen',
    );
    return result;
  }

  /// 用户预设生成
  Future<RandomPromptResult> _generateCustomPresetPrompt(
    RandomPreset preset, {
    int? seed,
  }) async {
    final generator = ref.read(randomPromptGeneratorProvider);

    if (preset.categories.isEmpty) {
      return RandomPromptResult(mainPrompt: '', seed: seed);
    }

    return generator.generateFromPreset(preset: preset, seed: seed);
  }
}
