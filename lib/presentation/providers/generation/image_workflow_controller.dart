import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_params_notifier.dart';

enum ImageWorkflowMode { base, inpaint, enhance, upscale }

enum UpscaleBackend { comfyui, novelai }

enum ComfyUpscaleModule { regular, seedvr2, rtx }

String defaultComfyUpscaleModelForModule(ComfyUpscaleModule module) {
  return switch (module) {
    ComfyUpscaleModule.seedvr2 => UpscaleWorkflowSettings.defaultComfyModel,
    ComfyUpscaleModule.regular => '',
    ComfyUpscaleModule.rtx => '',
  };
}

const String comfySeedvr2UpscaleTemplateId = 'builtin_seedvr2_upscale';
const String comfySeedvr2TiledUpscaleTemplateId =
    'builtin_seedvr2_tiled_upscale';
const String comfyModelUpscaleTemplateId = 'builtin_comfy_model_upscale';
const String comfyRtxUpscaleTemplateId = 'builtin_rtx_upscale';

bool isComfySeedvr2UpscaleModel(String model) {
  return model.trim().toLowerCase().contains('seedvr2');
}

List<String> filterComfyUpscaleModelsForModule(
  Iterable<String> availableModels, {
  required ComfyUpscaleModule module,
}) {
  final normalizedModels = availableModels
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toList(growable: false);

  return switch (module) {
    ComfyUpscaleModule.seedvr2 =>
      normalizedModels
          .where(isComfySeedvr2UpscaleModel)
          .toList(growable: false),
    ComfyUpscaleModule.regular =>
      normalizedModels
          .where((model) => !isComfySeedvr2UpscaleModel(model))
          .toList(growable: false),
    ComfyUpscaleModule.rtx => const [],
  };
}

String? resolveComfyUpscaleModelForModule(
  Iterable<String> availableModels, {
  required ComfyUpscaleModule module,
  required String currentModel,
}) {
  if (module == ComfyUpscaleModule.rtx) return null;

  final modelsForModule = filterComfyUpscaleModelsForModule(
    availableModels,
    module: module,
  );
  if (modelsForModule.isNotEmpty) {
    return selectPreferredUpscaleModel(
      modelsForModule,
      currentModel: currentModel,
    );
  }

  final trimmedCurrent = currentModel.trim();
  if (trimmedCurrent.isEmpty) return null;
  final currentIsSeedvr2 = isComfySeedvr2UpscaleModel(trimmedCurrent);
  return switch (module) {
    ComfyUpscaleModule.seedvr2 when currentIsSeedvr2 => trimmedCurrent,
    ComfyUpscaleModule.regular when !currentIsSeedvr2 => trimmedCurrent,
    _ => null,
  };
}

int calculateComfySeedvr2TargetResolution({
  required int sourceWidth,
  required int sourceHeight,
  required double scale,
}) {
  final shortestSide = sourceWidth < sourceHeight ? sourceWidth : sourceHeight;
  final safeShortestSide = shortestSide < 1 ? 1 : shortestSide;
  final safeScale = scale
      .clamp(UpscaleWorkflowSettings.minScale, UpscaleWorkflowSettings.maxScale)
      .toDouble();
  final resolution = (safeShortestSide * safeScale).round();
  return resolution.clamp(1, 16384).toInt();
}

int calculateComfySeedvr2TiledTargetResolution({
  required int sourceWidth,
  required int sourceHeight,
  required double scale,
}) {
  final longestSide = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
  final safeLongestSide = longestSide < 16 ? 16 : longestSide;
  final safeScale = scale
      .clamp(UpscaleWorkflowSettings.minScale, UpscaleWorkflowSettings.maxScale)
      .toDouble();
  final resolution = (safeLongestSide * safeScale).round();
  return resolution.clamp(16, 16384).toInt();
}

String selectPreferredUpscaleModel(
  Iterable<String> availableModels, {
  String? currentModel,
}) {
  final normalizedModels = availableModels
      .map((model) => model.trim())
      .where((model) => model.isNotEmpty)
      .toList(growable: false);
  if (normalizedModels.isEmpty) {
    return currentModel?.trim().isNotEmpty == true
        ? currentModel!.trim()
        : UpscaleWorkflowSettings.defaultComfyModel;
  }

  final normalizedCurrent = currentModel?.trim();
  if (normalizedCurrent != null &&
      normalizedModels.contains(normalizedCurrent)) {
    return normalizedCurrent;
  }

  for (final model in normalizedModels) {
    final lower = model.toLowerCase();
    if (lower.contains('3b') && lower.contains('q4')) {
      return model;
    }
  }

  return normalizedModels.first;
}

bool shouldAutoPersistResolvedUpscaleModel({
  required bool isComfyBackend,
  required bool hasFetchedFromServer,
  required Iterable<String> availableModels,
  required String currentModel,
  required String resolvedModel,
}) {
  if (!isComfyBackend || !hasFetchedFromServer) return false;
  if (availableModels.isEmpty) return false;
  return resolvedModel != currentModel;
}

