import 'dart:async';

import '../../../core/comfyui/seedvr2_support.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import 'image_workflow_models.dart';
import 'image_workflow_upscale_helpers.dart';

final class ImageWorkflowPersistenceService {
  const ImageWorkflowPersistenceService(this._storage);

  final LocalStorageService _storage;

  UpscaleWorkflowSettings readUpscaleSettings() {
    final persistedScale = _readPersistedUpscaleScale();
    final legacyPersistedModel = _readPersistedStringSetting(
      StorageKeys.comfyuiUpscaleModel,
      defaultValue: UpscaleWorkflowSettings.defaultComfyModel,
    );
    final persistedBackend = _readPersistedUpscaleBackend();
    final persistedComfyModule = _readPersistedComfyUpscaleModule(
      fallbackModel: legacyPersistedModel,
    );
    final persistedRegularModel = _readPersistedComfyModelForModule(
      ComfyUpscaleModule.regular,
      legacyModel: legacyPersistedModel,
    );
    final previousSeedvr2Model = _readPersistedComfyModelForModule(
      ComfyUpscaleModule.seedvr2,
      legacyModel: legacyPersistedModel,
    );
    final persistedSeedvr2Engine = _readPersistedSeedvr2Engine();
    final persistedNativeModel = _readPersistedStringSetting(
      StorageKeys.comfyuiUpscaleSeedvr2NativeModel,
    );
    final persistedLegacyModel = _readPersistedStringSetting(
      StorageKeys.comfyuiUpscaleSeedvr2LegacyModel,
    );
    final regularModel = persistedRegularModel.trim();
    final previousModel = previousSeedvr2Model.trim();
    final nativeModel = persistedNativeModel.trim().isNotEmpty
        ? persistedNativeModel.trim()
        : previousModel.isNotEmpty && !isLegacySeedvr2ModelName(previousModel)
        ? previousModel
        : UpscaleWorkflowSettings.defaultComfyModel;
    final legacyModel = persistedLegacyModel.trim().isNotEmpty
        ? persistedLegacyModel.trim()
        : previousModel.isNotEmpty && isLegacySeedvr2ModelName(previousModel)
        ? previousModel
        : UpscaleWorkflowSettings.defaultLegacyComfyModel;
    final seedvr2Model = persistedSeedvr2Engine == ComfySeedvr2Engine.legacy
        ? legacyModel
        : nativeModel;
    final rtxModel = legacyPersistedModel.trim().isNotEmpty
        ? legacyPersistedModel.trim()
        : seedvr2Model;
    final currentModel = switch (persistedComfyModule) {
      ComfyUpscaleModule.regular => regularModel,
      ComfyUpscaleModule.seedvr2 => seedvr2Model,
      ComfyUpscaleModule.rtx => rtxModel,
    };
    final persistedSeedvr2VaeTileSize = _readPersistedIntSetting(
      StorageKeys.comfyuiSeedvr2VaeTileSize,
      defaultValue: UpscaleWorkflowSettings.defaultSeedvr2VaeTileSize,
      min: UpscaleWorkflowSettings.minSeedvr2VaeTileSize,
      max: UpscaleWorkflowSettings.maxSeedvr2VaeTileSize,
    );
    final persistedSeedvr2Tiled =
        _storage.getSetting<bool>(
          StorageKeys.comfyuiSeedvr2Tiled,
          defaultValue: false,
        ) ??
        false;
    final persistedSeedvr2TileSize = _readPersistedIntSetting(
      StorageKeys.comfyuiSeedvr2TileSize,
      defaultValue: UpscaleWorkflowSettings.defaultSeedvr2TileSize,
      min: UpscaleWorkflowSettings.minSeedvr2TileSize,
      max: UpscaleWorkflowSettings.maxSeedvr2TileSize,
    );
    final persistedSeedvr2BlocksToSwap = _readPersistedIntSetting(
      StorageKeys.comfyuiSeedvr2BlocksToSwap,
      defaultValue: UpscaleWorkflowSettings.defaultSeedvr2BlocksToSwap,
      min: UpscaleWorkflowSettings.minSeedvr2BlocksToSwap,
      max: UpscaleWorkflowSettings.maxSeedvr2BlocksToSwap,
    );
    final persistedSeedvr2EmbedNaiMetadata =
        _storage.getSetting<bool>(
          StorageKeys.comfyuiSeedvr2EmbedNaiMetadata,
          defaultValue: false,
        ) ??
        false;

    return UpscaleWorkflowSettings(
      backend: persistedBackend,
      comfyModule: persistedComfyModule,
      comfyScale: persistedScale,
      comfyModel: currentModel,
      comfyRegularModel: regularModel,
      comfySeedvr2NativeModel: nativeModel,
      comfySeedvr2LegacyModel: legacyModel,
      seedvr2Engine: persistedSeedvr2Engine,
      seedvr2VaeTileSize: persistedSeedvr2VaeTileSize,
      seedvr2Tiled: persistedSeedvr2Tiled,
      seedvr2TileSize: persistedSeedvr2TileSize,
      seedvr2BlocksToSwap: persistedSeedvr2BlocksToSwap,
      seedvr2EmbedNaiMetadata: persistedSeedvr2EmbedNaiMetadata,
    );
  }

