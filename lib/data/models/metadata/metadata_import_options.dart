import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_import_options.freezed.dart';

/// 元数据导入选项模型
///
/// 用于选择性地套用图片元数据中的参数
@freezed
class MetadataImportOptions with _$MetadataImportOptions {
  const factory MetadataImportOptions({
    // ========== 提示词相关 ==========
    @Default(true) bool importPrompt, // 主提示词
    @Default(true) bool importNegativePrompt, // 负向提示词

    // 固定词（新增细分）
    @Default(true) bool importFixedTags, // 固定词总开关
    @Default(true) bool importFixedPrefix, // 固定前缀词
    @Default(true) bool importFixedSuffix, // 固定后缀词

    // 质量词（新增细分）
    @Default(true) bool importQualityTags, // 质量词总开关
    @Default([]) List<String> selectedQualityTags, // 选择的具体质量词

    // 角色提示词（新增细分）
    @Default(true) bool importCharacterPrompts, // 角色提示词总开关
    @Default([]) List<int> selectedCharacterIndices, // 选择的角色索引

    // Vibe数据（新增）
    @Default(true) bool importVibeReferences, // Vibe数据总开关
    @Default([]) List<int> selectedVibeIndices, // 选择的Vibe索引

    // ========== 生成参数 ==========
    @Default(false) bool importSeed, // 种子
    @Default(false) bool importSteps, // 步数
    @Default(false) bool importScale, // CFG Scale
    @Default(false) bool importSize, // 尺寸
    @Default(false) bool importSampler, // 采样器
    @Default(false) bool importModel, // 模型
    @Default(false) bool importSmea, // SMEA
    @Default(false) bool importSmeaDyn, // SMEA Dyn
    @Default(false) bool importNoiseSchedule, // 噪声计划
    @Default(false) bool importCfgRescale, // CFG Rescale
    @Default(false) bool importQualityToggle, // 质量标签
    @Default(false) bool importUcPreset, // UC 预设
  }) = _MetadataImportOptions;

  const MetadataImportOptions._();

  /// 快速预设：全部选中
  factory MetadataImportOptions.all() => const MetadataImportOptions();

  /// 快速预设：仅提示词相关
  factory MetadataImportOptions.promptsOnly() => const MetadataImportOptions(
        importPrompt: true,
        importNegativePrompt: true,
        importFixedTags: true,
        importFixedPrefix: true,
        importFixedSuffix: true,
        importQualityTags: true,
        importCharacterPrompts: true,
        importVibeReferences: true,
        importSeed: false,
        importSteps: false,
        importScale: false,
        importSize: false,
        importSampler: false,
        importModel: false,
        importSmea: false,
        importSmeaDyn: false,
        importNoiseSchedule: false,
        importCfgRescale: false,
        importQualityToggle: false,
        importUcPreset: false,
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
        importVibeReferences: false,
        importSeed: true,
        importSteps: true,
        importScale: true,
        importSize: true,
        importSampler: true,
        importModel: true,
        importSmea: true,
        importSmeaDyn: true,
        importNoiseSchedule: true,
        importCfgRescale: true,
        importQualityToggle: true,
        importUcPreset: true,
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
        importSeed: false,
        importSteps: false,
        importScale: false,
        importSize: false,
        importSampler: false,
        importModel: false,
        importSmea: false,
        importSmeaDyn: false,
        importNoiseSchedule: false,
        importCfgRescale: false,
        importQualityToggle: false,
        importUcPreset: false,
      );

  /// 获取已选中的参数数量（按逻辑分组计数）
  int get selectedCount {
    var count = 0;
    // 主提示词
    if (importPrompt) count++;
    // 负向提示词
    if (importNegativePrompt) count++;
    // 固定词（作为一个整体计数）
    if (importFixedTags && (importFixedPrefix || importFixedSuffix)) count++;
    // 质量词
    if (importQualityTags && selectedQualityTags.isNotEmpty) count++;
    // 角色提示词
    if (importCharacterPrompts && selectedCharacterIndices.isNotEmpty) count++;
    // Vibe数据
    if (importVibeReferences && selectedVibeIndices.isNotEmpty) count++;
    // 生成参数
    if (importSeed) count++;
    if (importSteps) count++;
    if (importScale) count++;
    if (importSize) count++;
    if (importSampler) count++;
    if (importModel) count++;
    if (importSmea) count++;
    if (importSmeaDyn) count++;
    if (importNoiseSchedule) count++;
    if (importCfgRescale) count++;
    if (importQualityToggle) count++;
    if (importUcPreset) count++;
    return count;
  }

  /// 是否全部选中
  bool get isAllSelected => selectedCount == 16;

  /// 是否全部未选中
  bool get isNoneSelected => selectedCount == 0;

  /// 是否导入任何提示词相关
  bool get isImportingAnyPrompt =>
      importPrompt ||
      importNegativePrompt ||
      (importFixedTags && (importFixedPrefix || importFixedSuffix)) ||
      (importQualityTags && selectedQualityTags.isNotEmpty) ||
      (importCharacterPrompts && selectedCharacterIndices.isNotEmpty) ||
      (importVibeReferences && selectedVibeIndices.isNotEmpty);
}
