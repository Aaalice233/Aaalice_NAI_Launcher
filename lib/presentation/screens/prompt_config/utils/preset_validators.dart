import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/prompt_config.dart' as pc;
import '../../../../data/models/prompt/random_preset.dart';

/// 预设名称验证工具类
class PresetValidators {
  PresetValidators._();

  /// 验证 PromptConfig 预设名称
  /// 返回验证错误信息，如果验证通过则返回 null
  static String? validatePresetName(
    BuildContext context,
    String name,
    List<pc.RandomPromptPreset> presets, {
    String? excludePresetId,
  }) {
    if (name.trim().isEmpty) {
      return context.l10n.preset_presetName;
    }

    final isDuplicate = presets.any(
      (p) =>
          p.name.trim().toLowerCase() == name.trim().toLowerCase() &&
          p.id != excludePresetId,
    );

    if (isDuplicate) {
      return '预设名称已存在';
    }

    return null;
  }

  /// 验证 RandomPreset 预设名称
  /// 返回验证错误信息，如果验证通过则返回 null
  static String? validateRandomPresetName(
    BuildContext context,
    String name,
    List<RandomPreset> presets, {
    String? excludePresetId,
  }) {
    if (name.trim().isEmpty) {
      return context.l10n.preset_presetName;
    }

    final isDuplicate = presets.any(
      (p) =>
          p.name.trim().toLowerCase() == name.trim().toLowerCase() &&
          p.id != excludePresetId,
    );

    if (isDuplicate) {
      return '预设名称已存在';
    }

    return null;
  }
}