/// 图生图「超分」子模式设置
class UpscaleWorkflowSettings {
  const UpscaleWorkflowSettings({
    this.backend = defaultBackend,
    this.comfyModule = defaultComfyModule,
    this.comfyScale = defaultComfyScale,
    this.comfyModel = defaultComfyModel,
    this.comfyRegularModel = defaultComfyRegularModel,
    this.comfySeedvr2Model = defaultComfyModel,
    this.seedvr2VaeTileSize = defaultSeedvr2VaeTileSize,
    this.seedvr2Tiled = false,
    this.seedvr2TileSize = defaultSeedvr2TileSize,
  });

  static const UpscaleBackend defaultBackend = UpscaleBackend.comfyui;
  static const ComfyUpscaleModule defaultComfyModule =
      ComfyUpscaleModule.seedvr2;
  static const double defaultComfyScale = 1.5;
  static const String defaultComfyModel = 'seedvr2_ema_3b_q4.safetensors';
  static const String defaultComfyRegularModel = '';
  static const int defaultSeedvr2VaeTileSize = 1024;
  static const int defaultSeedvr2TileSize = 1024;

  final UpscaleBackend backend;
  final ComfyUpscaleModule comfyModule;
  final double comfyScale;
  final String comfyModel;
  final String comfyRegularModel;
  final String comfySeedvr2Model;
  final int seedvr2VaeTileSize;
  final bool seedvr2Tiled;
  final int seedvr2TileSize;

  static const double minScale = 1.0;
  static const double maxScale = 2.0;
  static const int minSeedvr2VaeTileSize = 128;
  static const int maxSeedvr2VaeTileSize = 4096;
  static const int minSeedvr2TileSize = 256;
  static const int maxSeedvr2TileSize = 4096;

  UpscaleWorkflowSettings copyWith({
    UpscaleBackend? backend,
    ComfyUpscaleModule? comfyModule,
    double? comfyScale,
    String? comfyModel,
    String? comfyRegularModel,
    String? comfySeedvr2Model,
    int? seedvr2VaeTileSize,
    bool? seedvr2Tiled,
    int? seedvr2TileSize,
  }) {
    return UpscaleWorkflowSettings(
      backend: backend ?? this.backend,
      comfyModule: comfyModule ?? this.comfyModule,
      comfyScale: comfyScale ?? this.comfyScale,
      comfyModel: comfyModel ?? this.comfyModel,
      comfyRegularModel: comfyRegularModel ?? this.comfyRegularModel,
      comfySeedvr2Model: comfySeedvr2Model ?? this.comfySeedvr2Model,
      seedvr2VaeTileSize: seedvr2VaeTileSize ?? this.seedvr2VaeTileSize,
      seedvr2Tiled: seedvr2Tiled ?? this.seedvr2Tiled,
      seedvr2TileSize: seedvr2TileSize ?? this.seedvr2TileSize,
    );
  }

  String comfyModelForModule(ComfyUpscaleModule module) {
    return switch (module) {
      ComfyUpscaleModule.regular => comfyRegularModel,
      ComfyUpscaleModule.seedvr2 => comfySeedvr2Model,
      ComfyUpscaleModule.rtx => comfyModel,
    };
  }

  UpscaleWorkflowSettings copyWithComfyModelForModule(
    ComfyUpscaleModule module,
    String model,
  ) {
    final normalizedModel = model.trim();
    return switch (module) {
      ComfyUpscaleModule.regular => copyWith(
        comfyModel: normalizedModel,
        comfyRegularModel: normalizedModel,
      ),
      ComfyUpscaleModule.seedvr2 => copyWith(
        comfyModel: normalizedModel,
        comfySeedvr2Model: normalizedModel,
      ),
      ComfyUpscaleModule.rtx => copyWith(comfyModel: normalizedModel),
    };
  }
}

class EnhanceWorkflowSettings {
  const EnhanceWorkflowSettings({
    this.magnitude = 0.5,
    this.showIndividualSettings = false,
    this.upscaleFactor = 1.0,
    this.strength = 0.5,
    this.noise = 0.175,
  });

  final double magnitude;
  final bool showIndividualSettings;
  final double upscaleFactor;
  final double strength;
  final double noise;

  EnhanceWorkflowSettings copyWith({
    double? magnitude,
    bool? showIndividualSettings,
    double? upscaleFactor,
    double? strength,
    double? noise,
  }) {
    return EnhanceWorkflowSettings(
      magnitude: magnitude ?? this.magnitude,
      showIndividualSettings:
          showIndividualSettings ?? this.showIndividualSettings,
      upscaleFactor: upscaleFactor ?? this.upscaleFactor,
      strength: strength ?? this.strength,
      noise: noise ?? this.noise,
    );
  }
}

