import 'package:freezed_annotation/freezed_annotation.dart';

import '../gallery/nai_image_metadata.dart';

part 'metadata_import_options.freezed.dart';

/// 元数据导入选项模型
///
/// 用于选择性地套用图片元数据中的参数
@freezed
class MetadataImportOptions with _$MetadataImportOptions {
  const factory MetadataImportOptions({
    // ========== 提示词相关 ==========
    @Default(true) bool importPrompt,
    @Default(true) bool importNegativePrompt,

    // 固定词
    @Default(true) bool importFixedTags,
    @Default(true) bool importFixedPrefix,
    @Default(true) bool importFixedSuffix,

    // 质量词
    @Default(true) bool importQualityTags,
    @Default([]) List<String> selectedQualityTags,

    // 角色提示词
    @Default(true) bool importCharacterPrompts,
    @Default([]) List<int> selectedCharacterIndices,

    // Vibe 数据
    @Default(true) bool importVibeReferences,
    @Default([]) List<int> selectedVibeIndices,

    // Precise Reference 数据
    @Default(true) bool importPreciseReferences,
    @Default([]) List<int> selectedPreciseReferenceIndices,

    // ========== 生成参数 ==========
    @Default(false) bool importSeed,
    @Default(false) bool importSteps,
    @Default(false) bool importScale,
    @Default(false) bool importSize,
    @Default(false) bool importSampler,
    @Default(false) bool importModel,
    @Default(false) bool importSmea,
    @Default(false) bool importSmeaDyn,
    @Default(false) bool importVarietyPlus,
    @Default(false) bool importNoiseSchedule,
    @Default(false) bool importCfgRescale,
    @Default(false) bool importQualityToggle,
    @Default(false) bool importUcPreset,
    @Default(false) bool importTransparentBackground,
  }) = _MetadataImportOptions;

  const MetadataImportOptions._();

  /// 快速预设：全部选中
  factory MetadataImportOptions.all() => const MetadataImportOptions(
        importSeed: true,
        importSteps: true,
        importScale: true,
        importSize: true,
        importSampler: true,
        importModel: true,
        importSmea: true,
        importSmeaDyn: true,
        importVarietyPlus: true,
        importNoiseSchedule: true,
        importCfgRescale: true,
        importQualityToggle: true,
        importUcPreset: true,
        importTransparentBackground: true,
      );

  /// 快速预设：仅提示词相关
  factory MetadataImportOptions.promptsOnly() => const MetadataImportOptions(
        importPrompt: true,
        importNegativePrompt: true,
        importFixedTags: true,
        importFixedPrefix: true,
        importFixedSuffix: true,
        importQualityTags: true,
        importCharacterPrompts: true,
        importVibeReferences: false,
        importPreciseReferences: false,
        importSeed: false,
        importSteps: false,
        importScale: false,
        importSize: false,
        importSampler: false,
        importModel: false,
        importSmea: false,
        importSmeaDyn: false,
        importVarietyPlus: false,
        importNoiseSchedule: false,
        importCfgRescale: false,
        importQualityToggle: false,
        importUcPreset: false,
        importTransparentBackground: false,
      );

  /// 快速预设：仅生成参数（不包含提示词）
  factory MetadataImportOptions.generationOnly() => const MetadataImportOptions(
        importPrompt: false,
        importNegativePrompt: false,
        importFixedTags: false,
        importFixedPrefix: false,
        importFixedSuffix: false,
        importQualityTags: false,
        importCharacterPrompts: false,
        importVibeReferences: true,
        importPreciseReferences: true,
        importSeed: true,
        importSteps: true,
        importScale: true,
        importSize: true,
        importSampler: true,
        importModel: true,
        importSmea: true,
        importSmeaDyn: true,
        importVarietyPlus: true,
        importNoiseSchedule: true,
        importCfgRescale: true,
        importQualityToggle: true,
        importUcPreset: true,
        importTransparentBackground: true,
      );

  /// 全不选
  factory MetadataImportOptions.none() => const MetadataImportOptions(
        importPrompt: false,
        importNegativePrompt: false,
        importFixedTags: false,
        importFixedPrefix: false,
        importFixedSuffix: false,
        importQualityTags: false,
        importCharacterPrompts: false,
        importVibeReferences: false,
        importPreciseReferences: false,
        importSeed: false,
        importSteps: false,
        importScale: false,
        importSize: false,
        importSampler: false,
        importModel: false,
        importSmea: false,
        importSmeaDyn: false,
        importVarietyPlus: false,
        importNoiseSchedule: false,
        importCfgRescale: false,
        importQualityToggle: false,
        importUcPreset: false,
        importTransparentBackground: false,
      );