  EnhanceWorkflowSettings readEnhanceSettings() {
    final rawLevel = _storage.getSetting(StorageKeys.workflowEnhanceLevel);
    final rawLegacyMagnitude = _storage.getSetting(
      StorageKeys.workflowEnhanceMagnitude,
    );
    final rawShowIndividual = _storage.getSetting<bool>(
      StorageKeys.workflowEnhanceShowIndividualSettings,
      defaultValue: const EnhanceWorkflowSettings().showIndividualSettings,
    );
    final rawUpscaleFactor = _storage.getSetting(
      StorageKeys.workflowEnhanceUpscaleFactor,
    );
    final rawMaxScale = _storage.getSetting<bool>(
      StorageKeys.workflowEnhanceMaxScale,
      defaultValue: const EnhanceWorkflowSettings().maxScale,
    );
    final rawStrength = _storage.getSetting(
      StorageKeys.workflowEnhanceStrength,
    );
    final rawNoise = _storage.getSetting(StorageKeys.workflowEnhanceNoise);

    double asDouble(dynamic value, double fallback) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return fallback;
    }

    // 档位化之前存的是 0-1 的连续 magnitude，用独立的新键避免两种量纲混淆；
    // 新键缺失时按最接近的档位迁移旧值。
    final level = switch (rawLevel) {
      final int value => value,
      final double value => value.round(),
      _ =>
        rawLegacyMagnitude == null
            ? const EnhanceWorkflowSettings().level
            : EnhanceLevels.fromLegacyMagnitude(
                asDouble(rawLegacyMagnitude, 0.5),
              ),
    };

