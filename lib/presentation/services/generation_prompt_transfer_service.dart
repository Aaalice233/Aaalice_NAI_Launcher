import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../core/utils/nai_prompt_formatter.dart';
import '../../core/utils/sd_to_nai_converter.dart';
import '../../data/models/online_gallery/ai_tag_generation_info.dart';
import '../providers/image_generation_provider.dart';
import '../providers/pending_prompt_provider.dart';

final generationPromptTransferServiceProvider =
    Provider<GenerationPromptTransferService>(
      (ref) => GenerationPromptTransferService(ref),
    );

enum GenerationTransferSetting {
  model,
  size,
  sampler,
  seed,
  steps,
  scale,
  cfgRescale,
  noiseSchedule,
  smea,
  smeaDyn,
}

/// Enables the optional configuration-selection step for a prompt transfer.
/// A null configuration keeps the step visible but disables unsupported fields.
class GenerationTransferOptions {
  const GenerationTransferOptions({required this.configuration});

  final GenerationTransferConfiguration? configuration;
}

/// NovelAI settings parsed from the selected AI TAG image that can be mapped
/// one-to-one onto the launcher's native generation controls.
class GenerationTransferConfiguration {
  const GenerationTransferConfiguration({
    this.width,
    this.height,
    this.sampler,
    this.model,
    this.seed,
    this.steps,
    this.scale,
    this.cfgRescale,
    this.noiseSchedule,
    this.smea,
    this.smeaDyn,
  });

  final int? width;
  final int? height;
  final String? sampler;
  final String? model;
  final int? seed;
  final int? steps;
  final double? scale;
  final double? cfgRescale;
  final String? noiseSchedule;
  final bool? smea;
  final bool? smeaDyn;

  Set<GenerationTransferSetting> get availableSettings => {
    if (model != null) GenerationTransferSetting.model,
    if (width != null && height != null) GenerationTransferSetting.size,
    if (sampler != null) GenerationTransferSetting.sampler,
    if (seed != null) GenerationTransferSetting.seed,
    if (steps != null) GenerationTransferSetting.steps,
    if (scale != null) GenerationTransferSetting.scale,
    if (cfgRescale != null) GenerationTransferSetting.cfgRescale,
    if (noiseSchedule != null) GenerationTransferSetting.noiseSchedule,
    if (smea != null) GenerationTransferSetting.smea,
    if (smeaDyn != null) GenerationTransferSetting.smeaDyn,
  };

  static GenerationTransferConfiguration? tryFromAiTag(
    AiTagGenerationInfo info,
  ) {
    final descriptor = [
      info.software,
      info.model,
      info.extra['Model ID'],
    ].whereType<String>().join(' ').toLowerCase();
    final isNovelAi =
        descriptor.contains('novelai') ||
        RegExp(r'\bnai(?:[-_\s]|$)').hasMatch(descriptor);
    if (!isNovelAi) return null;

    final width = (info.width ?? 0) > 0 ? info.width : null;
    final height = (info.height ?? 0) > 0 ? info.height : null;
    final hasSize = width != null && height != null;
    return GenerationTransferConfiguration(
      width: hasSize ? width : null,
      height: hasSize ? height : null,
      sampler: _resolveSampler(info.sampler),
      model: _resolveModel(info),
      seed: _validInt(info.seed, min: 0, max: 0xffffffff),
      steps: _validInt(info.steps, min: 1, max: 50),
      scale: _validDouble(info.cfgScale, min: 0, max: 10),
      cfgRescale: _validDouble(info.cfgRescale, min: 0, max: 1),
      noiseSchedule: _resolveNoiseSchedule(info.scheduler),
      smea: info.smea,
      smeaDyn: info.smeaDyn,
    );
  }

  static int? _validInt(int? value, {required int min, required int max}) =>
      value != null && value >= min && value <= max ? value : null;

  static double? _validDouble(
    double? value, {
    required double min,
    required double max,
  }) => value != null && value.isFinite && value >= min && value <= max
      ? value
      : null;

  static String? _resolveSampler(String? rawSampler) {
    final sampler = rawSampler?.trim();
    if (sampler == null || sampler.isEmpty) return null;
    if (Samplers.allSamplers.contains(sampler)) return sampler;
    final normalized = sampler.toLowerCase();
    for (final entry in Samplers.samplerDisplayNames.entries) {
      if (entry.value.toLowerCase() == normalized) return entry.key;
    }
    return null;
  }