  /// 获取已选中的可用参数数量。
  ///
  /// 与 [selectedCount] 不同，这里只统计当前图片元数据里实际存在的数据，
  /// 避免“仅提示词”把空的固定词/质量词开关也计入数量。
  int selectedCountFor(NaiImageMetadata metadata) {
    var count = 0;

    if (importPrompt && metadata.prompt.isNotEmpty) count++;
    if (importNegativePrompt && metadata.negativePrompt.isNotEmpty) count++;

    final hasSelectedFixedPrefix = importFixedPrefix &&
        (metadata.fixedPrefixTags.isNotEmpty ||
            metadata.fixedNegativePrefixTags.isNotEmpty);
    final hasSelectedFixedSuffix = importFixedSuffix &&
        (metadata.fixedSuffixTags.isNotEmpty ||
            metadata.fixedNegativeSuffixTags.isNotEmpty);
    if (importFixedTags && (hasSelectedFixedPrefix || hasSelectedFixedSuffix)) {
      count++;
    }

    if (importQualityTags &&
        selectedQualityTags.any(metadata.qualityTags.contains)) {
      count++;
    }

    if (importCharacterPrompts &&
        (selectedCharacterIndices.any(
              (index) => index >= 0 && index < metadata.characterInfos.length,
            ) ||
            (metadata.characterInfos.isEmpty &&
                metadata.characterPrompts.isNotEmpty))) {
      count++;
    }

    if (importVibeReferences &&
        selectedVibeIndices.any(
          (index) => index >= 0 && index < metadata.vibeReferences.length,
        )) {
      count++;
    }

    if (importPreciseReferences &&
        selectedPreciseReferenceIndices.any(
          (index) => index >= 0 && index < metadata.preciseReferences.length,
        )) {
      count++;
    }

    if (importSeed && metadata.seed != null) count++;
    if (importSteps && metadata.steps != null) count++;
    if (importScale && metadata.scale != null) count++;
    if (importSize && metadata.width != null && metadata.height != null) {
      count++;
    }
    if (importSampler && metadata.sampler != null) count++;
    if (importModel && metadata.effectiveModel != null) count++;
    if (importSmea && (metadata.smea == true || metadata.smeaDyn == true)) {
      count++;
    }
    if (importSmeaDyn && metadata.smeaDyn == true) count++;
    if (importVarietyPlus && metadata.varietyPlus != null) count++;
    if (importNoiseSchedule && metadata.noiseSchedule != null) count++;
    if (importCfgRescale &&
        metadata.cfgRescale != null &&
        metadata.cfgRescale! > 0) {
      count++;
    }
    if (importQualityToggle && metadata.qualityToggle != null) count++;
    if (importUcPreset && metadata.ucPreset != null) count++;
    if (importTransparentBackground && metadata.transparentBackground != null) {
      count++;
    }

    return count;
  }

  /// 获取已选中的参数数量（按逻辑分组计数）
  int get selectedCount {
    var count = 0;
    if (importPrompt) count++;
    if (importNegativePrompt) count++;
    if (importFixedTags && (importFixedPrefix || importFixedSuffix)) count++;
    if (importQualityTags && selectedQualityTags.isNotEmpty) count++;
    if (importCharacterPrompts && selectedCharacterIndices.isNotEmpty) count++;
    if (importVibeReferences && selectedVibeIndices.isNotEmpty) count++;
    if (importPreciseReferences && selectedPreciseReferenceIndices.isNotEmpty) {
      count++;
    }
    if (importSeed) count++;
    if (importSteps) count++;
    if (importScale) count++;
    if (importSize) count++;
    if (importSampler) count++;
    if (importModel) count++;
    if (importSmea) count++;
    if (importSmeaDyn) count++;
    if (importVarietyPlus) count++;
    if (importNoiseSchedule) count++;
    if (importCfgRescale) count++;
    if (importQualityToggle) count++;
    if (importUcPreset) count++;
    if (importTransparentBackground) count++;
    return count;
  }

  /// 是否全部选中
  bool get isAllSelected => selectedCount == 20;

  /// 是否全部未选中
  bool get isNoneSelected => selectedCount == 0;

  /// 是否导入任何提示词相关
  bool get isImportingAnyPrompt =>
      importPrompt ||
      importNegativePrompt ||
      (importFixedTags && (importFixedPrefix || importFixedSuffix)) ||
      (importQualityTags && selectedQualityTags.isNotEmpty) ||
      (importCharacterPrompts && selectedCharacterIndices.isNotEmpty);

  bool isNoneSelectedFor(NaiImageMetadata metadata) =>
      selectedCountFor(metadata) == 0;
}
