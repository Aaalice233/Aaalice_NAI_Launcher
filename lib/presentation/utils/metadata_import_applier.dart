import '../../core/enums/image_model_mode.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/metadata/metadata_import_options.dart';

void _ignoreQualityTier(String _) {}

void _ignoreModelMode(ImageModelMode _) {}

class MetadataImportTarget {
  const MetadataImportTarget({
    required this.updatePrompt,
    required this.updateNegativePrompt,
    required this.updateSeed,
    required this.updateSteps,
    required this.updateScale,
    required this.updateSize,
    required this.updateSampler,
    required this.updateModel,
    required this.updateSmea,
    required this.updateSmeaDyn,
    required this.updateVarietyPlus,
    required this.updateNoiseSchedule,
    required this.updateCfgRescale,
    required this.updateQualityToggle,
    this.updateQualityTier = _ignoreQualityTier,
    required this.updateUcPreset,
    required this.updateTransparentBackground,
    this.updateModelMode = _ignoreModelMode,
  });

  final void Function(String value) updatePrompt;
  final void Function(String value) updateNegativePrompt;
  final void Function(int value) updateSeed;
  final void Function(int value) updateSteps;
  final void Function(double value) updateScale;
  final void Function(int width, int height) updateSize;
  final void Function(String value) updateSampler;
  final void Function(String value) updateModel;
  final void Function(bool value) updateSmea;
  final void Function(bool value) updateSmeaDyn;
  final void Function(bool value) updateVarietyPlus;
  final void Function(String value) updateNoiseSchedule;
  final void Function(double value) updateCfgRescale;
  final void Function(bool value) updateQualityToggle;
  final void Function(String value) updateQualityTier;
  final void Function(int value) updateUcPreset;
  final void Function(bool value) updateTransparentBackground;
  final void Function(ImageModelMode value) updateModelMode;
}

class MetadataImportApplier {
  MetadataImportApplier._();

  static int applyPromptAndGenerationParams({
    required NaiImageMetadata metadata,
    required MetadataImportOptions options,
    required MetadataImportTarget target,
  }) {
    var count = 0;

    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      target.updatePrompt(
        metadata.hasSeparatedFields ? metadata.mainPrompt : metadata.prompt,
      );
      // 数据集前缀已从提示词剥离，模式随提示词一起恢复才能复现原图。
      final modelMode = metadata.modelMode;
      if (modelMode != null) target.updateModelMode(modelMode);
      count++;
    }

    if (options.importNegativePrompt &&
        (metadata.negativePrompt.isNotEmpty ||
            (options.importUcPreset && metadata.ucPreset != null))) {
      target.updateNegativePrompt(
        resolveImportedNegativePrompt(
          metadata,
          importUcPreset: options.importUcPreset,
        ),
      );
      count++;
    }

    count += _applyValue<int>(
      options.importSeed,
      metadata.seed,
      target.updateSeed,
    );
    count += _applyValue<int>(
      options.importSteps,
      metadata.steps,
      target.updateSteps,
    );
    count += _applyValue<double>(
      options.importScale,
      metadata.scale,
      target.updateScale,
    );

    if (options.importSize &&
        metadata.width != null &&
        metadata.height != null) {
      target.updateSize(metadata.width!, metadata.height!);
      count++;
    }

    count += _applyValue<String>(
      options.importSampler,
      metadata.sampler,
      target.updateSampler,
    );
    count += _applyValue<String>(
      options.importModel,
      resolveImportableModel(metadata),
      target.updateModel,
    );
    count += _applyValue<bool>(
      options.importSmea,
      metadata.smea,
      target.updateSmea,
    );
    count += _applyValue<bool>(
      options.importSmeaDyn,
      metadata.smeaDyn,
      target.updateSmeaDyn,
    );
    count += _applyValue<bool>(
      options.importVarietyPlus,
      metadata.varietyPlus,
      target.updateVarietyPlus,
    );
    count += _applyValue<String>(
      options.importNoiseSchedule,
      metadata.noiseSchedule,
      target.updateNoiseSchedule,
    );
    count += _applyValue<double>(
      options.importCfgRescale,
      metadata.cfgRescale,
      target.updateCfgRescale,
    );
    if (options.importQualityToggle && metadata.qualityToggle != null) {
      final enabled = metadata.qualityToggle!;
      target.updateQualityToggle(enabled);
      if (enabled && metadata.qualityTier != null) {
        target.updateQualityTier(metadata.qualityTier!);
      }
      count++;
    }
    count += _applyValue<int>(
      options.importUcPreset,
      metadata.ucPreset,
      target.updateUcPreset,
    );
    count += _applyValue<bool>(
      options.importTransparentBackground,
      metadata.transparentBackground,
      target.updateTransparentBackground,
    );

    return count;
  }

  /// 写入负面框的内容。导入 UC 预设时预设文字由预设选择在发送时拼回，
  /// 不导入时保留在文本里，否则原图的预设会丢失。
  static String resolveImportedNegativePrompt(
    NaiImageMetadata metadata, {
    required bool importUcPreset,
  }) {
    final mainNegative = metadata.mainNegativePrompt;
    if (importUcPreset) return mainNegative;
    return [
      metadata.negativePresetSplit.preset,
      mainNegative,
    ].where((part) => part.isNotEmpty).join(', ');
  }

  static String? resolveImportableModel(NaiImageMetadata metadata) =>
      metadata.importableModel;

  static int _applyValue<T>(
    bool shouldImport,
    T? value,
    void Function(T value) update,
  ) {
    if (!shouldImport || value == null) {
      return 0;
    }
    update(value);
    return 1;
  }
}