class ImageWorkflowState {
  const ImageWorkflowState({
    this.mode = ImageWorkflowMode.base,
    this.sourceWidth,
    this.sourceHeight,
    this.sourceImageWidth,
    this.sourceImageHeight,
    this.baseWidth,
    this.baseHeight,
    this.baseStrength,
    this.baseNoise,
    this.baseModel,
    this.enhance = const EnhanceWorkflowSettings(),
    this.upscale = const UpscaleWorkflowSettings(),
    this.isPanelExpanded = false,
    this.isOutpaint = false,
    this.focusedInpaintEnabled = false,
    this.minimumContextMegaPixels = 88.0,
    this.focusedSelectionRect,
  });

  final ImageWorkflowMode mode;
  final int? sourceWidth;
  final int? sourceHeight;
  final int? sourceImageWidth;
  final int? sourceImageHeight;
  final int? baseWidth;
  final int? baseHeight;
  final double? baseStrength;
  final double? baseNoise;
  final String? baseModel;
  final EnhanceWorkflowSettings enhance;
  final UpscaleWorkflowSettings upscale;
  final bool isPanelExpanded;
  final bool isOutpaint;
  final bool focusedInpaintEnabled;
  final double minimumContextMegaPixels;
  final Rect? focusedSelectionRect;

  bool get isEnhance => mode == ImageWorkflowMode.enhance;
  bool get isInpaint => mode == ImageWorkflowMode.inpaint;
  bool get isUpscale => mode == ImageWorkflowMode.upscale;

  ImageWorkflowState copyWith({
    ImageWorkflowMode? mode,
    int? sourceWidth,
    int? sourceHeight,
    int? sourceImageWidth,
    int? sourceImageHeight,
    int? baseWidth,
    int? baseHeight,
    double? baseStrength,
    double? baseNoise,
    String? baseModel,
    EnhanceWorkflowSettings? enhance,
    UpscaleWorkflowSettings? upscale,
    bool? isPanelExpanded,
    bool? isOutpaint,
    bool? focusedInpaintEnabled,
    double? minimumContextMegaPixels,
    Rect? focusedSelectionRect,
    bool clearSourceSize = false,
    bool clearBaseSnapshot = false,
    bool clearFocusedSelectionRect = false,
  }) {
    return ImageWorkflowState(
      mode: mode ?? this.mode,
      sourceWidth: clearSourceSize ? null : (sourceWidth ?? this.sourceWidth),
      sourceHeight: clearSourceSize
          ? null
          : (sourceHeight ?? this.sourceHeight),
      sourceImageWidth: clearSourceSize
          ? null
          : (sourceImageWidth ?? this.sourceImageWidth),
      sourceImageHeight: clearSourceSize
          ? null
          : (sourceImageHeight ?? this.sourceImageHeight),
      baseWidth: clearBaseSnapshot ? null : (baseWidth ?? this.baseWidth),
      baseHeight: clearBaseSnapshot ? null : (baseHeight ?? this.baseHeight),
      baseStrength: clearBaseSnapshot
          ? null
          : (baseStrength ?? this.baseStrength),
      baseNoise: clearBaseSnapshot ? null : (baseNoise ?? this.baseNoise),
      baseModel: clearBaseSnapshot ? null : (baseModel ?? this.baseModel),
      enhance: enhance ?? this.enhance,
      upscale: upscale ?? this.upscale,
      isPanelExpanded: isPanelExpanded ?? this.isPanelExpanded,
      isOutpaint: isOutpaint ?? this.isOutpaint,
      focusedInpaintEnabled:
          focusedInpaintEnabled ?? this.focusedInpaintEnabled,
      minimumContextMegaPixels:
          minimumContextMegaPixels ?? this.minimumContextMegaPixels,
      focusedSelectionRect: clearFocusedSelectionRect
          ? null
          : (focusedSelectionRect ?? this.focusedSelectionRect),
    );
  }
}

final imageWorkflowControllerProvider =
    NotifierProvider<ImageWorkflowController, ImageWorkflowState>(
      ImageWorkflowController.new,
    );

class ImageWorkflowController extends Notifier<ImageWorkflowState> {
  int _sourceImageRequestId = 0;
  bool _isDisposed = false;

  ImageWorkflowState _buildDefaultState({
    EnhanceWorkflowSettings? enhance,
    UpscaleWorkflowSettings? upscale,
  }) {
    return ImageWorkflowState(
      enhance: enhance ?? const EnhanceWorkflowSettings(),
      upscale: upscale ?? const UpscaleWorkflowSettings(),
    );
  }