  static String? _resolveNoiseSchedule(String? rawSchedule) {
    final normalized = rawSchedule?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final schedule in NoiseSchedules.all) {
      if (schedule.toLowerCase() == normalized ||
          NoiseSchedules.displayNames[schedule]?.toLowerCase() == normalized) {
        return schedule;
      }
    }
    return null;
  }

  static String? _resolveModel(AiTagGenerationInfo info) {
    for (final candidate in [info.extra['Model ID'], info.model]) {
      final model = candidate?.trim();
      if (model != null && ImageModels.allModels.contains(model)) return model;
    }

    final descriptor = [
      info.software,
      info.model,
      info.extra['Model ID'],
    ].whereType<String>().join(' ').toLowerCase();
    final curated = descriptor.contains('curated');
    final full = descriptor.contains('full');
    if (descriptor.contains('furry')) {
      return descriptor.contains(RegExp(r'(?:v|diffusion[-_\s]*)3'))
          ? ImageModels.furryDiffusionV3
          : ImageModels.furryDiffusion;
    }
    if (descriptor.contains(RegExp(r'(?:v|diffusion[-_\s]*)5'))) {
      if (curated) return ImageModels.animeDiffusionV5Curated;
      if (full) return ImageModels.animeDiffusionV5Full;
    }
    if (descriptor.contains(RegExp(r'(?:v|diffusion[-_\s]*)4[._-]5'))) {
      if (curated) return ImageModels.animeDiffusionV45Curated;
      if (full) return ImageModels.animeDiffusionV45Full;
    }
    if (descriptor.contains(RegExp(r'(?:v|diffusion[-_\s]*)4'))) {
      if (curated) return ImageModels.animeDiffusionV4Curated;
      if (full) return ImageModels.animeDiffusionV4Full;
    }
    if (descriptor.contains(RegExp(r'(?:v|diffusion[-_\s]*)3'))) {
      return ImageModels.animeDiffusionV3;
    }
    return null;
  }
}

/// Applies prompts sent from another page to the authoritative generation state.
class GenerationPromptTransferService {
  const GenerationPromptTransferService(this._ref);

  final Ref _ref;

  void replaceMainPrompt({
    required String prompt,
    String? negativePrompt,
    GenerationTransferConfiguration? configuration,
    Set<GenerationTransferSetting>? configurationSettings,
  }) {
    _ref.read(pendingPromptNotifierProvider.notifier).clear();
    final notifier = _ref.read(generationParamsNotifierProvider.notifier);
    if (configuration != null) {
      final selected = configurationSettings ?? configuration.availableSettings;
      if (selected.contains(GenerationTransferSetting.model) &&
          configuration.model != null) {
        notifier.updateModel(configuration.model!, followDefaults: false);
      }
      if (selected.contains(GenerationTransferSetting.size) &&
          configuration.width != null &&
          configuration.height != null) {
        notifier.updateSize(configuration.width!, configuration.height!);
      }
      if (selected.contains(GenerationTransferSetting.sampler) &&
          configuration.sampler != null) {
        notifier.updateSampler(configuration.sampler!);
      }
      if (selected.contains(GenerationTransferSetting.seed) &&
          configuration.seed != null) {
        notifier.updateSeed(configuration.seed!);
      }
      if (selected.contains(GenerationTransferSetting.steps) &&
          configuration.steps != null) {
        notifier.updateSteps(configuration.steps!);
      }
      if (selected.contains(GenerationTransferSetting.scale) &&
          configuration.scale != null) {
        notifier.updateScale(configuration.scale!);
      }
      if (selected.contains(GenerationTransferSetting.cfgRescale) &&
          configuration.cfgRescale != null) {
        notifier.updateCfgRescale(configuration.cfgRescale!);
      }
      if (selected.contains(GenerationTransferSetting.noiseSchedule) &&
          configuration.noiseSchedule != null) {
        notifier.updateNoiseSchedule(configuration.noiseSchedule!);
      }
      if (selected.contains(GenerationTransferSetting.smea) &&
          configuration.smea != null) {
        notifier.updateSmea(configuration.smea!);
      }
      if (selected.contains(GenerationTransferSetting.smeaDyn) &&
          configuration.smeaDyn != null) {
        notifier.updateSmeaDyn(configuration.smeaDyn!);
      }
    }

    final positive = prompt.trim();
    if (positive.isNotEmpty) {
      notifier.updatePrompt(_normalize(positive));
    }

    final negative = negativePrompt?.trim();
    if (negative != null && negative.isNotEmpty) {
      notifier.updateNegativePrompt(_normalize(negative));
    }
  }

  String _normalize(String prompt) =>
      NaiPromptFormatter.format(SdToNaiConverter.convert(prompt));
}
