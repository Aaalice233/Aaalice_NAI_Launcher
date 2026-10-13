import 'dart:convert';

import 'metadata_import_options.dart';

typedef _CategoryToggle = ({
  bool Function(MetadataImportOptions options) read,
  MetadataImportOptions Function(MetadataImportOptions options, bool value)
  write,
});

/// 元数据导入对话框“类别开关”的持久化格式。
///
/// 逐图条目（角色、质量词、Vibe、精准参考的选中项）按序号对应当前图片，不落盘。
abstract final class MetadataImportSelectionCodec {
  static const _unknownFixedTagPolicyKey = 'unknownFixedTagPolicy';

  // 键名即落盘格式，字段改名时不得随之改动。
  static final Map<String, _CategoryToggle> _categoryToggles = {
    'prompt': (
      read: (options) => options.importPrompt,
      write: (options, value) => options.copyWith(importPrompt: value),
    ),
    'negativePrompt': (
      read: (options) => options.importNegativePrompt,
      write: (options, value) => options.copyWith(importNegativePrompt: value),
    ),
    'fixedTags': (
      read: (options) => options.importFixedTags,
      write: (options, value) => options.copyWith(importFixedTags: value),
    ),
    'fixedPrefix': (
      read: (options) => options.importFixedPrefix,
      write: (options, value) => options.copyWith(importFixedPrefix: value),
    ),
    'fixedSuffix': (
      read: (options) => options.importFixedSuffix,
      write: (options, value) => options.copyWith(importFixedSuffix: value),
    ),
    'fixedNegativePrefix': (
      read: (options) => options.importFixedNegativePrefix,
      write: (options, value) =>
          options.copyWith(importFixedNegativePrefix: value),
    ),
    'fixedNegativeSuffix': (
      read: (options) => options.importFixedNegativeSuffix,
      write: (options, value) =>
          options.copyWith(importFixedNegativeSuffix: value),
    ),
    'qualityTags': (
      read: (options) => options.importQualityTags,
      write: (options, value) => options.copyWith(importQualityTags: value),
    ),
    'characterPrompts': (
      read: (options) => options.importCharacterPrompts,
      write: (options, value) =>
          options.copyWith(importCharacterPrompts: value),
    ),
    'vibeReferences': (
      read: (options) => options.importVibeReferences,
      write: (options, value) => options.copyWith(importVibeReferences: value),
    ),
    'preciseReferences': (
      read: (options) => options.importPreciseReferences,
      write: (options, value) =>
          options.copyWith(importPreciseReferences: value),
    ),
    'seed': (
      read: (options) => options.importSeed,
      write: (options, value) => options.copyWith(importSeed: value),
    ),
    'steps': (
      read: (options) => options.importSteps,
      write: (options, value) => options.copyWith(importSteps: value),
    ),
    'scale': (
      read: (options) => options.importScale,
      write: (options, value) => options.copyWith(importScale: value),
    ),
    'size': (
      read: (options) => options.importSize,
      write: (options, value) => options.copyWith(importSize: value),
    ),
    'sampler': (
      read: (options) => options.importSampler,
      write: (options, value) => options.copyWith(importSampler: value),
    ),
    'model': (
      read: (options) => options.importModel,
      write: (options, value) => options.copyWith(importModel: value),
    ),
    'smea': (
      read: (options) => options.importSmea,
      write: (options, value) => options.copyWith(importSmea: value),
    ),
    'smeaDyn': (
      read: (options) => options.importSmeaDyn,
      write: (options, value) => options.copyWith(importSmeaDyn: value),
    ),
    'varietyPlus': (
      read: (options) => options.importVarietyPlus,
      write: (options, value) => options.copyWith(importVarietyPlus: value),
    ),
    'noiseSchedule': (
      read: (options) => options.importNoiseSchedule,
      write: (options, value) => options.copyWith(importNoiseSchedule: value),
    ),
    'cfgRescale': (
      read: (options) => options.importCfgRescale,
      write: (options, value) => options.copyWith(importCfgRescale: value),
    ),
    'qualityToggle': (
      read: (options) => options.importQualityToggle,
      write: (options, value) => options.copyWith(importQualityToggle: value),
    ),
    'ucPreset': (
      read: (options) => options.importUcPreset,
      write: (options, value) => options.copyWith(importUcPreset: value),
    ),
    'transparentBackground': (
      read: (options) => options.importTransparentBackground,
      write: (options, value) =>
          options.copyWith(importTransparentBackground: value),
    ),
  };

  static String encode(MetadataImportOptions options) => jsonEncode({
    for (final MapEntry(:key, value: toggle) in _categoryToggles.entries)
      key: toggle.read(options),
    _unknownFixedTagPolicyKey: options.unknownFixedTagPolicy.name,
  });

  /// 缺项、类型不符或整体无法解析时，逐项回落到 [MetadataImportOptions.all]。
  static MetadataImportOptions decode(String? raw) {
    final stored = _parseObject(raw);
    var options = MetadataImportOptions.all();
    if (stored == null) return options;

    for (final MapEntry(:key, value: toggle) in _categoryToggles.entries) {
      if (stored[key] case final bool value) {
        options = toggle.write(options, value);
      }
    }
    final policy = UnknownFixedTagPolicy.values
        .asNameMap()[stored[_unknownFixedTagPolicyKey]];
    return policy == null
        ? options
        : options.copyWith(unknownFixedTagPolicy: policy);
  }

  static Map<String, Object?>? _parseObject(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
