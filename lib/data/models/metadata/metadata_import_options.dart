import 'package:freezed_annotation/freezed_annotation.dart';

part 'metadata_import_options.freezed.dart';

/// 元数据导入选项模型
///
/// 用于选择性地套用图片元数据中的参数
@freezed
class MetadataImportOptions with _$MetadataImportOptions {
  const factory MetadataImportOptions({
    @Default(true) bool importPrompt, // 正向提示词
    @Default(true) bool importNegativePrompt, // 负向提示词
    @Default(true) bool importCharacterPrompts, // 多角色提示词
    @Default(true) bool importSeed, // 种子
    @Default(true) bool importSteps, // 步数
    @Default(true) bool importScale, // CFG Scale
    @Default(true) bool importSize, // 尺寸
    @Default(true) bool importSampler, // 采样器
    @Default(true) bool importModel, // 模型
    @Default(true) bool importSmea, // SMEA
    @Default(true) bool importSmeaDyn, // SMEA Dyn
    @Default(true) bool importNoiseSchedule, // 噪声计划
    @Default(true) bool importCfgRescale, // CFG Rescale
    @Default(true) bool importQualityToggle, // 质量标签
    @Default(true) bool importUcPreset, // UC 预设
  }) = _MetadataImportOptions;

  const MetadataImportOptions._();

  /// 快速预设：全部选中
  factory MetadataImportOptions.all() => const MetadataImportOptions();

  /// 快速预设：仅提示词相关
  factory MetadataImportOptions.promptsOnly() => const MetadataImportOptions(
        importPrompt: true,
        importNegativePrompt: true,
        importCharacterPrompts: true,
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
        importCharacterPrompts: false,
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
        importCharacterPrompts: false,
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

  /// 获取已选中的参数数量
  int get selectedCount {
    var count = 0;
    if (importPrompt) count++;
    if (importNegativePrompt) count++;
    if (importCharacterPrompts) count++;
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
  bool get isAllSelected => selectedCount == 15;

  /// 是否全部未选中
  bool get isNoneSelected => selectedCount == 0;
}
