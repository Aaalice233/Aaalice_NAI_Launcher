import '../../core/constants/api_constants.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/models/metadata/metadata_import_options.dart';

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
    required this.updateUcPreset,
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
  final void Function(int value) updateUcPreset;
}

class MetadataImportApplier {
  MetadataImportApplier._();

  static int applyPromptAndGenerationParams({
    required NaiImageMetadata metadata,
    required MetadataImportOptions options,
    required String currentModel,
    required MetadataImportTarget target,
  }) {
    var count = 0;

    if (options.importPrompt && metadata.prompt.isNotEmpty) {
      target.updatePrompt(
        metadata.hasSeparatedFields ? metadata.mainPrompt : metadata.prompt,
      );
      count++;
    }

    if (options.importNegativePrompt &&
        (metadata.negativePrompt.isNotEmpty ||
            (options.importUcPreset && metadata.ucPreset != null))) {
      target.updateNegativePrompt(
        resolveImportedNegativePrompt(
          metadata,
          importUcPreset: options.importUcPreset,
          currentModel: currentModel,
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
    count += _applyValue<bool>(
      options.importQualityToggle,
      metadata.qualityToggle,
      target.updateQualityToggle,
    );
    count += _applyValue<int>(
      options.importUcPreset,
      metadata.ucPreset,
      target.updateUcPreset,
    );

    return count;
  }

  static String resolveImportedNegativePrompt(
    NaiImageMetadata metadata, {
    required bool importUcPreset,
    required String currentModel,
  }) {
    final baseNegative = metadata.displayNegativePrompt;
    if (!importUcPreset || metadata.ucPreset == null) {
      return baseNegative;
    }

    final model = resolveImportableModel(metadata) ?? currentModel;
    return UcPresets.stripPresetByInt(
      baseNegative,
      model,
      metadata.ucPreset!,
    );
  }

  static String? toImportableModelId(String? model) {
    if (model == null || model.isEmpty) return null;
    // 测试期生成的图元数据里是 `custom`，迁移到正式 ID。
    final normalized = ImageModels.migrateLegacyModel(model);
    return ImageModels.allModels.contains(normalized) ? normalized : null;
  }

  static String? resolveImportableModel(NaiImageMetadata metadata) {
    return toImportableModelId(metadata.sourceModel) ??
        toImportableModelId(metadata.model);
  }

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