  @override
  ImageWorkflowState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _sourceImageRequestId++;
    });

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
    final persistedSeedvr2Model = _readPersistedComfyModelForModule(
      ComfyUpscaleModule.seedvr2,
      legacyModel: legacyPersistedModel,
    );
    final regularModel = persistedRegularModel.trim();
    final seedvr2Model = persistedSeedvr2Model.trim().isNotEmpty
        ? persistedSeedvr2Model.trim()
        : UpscaleWorkflowSettings.defaultComfyModel;
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
    final persistedEnhance = _readPersistedEnhanceSettings();

    return _buildDefaultState(
      enhance: persistedEnhance,
      upscale: UpscaleWorkflowSettings(
        backend: persistedBackend,
        comfyModule: persistedComfyModule,
        comfyScale: persistedScale,
        comfyModel: currentModel,
        comfyRegularModel: regularModel,
        comfySeedvr2Model: seedvr2Model,
        seedvr2VaeTileSize: persistedSeedvr2VaeTileSize,
        seedvr2Tiled: persistedSeedvr2Tiled,
        seedvr2TileSize: persistedSeedvr2TileSize,
      ),
    );
  }

  GenerationParamsNotifier get _paramsNotifier =>
      ref.read(generationParamsNotifierProvider.notifier);

  ImageParams get _params => ref.read(generationParamsNotifierProvider);
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

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

  EnhanceWorkflowSettings _readPersistedEnhanceSettings() {
    final rawMagnitude = _storage.getSetting(
      StorageKeys.workflowEnhanceMagnitude,
    );
    final rawShowIndividual = _storage.getSetting<bool>(
      StorageKeys.workflowEnhanceShowIndividualSettings,
      defaultValue: const EnhanceWorkflowSettings().showIndividualSettings,
    );
    final rawUpscaleFactor = _storage.getSetting(
      StorageKeys.workflowEnhanceUpscaleFactor,
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

    return EnhanceWorkflowSettings(
      magnitude: asDouble(
        rawMagnitude,
        const EnhanceWorkflowSettings().magnitude,
      ).clamp(0.0, 1.0),
      showIndividualSettings:
          rawShowIndividual ??
          const EnhanceWorkflowSettings().showIndividualSettings,
      upscaleFactor: asDouble(
        rawUpscaleFactor,
        const EnhanceWorkflowSettings().upscaleFactor,
      ).clamp(1.0, 1.5),
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

  void _persistUpscaleSettings(UpscaleWorkflowSettings settings) {
    final activeModel = settings.comfyModel.trim();
    final regularModel = settings.comfyRegularModel.trim();
    final seedvr2Model = settings.comfySeedvr2Model.trim();
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
  }

  void _persistEnhanceSettings(EnhanceWorkflowSettings settings) {
    unawaited(
      _storage.setSetting(
        StorageKeys.workflowEnhanceMagnitude,
        settings.magnitude,
      ),
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
        StorageKeys.workflowEnhanceStrength,
        settings.strength,
      ),
    );
    unawaited(
      _storage.setSetting(StorageKeys.workflowEnhanceNoise, settings.noise),
    );
  }

  /// 设置源图像，自动同步到 NovelAI Web 的 Image2Image 导入分辨率
  ///
  /// 官网会按当前参数尺寸、模型族和图片宽高比选择 64-grid 分辨率，
  /// 并在发送请求前把源图 resize 到同一尺寸；导入阶段保留原始图片字节。
  void replaceSourceImage(
    Uint8List imageBytes, {
    int? sourceWidth,
    int? sourceHeight,
    bool autoAdapt = true,
  }) {
    _sourceImageRequestId++;

    int? effectiveWidth = sourceWidth;
    int? effectiveHeight = sourceHeight;
    NaiImportImageInfo? importInfo;

    if (autoAdapt) {
      importInfo = NaiResolutionAdapter.describeImageForImport(
        imageBytes,
        currentWidth: sourceWidth ?? _params.width,
        currentHeight: sourceHeight ?? _params.height,
        isStableDiffusionFamily: _usesStableDiffusionImportBounds(
          _params.model,
        ),
      );
      if (importInfo != null) {
        effectiveWidth = importInfo.width;
        effectiveHeight = importInfo.height;
      }
    }

    _commitSourceImage(
      imageBytes,
      effectiveWidth: effectiveWidth,
      effectiveHeight: effectiveHeight,
      importInfo: importInfo,
    );
  }

  /// 异步设置源图像，用于拖入/文件选择等用户交互入口。
  ///
  /// 大图的尺寸解析会在后台 isolate 中执行；Lanczos3 重采样延迟到请求阶段。
  Future<void> replaceSourceImageAsync(
    Uint8List imageBytes, {
    int? sourceWidth,
    int? sourceHeight,
    bool autoAdapt = true,
  }) async {
    if (!autoAdapt) {
      replaceSourceImage(
        imageBytes,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        autoAdapt: false,
      );
      return;
    }

    final requestId = ++_sourceImageRequestId;
    final params = _params;
    final importInfo = await NaiResolutionAdapter.describeImageForImportAsync(
      imageBytes,
      currentWidth: sourceWidth ?? params.width,
      currentHeight: sourceHeight ?? params.height,
      isStableDiffusionFamily: _usesStableDiffusionImportBounds(params.model),
    );

    if (_isDisposed || requestId != _sourceImageRequestId) return;

    _commitSourceImage(
      imageBytes,
      effectiveWidth: importInfo?.width ?? sourceWidth,
      effectiveHeight: importInfo?.height ?? sourceHeight,
      importInfo: importInfo,
    );
  }

  void _commitSourceImage(
    Uint8List effectiveBytes, {
    int? effectiveWidth,
    int? effectiveHeight,
    NaiImportImageInfo? importInfo,
  }) {
    if (importInfo != null && importInfo.sizeChanged) {
      AppLogger.i(
        'Image import size adapted: ${importInfo.resizeDescription}',
        'ImageWorkflow',
      );
    }

    _paramsNotifier.setSourceImage(effectiveBytes);
    _paramsNotifier.updateIsOutpaint(false);

    final requestSize = _resolveImageSize(
      effectiveBytes,
      width: effectiveWidth,
      height: effectiveHeight,
    );
    final sourceImageSize = importInfo == null
        ? _resolveImageSize(effectiveBytes)
        : (importInfo.originalWidth, importInfo.originalHeight);
    state = state.copyWith(
      sourceWidth: requestSize?.$1,
      sourceHeight: requestSize?.$2,
      sourceImageWidth: sourceImageSize?.$1,
      sourceImageHeight: sourceImageSize?.$2,
      isOutpaint: false,
      clearFocusedSelectionRect: true,
    );

    switch (state.mode) {
      case ImageWorkflowMode.enhance:
        _ensureBaseSnapshot();
        _applyEnhanceToParams();
        break;
      case ImageWorkflowMode.upscale:
        _ensureBaseSnapshot();
        _applySourceSizeToParams();
        break;
      case ImageWorkflowMode.inpaint:
        _restoreBaseParams();
        _applySourceSizeToParams();
        _paramsNotifier.setMaskImage(null);
        state = state.copyWith(
          mode: ImageWorkflowMode.base,
          isOutpaint: false,
          clearBaseSnapshot: true,
          clearFocusedSelectionRect: true,
        );
        _paramsNotifier.updateAction(ImageGenerationAction.img2img);
        break;
      case ImageWorkflowMode.base:
        _ensureBaseSnapshot();
        _applySourceSizeToParams();
        _paramsNotifier.updateAction(ImageGenerationAction.img2img);
        break;
    }
  }

  void clearSourceImage() {
    if (state.baseWidth != null ||
        state.baseHeight != null ||
        state.baseModel != null) {
      _restoreBaseParams();
    } else if (ImageModels.isInpaintingModel(_params.model)) {
      _paramsNotifier.updateModel(
        _resolveBaseModel(_params.model),
        persist: false,
      );
    }

    _paramsNotifier.clearImg2Img();
    _paramsNotifier.setMaskImage(null);
    state = _buildDefaultState(enhance: state.enhance, upscale: state.upscale);
  }

  void setPanelExpanded(bool value) {
    state = state.copyWith(isPanelExpanded: value);
  }

  void setSourceImageDimensions(int? width, int? height) {
    state = state.copyWith(sourceWidth: width, sourceHeight: height);
    if (state.mode == ImageWorkflowMode.enhance) {
      _applyEnhanceToParams();
    }
  }

  void enterUpscaleMode() {
    if (_params.sourceImage == null) {
      return;
    }

    if (state.mode == ImageWorkflowMode.enhance) {
      _restoreBaseParams();
    }
    if (state.mode == ImageWorkflowMode.inpaint) {
      _restoreBaseParams();
    }

    _ensureBaseSnapshot();
    state = state.copyWith(
      mode: ImageWorkflowMode.upscale,
      isPanelExpanded: true,
      isOutpaint: false,
    );
    _applySourceSizeToParams();
    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(ImageGenerationAction.img2img);
  }

  void exitUpscaleMode() {
    if (state.mode != ImageWorkflowMode.upscale) {
      return;
    }

    _restoreBaseParams();
    state = state.copyWith(
      mode: ImageWorkflowMode.base,
      isOutpaint: false,
      clearBaseSnapshot: true,
    );
    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(
      _params.sourceImage != null
          ? ImageGenerationAction.img2img
          : ImageGenerationAction.generate,
    );
  }

  void updateUpscaleComfyScale(double scale) {
    final nextSettings = state.upscale.copyWith(
      comfyScale: scale.clamp(
        UpscaleWorkflowSettings.minScale,
        UpscaleWorkflowSettings.maxScale,
      ),
    );
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateUpscaleComfyModel(String model) {
    final nextSettings = state.upscale.copyWithComfyModelForModule(
      state.upscale.comfyModule,
      model,
    );
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateComfyUpscaleModule(ComfyUpscaleModule module) {
    final nextSettings = state.upscale.copyWith(
      comfyModule: module,
      comfyModel: state.upscale.comfyModelForModule(module),
    );
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateUpscaleBackend(UpscaleBackend backend) {
    final nextSettings = state.upscale.copyWith(backend: backend);
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateSeedvr2VaeTileSize(double value) {
    final nextSettings = state.upscale.copyWith(
      seedvr2VaeTileSize: value
          .round()
          .clamp(
            UpscaleWorkflowSettings.minSeedvr2VaeTileSize,
            UpscaleWorkflowSettings.maxSeedvr2VaeTileSize,
          )
          .toInt(),
    );
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateSeedvr2Tiled(bool value) {
    final nextSettings = state.upscale.copyWith(seedvr2Tiled: value);
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void updateSeedvr2TileSize(double value) {
    final nextSettings = state.upscale.copyWith(
      seedvr2TileSize: value
          .round()
          .clamp(
            UpscaleWorkflowSettings.minSeedvr2TileSize,
            UpscaleWorkflowSettings.maxSeedvr2TileSize,
          )
          .toInt(),
    );
    state = state.copyWith(upscale: nextSettings);
    _persistUpscaleSettings(nextSettings);
  }

  void setFocusedInpaintEnabled(bool value) {
    state = state.copyWith(
      focusedInpaintEnabled: value,
      clearFocusedSelectionRect: !value,
    );
  }

  void setMinimumContextMegaPixels(double value) {
    final context = value.clamp(16.0, 192.0);
    final constrainedSelection = _constrainFocusedSelection(
      state.focusedSelectionRect,
      minimumContextMegaPixels: context,
    );
    state = state.copyWith(
      minimumContextMegaPixels: context,
      focusedSelectionRect: constrainedSelection,
      clearFocusedSelectionRect:
          state.focusedSelectionRect != null && constrainedSelection == null,
    );
  }

  void setFocusedSelectionRect(Rect? rect) {
    final constrainedSelection = _constrainFocusedSelection(
      rect,
      minimumContextMegaPixels: state.minimumContextMegaPixels,
    );
    state = state.copyWith(
      focusedSelectionRect: constrainedSelection,
      clearFocusedSelectionRect: constrainedSelection == null,
    );
  }

  Rect? _constrainFocusedSelection(
    Rect? rect, {
    required double minimumContextMegaPixels,
  }) {
    if (rect == null) return null;
    final width = state.sourceImageWidth ?? state.sourceWidth;
    final height = state.sourceImageHeight ?? state.sourceHeight;
    if (width == null || height == null) return rect;
    return FocusedInpaintUtils.constrainSelectionRect(
      sourceWidth: width,
      sourceHeight: height,
      selectionRect: rect,
      minContextMegaPixels: minimumContextMegaPixels,
    );
  }

  void applyInpaintEditorResult({
    Uint8List? sourceImage,
    int? sourceWidth,
    int? sourceHeight,
    required Uint8List? maskImage,
    required bool focusedInpaintEnabled,
    required Rect? focusedSelectionRect,
    required double minimumContextMegaPixels,
    bool forceDisableFocusedInpaint = false,
    bool sourceIsOutpaint = true,
    bool useExactSourceDimensions = false,
  }) {
    final hasReplacementSource = sourceImage != null;
    if (hasReplacementSource) {
      if (sourceWidth == null || sourceHeight == null) {
        throw ArgumentError(
          sourceIsOutpaint
              ? 'Outpaint source dimensions are required'
              : 'Editor source dimensions are required',
        );
      }
      if (sourceIsOutpaint &&
          !NaiResolutionAdapter.isCompatible(sourceWidth, sourceHeight)) {
        throw ArgumentError('Outpaint source dimensions must be 64-compatible');
      }
    }

    if (_params.sourceImage == null && !hasReplacementSource) {
      return;
    }

    if (state.mode == ImageWorkflowMode.enhance ||
        state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    NaiImportImageInfo? importInfo;
    if (hasReplacementSource) {
      _paramsNotifier.setSourceImage(sourceImage);
      if (!useExactSourceDimensions) {
        importInfo = NaiResolutionAdapter.describeImageForImport(
          sourceImage,
          currentWidth: _params.width,
          currentHeight: _params.height,
          isStableDiffusionFamily: _usesStableDiffusionImportBounds(
            _params.model,
          ),
        );
      }
    }

    _ensureBaseSnapshot();

    final actualSourceWidth = hasReplacementSource
        ? (importInfo?.originalWidth ?? sourceWidth)
        : (state.sourceImageWidth ?? state.sourceWidth);
    final actualSourceHeight = hasReplacementSource
        ? (importInfo?.originalHeight ?? sourceHeight)
        : (state.sourceImageHeight ?? state.sourceHeight);
    final constrainedSelection = switch ((
      forceDisableFocusedInpaint,
      focusedSelectionRect,
      actualSourceWidth,
      actualSourceHeight,
    )) {
      (false, final Rect rect, final int width, final int height) =>
        FocusedInpaintUtils.constrainSelectionRect(
          sourceWidth: width,
          sourceHeight: height,
          selectionRect: rect,
          minContextMegaPixels: minimumContextMegaPixels,
        ),
      _ => null,
    };
    final effectiveFocusedInpaintEnabled =
        !forceDisableFocusedInpaint &&
        focusedInpaintEnabled &&
        constrainedSelection != null;
    state = state.copyWith(
      mode: ImageWorkflowMode.inpaint,
      sourceWidth: hasReplacementSource
          ? (importInfo?.width ?? sourceWidth)
          : null,
      sourceHeight: hasReplacementSource
          ? (importInfo?.height ?? sourceHeight)
          : null,
      sourceImageWidth: hasReplacementSource ? actualSourceWidth : null,
      sourceImageHeight: hasReplacementSource ? actualSourceHeight : null,
      isPanelExpanded: true,
      isOutpaint: hasReplacementSource && sourceIsOutpaint,
      focusedInpaintEnabled: effectiveFocusedInpaintEnabled,
      minimumContextMegaPixels: minimumContextMegaPixels.clamp(16.0, 192.0),
      focusedSelectionRect: constrainedSelection,
      clearFocusedSelectionRect: !effectiveFocusedInpaintEnabled,
    );

    _applySourceSizeToParams();
    _paramsNotifier.setMaskImage(maskImage);
    _syncInpaintRequestState();
  }

  void enterEnhanceMode() {
    if (_params.sourceImage == null) {
      return;
    }

    if (state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    _ensureBaseSnapshot();
    state = state.copyWith(
      mode: ImageWorkflowMode.enhance,
      isPanelExpanded: true,
      isOutpaint: false,
    );
    _paramsNotifier.updateIsOutpaint(false);
    _applyEnhanceToParams();
  }

  void exitEnhanceMode() {
    if (state.mode != ImageWorkflowMode.enhance) {
      return;
    }

    _restoreBaseParams();
    state = state.copyWith(
      mode: ImageWorkflowMode.base,
      isOutpaint: false,
      clearBaseSnapshot: true,
    );
    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(
      _params.sourceImage != null
          ? ImageGenerationAction.img2img
          : ImageGenerationAction.generate,
    );
  }

  void enterInpaintMode() {
    if (_params.sourceImage == null) {
      return;
    }

    if (state.mode == ImageWorkflowMode.enhance) {
      _restoreBaseParams();
    }
    if (state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    _ensureBaseSnapshot();
    state = state.copyWith(
      mode: ImageWorkflowMode.inpaint,
      isPanelExpanded: true,
      isOutpaint: false,
    );

    _applySourceSizeToParams();
    _syncInpaintRequestState();
  }

  void enterBaseMode({bool clearMask = true}) {
    final shouldRestoreBaseSnapshot =
        state.mode == ImageWorkflowMode.enhance ||
        state.mode == ImageWorkflowMode.inpaint ||
        state.mode == ImageWorkflowMode.upscale;

    if (shouldRestoreBaseSnapshot) {
      _restoreBaseParams();
    }

    if (clearMask) {
      _paramsNotifier.setMaskImage(null);
    }

    state = state.copyWith(
      mode: ImageWorkflowMode.base,
      isOutpaint: false,
      clearBaseSnapshot: shouldRestoreBaseSnapshot,
      clearFocusedSelectionRect: clearMask,
    );
    _applySourceSizeToParams();
    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(
      _params.sourceImage != null
          ? ImageGenerationAction.img2img
          : ImageGenerationAction.generate,
    );
  }

  void onMaskChanged(Uint8List? mask) {
    _paramsNotifier.setMaskImage(mask);
    if (state.mode == ImageWorkflowMode.inpaint) {
      _syncInpaintRequestState();
    }
  }

  void updateEnhanceMagnitude(double value) {
    final resolved = _resolveMagnitude(value);
    final nextSettings = state.enhance.copyWith(
      magnitude: value.clamp(0.0, 1.0),
      strength: state.enhance.showIndividualSettings
          ? state.enhance.strength
          : resolved.$1,
      noise: state.enhance.showIndividualSettings
          ? state.enhance.noise
          : resolved.$2,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);

    if (!state.enhance.showIndividualSettings) {
      _applyEnhanceToParams();
    }
  }

  void toggleEnhanceIndividualSettings(bool value) {
    final resolved = _resolveMagnitude(state.enhance.magnitude);
    final nextSettings = state.enhance.copyWith(
      showIndividualSettings: value,
      strength: value ? state.enhance.strength : resolved.$1,
      noise: value ? state.enhance.noise : resolved.$2,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  void updateEnhanceUpscaleFactor(double factor) {
    final nextSettings = state.enhance.copyWith(
      upscaleFactor: factor <= 1.0 ? 1.0 : 1.5,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  void updateEnhanceIndividualSettings({double? strength, double? noise}) {
    final nextSettings = state.enhance.copyWith(
      showIndividualSettings: true,
      strength: strength ?? state.enhance.strength,
      noise: noise ?? state.enhance.noise,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  void _ensureBaseSnapshot() {
    if (state.baseWidth != null &&
        state.baseHeight != null &&
        state.baseStrength != null &&
        state.baseNoise != null) {
      return;
    }

    state = state.copyWith(
      baseWidth: _params.width,
      baseHeight: _params.height,
      baseStrength: _params.strength,
      baseNoise: _params.noise,
      baseModel: _resolveBaseModel(_params.model),
    );
  }

  void _restoreBaseParams() {
    if (state.baseWidth != null && state.baseHeight != null) {
      _paramsNotifier.updateSize(
        state.baseWidth!,
        state.baseHeight!,
        persist: false,
      );
    }
    if (state.baseStrength != null) {
      _paramsNotifier.updateStrength(state.baseStrength!);
    }
    if (state.baseNoise != null) {
      _paramsNotifier.updateNoise(state.baseNoise!);
    }
    if (state.baseModel != null) {
      _paramsNotifier.updateModel(state.baseModel!, persist: false);
    }
  }

  void _applyEnhanceToParams() {
    if (_params.sourceImage == null) {
      return;
    }

    final baseWidth = state.sourceWidth ?? state.baseWidth ?? _params.width;
    final baseHeight = state.sourceHeight ?? state.baseHeight ?? _params.height;
    final requestWidth = _normalizeDimension(
      (baseWidth * state.enhance.upscaleFactor).round(),
    );
    final requestHeight = _normalizeDimension(
      (baseHeight * state.enhance.upscaleFactor).round(),
    );
    final resolved = state.enhance.showIndividualSettings
        ? (state.enhance.strength, state.enhance.noise)
        : _resolveMagnitude(state.enhance.magnitude);

    _paramsNotifier.updateSize(requestWidth, requestHeight, persist: false);
    _paramsNotifier.updateStrength(resolved.$1);
    _paramsNotifier.updateNoise(resolved.$2);
    _paramsNotifier.updateAction(ImageGenerationAction.img2img);
  }

  void _applySourceSizeToParams() {
    final width = state.sourceWidth;
    final height = state.sourceHeight;
    if (width == null || height == null) {
      return;
    }

    _paramsNotifier.updateSize(width, height, persist: false);
  }

  void _applyInpaintModel() {
    final sourceModel = state.baseModel ?? _params.model;
    _paramsNotifier.updateModel(
      _resolveInpaintModel(sourceModel),
      persist: false,
    );
  }

  void _restoreBaseModel() {
    final baseModel = state.baseModel ?? _resolveBaseModel(_params.model);
    _paramsNotifier.updateModel(baseModel, persist: false);
  }

  void _syncInpaintRequestState() {
    if (state.mode != ImageWorkflowMode.inpaint) {
      return;
    }

    if (_params.maskImage != null) {
      _applyInpaintModel();
      _paramsNotifier.updateIsOutpaint(state.isOutpaint);
      _paramsNotifier.updateAction(ImageGenerationAction.infill);
      return;
    }

    _restoreBaseModel();
    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(ImageGenerationAction.img2img);
  }

  String _resolveInpaintModel(String model) {
    if (ImageModels.isInpaintingModel(model)) {
      return model;
    }

    switch (model) {
      case ImageModels.animeDiffusionV45Full:
        return ImageModels.animeDiffusionV45FullInpainting;
      case ImageModels.animeDiffusionV45Curated:
        return ImageModels.animeDiffusionV45CuratedInpainting;
      case ImageModels.animeDiffusionV4Full:
        return ImageModels.animeDiffusionV4FullInpainting;
      case ImageModels.animeDiffusionV4Curated:
        return ImageModels.animeDiffusionV4CuratedInpainting;
      case ImageModels.furryDiffusion:
      case ImageModels.furryDiffusionV3:
        return ImageModels.furryDiffusionV3Inpainting;
      case ImageModels.animeDiffusionV3:
      default:
        return ImageModels.animeDiffusionV3Inpainting;
    }
  }

  String _resolveBaseModel(String model) {
    switch (model) {
      case ImageModels.animeDiffusionV45FullInpainting:
        return ImageModels.animeDiffusionV45Full;
      case ImageModels.animeDiffusionV45CuratedInpainting:
        return ImageModels.animeDiffusionV45Curated;
      case ImageModels.animeDiffusionV4FullInpainting:
        return ImageModels.animeDiffusionV4Full;
      case ImageModels.animeDiffusionV4CuratedInpainting:
        return ImageModels.animeDiffusionV4Curated;
      case ImageModels.furryDiffusionV3Inpainting:
        return ImageModels.furryDiffusionV3;
      case ImageModels.animeDiffusionV3Inpainting:
        return ImageModels.animeDiffusionV3;
      default:
        return model;
    }
  }

  (double, double) _resolveMagnitude(double magnitude) {
    final clamped = magnitude.clamp(0.0, 1.0);
    // Magnitude 在 UI 中作为 Strength/Noise 的快捷联动值使用。
    // 这里先采用保守映射，避免增强时默认噪声过高。
    return (clamped, clamped * 0.35);
  }

  int _normalizeDimension(int value) {
    final normalized = ((value + 32) ~/ 64) * 64;
    return normalized.clamp(64, 4096);
  }

  bool _usesStableDiffusionImportBounds(String model) {
    final baseModel = _resolveBaseModel(model);
    return baseModel == ImageModels.animeCurated ||
        baseModel == ImageModels.animeFull ||
        baseModel == ImageModels.furry;
  }

  (int, int)? _resolveImageSize(
    Uint8List imageBytes, {
    int? width,
    int? height,
  }) {
    if (width != null && height != null) {
      return (width, height);
    }

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      return null;
    }
    return (decoded.width, decoded.height);
  }
}