    return EnhanceWorkflowSettings(
      level: level.clamp(EnhanceLevels.minLevel, EnhanceLevels.maxLevel),
      showIndividualSettings:
          rawShowIndividual ??
          const EnhanceWorkflowSettings().showIndividualSettings,
      upscaleFactor: asDouble(
        rawUpscaleFactor,
        const EnhanceWorkflowSettings().upscaleFactor,
      ).clamp(1.0, EnhanceScales.candidates.first),
      maxScale: rawMaxScale ?? const EnhanceWorkflowSettings().maxScale,
      strength: asDouble(
        rawStrength,
        const EnhanceWorkflowSettings().strength,
      ).clamp(0.0, 1.0),
      noise: asDouble(
        rawNoise,
        const EnhanceWorkflowSettings().noise,
      ).clamp(0.0, 1.0),
    );
  }

  void persistUpscaleSettings(UpscaleWorkflowSettings settings) {
    final activeModel = settings.comfyModel.trim();
    final regularModel = settings.comfyRegularModel.trim();
    final seedvr2Model = settings.comfyModule == ComfyUpscaleModule.seedvr2
        ? activeModel
        : settings.comfySeedvr2Model.trim();
    final nativeSeedvr2Model = settings.comfySeedvr2NativeModel.trim();
    final legacySeedvr2Model = settings.comfySeedvr2LegacyModel.trim();
    if (activeModel.isNotEmpty) {
      unawaited(
        _storage.setSetting(StorageKeys.comfyuiUpscaleModel, activeModel),
      );
    }
    if (regularModel.isNotEmpty) {
      unawaited(
        _storage.setSetting(
          StorageKeys.comfyuiUpscaleRegularModel,
          regularModel,
        ),
      );
    }
    if (seedvr2Model.isNotEmpty) {
      unawaited(
        _storage.setSetting(
          StorageKeys.comfyuiUpscaleSeedvr2Model,
          seedvr2Model,
        ),
      );
    }
    if (nativeSeedvr2Model.isNotEmpty) {
      unawaited(
        _storage.setSetting(
          StorageKeys.comfyuiUpscaleSeedvr2NativeModel,
          nativeSeedvr2Model,
        ),
      );
    }
    if (legacySeedvr2Model.isNotEmpty) {
      unawaited(
        _storage.setSetting(
          StorageKeys.comfyuiUpscaleSeedvr2LegacyModel,
          legacySeedvr2Model,
        ),
      );
    }
    unawaited(
      _storage.setSetting(StorageKeys.comfyuiUpscaleScale, settings.comfyScale),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiUpscaleBackend,
        settings.backend.name,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiUpscaleModule,
        settings.comfyModule.name,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2VaeTileSize,
        settings.seedvr2VaeTileSize,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2Tiled,
        settings.seedvr2Tiled,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2TileSize,
        settings.seedvr2TileSize,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2BlocksToSwap,
        settings.seedvr2BlocksToSwap,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2Engine,
        settings.seedvr2Engine.name,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.comfyuiSeedvr2EmbedNaiMetadata,
        settings.seedvr2EmbedNaiMetadata,
      ),
    );
  }

  void persistEnhanceSettings(EnhanceWorkflowSettings settings) {
    unawaited(
      _storage.setSetting(StorageKeys.workflowEnhanceLevel, settings.level),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.workflowEnhanceShowIndividualSettings,
        settings.showIndividualSettings,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.workflowEnhanceUpscaleFactor,
        settings.upscaleFactor,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.workflowEnhanceMaxScale,
        settings.maxScale,
      ),
    );
    unawaited(
      _storage.setSetting(
        StorageKeys.workflowEnhanceStrength,
        settings.strength,
      ),
    );
    unawaited(
      _storage.setSetting(StorageKeys.workflowEnhanceNoise, settings.noise),
    );
  }

  double _readPersistedUpscaleScale() {
    final rawValue = _storage.getSetting(StorageKeys.comfyuiUpscaleScale);
    if (rawValue is int) {
      return rawValue.toDouble().clamp(
        UpscaleWorkflowSettings.minScale,
        UpscaleWorkflowSettings.maxScale,
      );
    }
    if (rawValue is double) {
      return rawValue.clamp(
        UpscaleWorkflowSettings.minScale,
        UpscaleWorkflowSettings.maxScale,
      );
    }
    return UpscaleWorkflowSettings.defaultComfyScale;
  }

  String _readPersistedStringSetting(String key, {String defaultValue = ''}) {
    final rawValue = _storage.getSetting(key);
    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue.trim();
    }
    return defaultValue;
  }

  UpscaleBackend _readPersistedUpscaleBackend() {
    final rawValue = _storage.getSetting<String>(
      StorageKeys.comfyuiUpscaleBackend,
      defaultValue: UpscaleWorkflowSettings.defaultBackend.name,
    );
    for (final backend in UpscaleBackend.values) {
      if (backend.name == rawValue) {
        return backend;
      }
    }
    return UpscaleWorkflowSettings.defaultBackend;
  }

  ComfyUpscaleModule _readPersistedComfyUpscaleModule({
    required String fallbackModel,
  }) {
    final rawValue = _storage.getSetting<String>(
      StorageKeys.comfyuiUpscaleModule,
      defaultValue: null,
    );
    for (final module in ComfyUpscaleModule.values) {
      if (module.name == rawValue) {
        return module;
      }
    }
    return isComfySeedvr2UpscaleModel(fallbackModel)
        ? ComfyUpscaleModule.seedvr2
        : ComfyUpscaleModule.regular;
  }

  ComfySeedvr2Engine _readPersistedSeedvr2Engine() {
    final rawValue = _storage.getSetting<String>(
      StorageKeys.comfyuiSeedvr2Engine,
      defaultValue: ComfySeedvr2Engine.automatic.name,
    );
    for (final engine in ComfySeedvr2Engine.values) {
      if (engine.name == rawValue) return engine;
    }
    return ComfySeedvr2Engine.automatic;
  }

  String _readPersistedComfyModelForModule(
    ComfyUpscaleModule module, {
    required String legacyModel,
  }) {
    final key = switch (module) {
      ComfyUpscaleModule.regular => StorageKeys.comfyuiUpscaleRegularModel,
      ComfyUpscaleModule.seedvr2 => StorageKeys.comfyuiUpscaleSeedvr2Model,
      ComfyUpscaleModule.rtx => null,
    };

    if (key != null) {
      final moduleModel = _readPersistedStringSetting(key);
      if (moduleModel.isNotEmpty) return moduleModel;
    }

    final normalizedLegacyModel = legacyModel.trim();
    if (normalizedLegacyModel.isEmpty) {
      return defaultComfyUpscaleModelForModule(module);
    }

    final legacyIsSeedvr2 = isComfySeedvr2UpscaleModel(normalizedLegacyModel);
    return switch (module) {
      ComfyUpscaleModule.regular when !legacyIsSeedvr2 => normalizedLegacyModel,
      ComfyUpscaleModule.seedvr2 when legacyIsSeedvr2 => normalizedLegacyModel,
      ComfyUpscaleModule.rtx => normalizedLegacyModel,
      _ => defaultComfyUpscaleModelForModule(module),
    };
  }

  int _readPersistedIntSetting(
    String key, {
    required int defaultValue,
    required int min,
    required int max,
  }) {
    final rawValue = _storage.getSetting(key);
    final intValue = switch (rawValue) {
      final int value => value,
      final double value => value.round(),
      final String value => int.tryParse(value) ?? defaultValue,
      _ => defaultValue,
    };
    return intValue.clamp(min, max).toInt();
  }
}
