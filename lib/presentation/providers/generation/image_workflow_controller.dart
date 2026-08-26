import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/comfyui/seedvr2_support.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_panel_expansion_provider.dart';
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

const String comfySeedvr2NativeUpscaleTemplateId =
    'builtin_seedvr2_native_upscale';
const String comfySeedvr2LegacyUpscaleTemplateId = 'builtin_seedvr2_upscale';
const String comfySeedvr2LegacyTiledUpscaleTemplateId =
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

  const preferences = [
    ['3b', 'int8'],
    ['3b', 'fp8'],
    ['3b', 'q4'],
    ['7b', 'int8'],
    ['7b', 'fp8'],
    ['7b', 'fp16'],
  ];
  for (final preference in preferences) {
    for (final model in normalizedModels) {
      final lower = model.toLowerCase();
      if (preference.every(lower.contains)) return model;
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

/// 决定 SeedVR2 是否把 DiT 的输入输出组件（embedding 与归一化层）也卸载到
/// CPU 内存。
///
/// 上游把这个开关描述为「在 blocks_to_swap 之上进一步压低显存」的手段，默认
/// 关闭，只在显存确实吃紧时才建议打开；它同样要求 offload_device 已设置。
/// 启动器此前把它固定为 true，导致用户即使把 [blocksToSwap] 调到 0，仍有一部分
/// 权重留在内存里、每次前向都要经 PCIe 往返。
///
/// [blocksToSwap] 为用户在界面上设定的层数，范围见
/// [UpscaleWorkflowSettings.minSeedvr2BlocksToSwap] 与
/// [UpscaleWorkflowSettings.maxSeedvr2BlocksToSwap]。
bool resolveSeedvr2SwapIoComponents(int blocksToSwap) {
  return blocksToSwap >= seedvr2SwapIoComponentsThreshold;
}

/// [resolveSeedvr2SwapIoComponents] 启用输入输出组件卸载的层数阈值。
///
/// 取值落在默认档（[UpscaleWorkflowSettings.defaultSeedvr2BlocksToSwap]）与
/// 上游给 8GB 显存的推荐档（32）之间：停在中低档位说明显存尚有余量，不值得
/// 为有限的显存收益换来每次前向都要付的 PCIe 往返；用户主动调到该档位以上，
/// 才说明显存确实吃紧、需要这个额外手段。
const int seedvr2SwapIoComponentsThreshold = 24;

/// 图生图「超分」子模式设置
class UpscaleWorkflowSettings {
  const UpscaleWorkflowSettings({
    this.backend = defaultBackend,
    this.comfyModule = defaultComfyModule,
    this.comfyScale = defaultComfyScale,
    this.comfyModel = defaultComfyModel,
    this.comfyRegularModel = defaultComfyRegularModel,
    this.comfySeedvr2NativeModel = defaultComfyModel,
    this.comfySeedvr2LegacyModel = defaultLegacyComfyModel,
    this.seedvr2Engine = ComfySeedvr2Engine.automatic,
    this.seedvr2VaeTileSize = defaultSeedvr2VaeTileSize,
    this.seedvr2Tiled = false,
    this.seedvr2TileSize = defaultSeedvr2TileSize,
    this.seedvr2BlocksToSwap = defaultSeedvr2BlocksToSwap,
    this.seedvr2EmbedNaiMetadata = false,
  });

  static const UpscaleBackend defaultBackend = UpscaleBackend.comfyui;
  static const ComfyUpscaleModule defaultComfyModule =
      ComfyUpscaleModule.seedvr2;
  static const double defaultComfyScale = 1.5;
  static const String defaultComfyModel = 'seedvr2_3b_int8_convrot.safetensors';
  static const String defaultLegacyComfyModel =
      'seedvr2_ema_3b_fp8_e4m3fn.safetensors';
  static const String defaultComfyRegularModel = '';
  static const int defaultSeedvr2VaeTileSize = 1024;
  static const int defaultSeedvr2TileSize = 1024;

  /// SeedVR2 DiT 主干中放在 CPU 内存、推理时再逐层搬进显存的层数。
  ///
  /// 这个值决定权重在显存和内存之间怎么切分：调高省显存但吃内存并变慢，
  /// 调低反之。默认取上游建议的起步值，保证 8GB 显存搭配默认的 3B 量化模型
  /// 可以直接跑起来；显存充裕的用户可以在界面上调低以释放内存。
  static const int defaultSeedvr2BlocksToSwap = 16;

  final UpscaleBackend backend;
  final ComfyUpscaleModule comfyModule;
  final double comfyScale;
  final String comfyModel;
  final String comfyRegularModel;
  final String comfySeedvr2NativeModel;
  final String comfySeedvr2LegacyModel;
  final ComfySeedvr2Engine seedvr2Engine;
  final int seedvr2VaeTileSize;
  final bool seedvr2Tiled;
  final int seedvr2TileSize;
  final int seedvr2BlocksToSwap;
  final bool seedvr2EmbedNaiMetadata;

  static const double minScale = 1.0;
  static const double maxScale = 2.0;
  static const int minSeedvr2VaeTileSize = 128;
  static const int maxSeedvr2VaeTileSize = 4096;
  static const int minSeedvr2TileSize = 256;
  static const int maxSeedvr2TileSize = 4096;
  static const int minSeedvr2BlocksToSwap = 0;

  /// 上游节点对 7B 模型的上限即为 36；更小的模型层数不足时会自行截断。
  static const int maxSeedvr2BlocksToSwap = 36;

  UpscaleWorkflowSettings copyWith({
    UpscaleBackend? backend,
    ComfyUpscaleModule? comfyModule,
    double? comfyScale,
    String? comfyModel,
    String? comfyRegularModel,
    String? comfySeedvr2NativeModel,
    String? comfySeedvr2LegacyModel,
    ComfySeedvr2Engine? seedvr2Engine,
    int? seedvr2VaeTileSize,
    bool? seedvr2Tiled,
    int? seedvr2TileSize,
    int? seedvr2BlocksToSwap,
    bool? seedvr2EmbedNaiMetadata,
  }) {
    return UpscaleWorkflowSettings(
      backend: backend ?? this.backend,
      comfyModule: comfyModule ?? this.comfyModule,
      comfyScale: comfyScale ?? this.comfyScale,
      comfyModel: comfyModel ?? this.comfyModel,
      comfyRegularModel: comfyRegularModel ?? this.comfyRegularModel,
      comfySeedvr2NativeModel:
          comfySeedvr2NativeModel ?? this.comfySeedvr2NativeModel,
      comfySeedvr2LegacyModel:
          comfySeedvr2LegacyModel ?? this.comfySeedvr2LegacyModel,
      seedvr2Engine: seedvr2Engine ?? this.seedvr2Engine,
      seedvr2VaeTileSize: seedvr2VaeTileSize ?? this.seedvr2VaeTileSize,
      seedvr2Tiled: seedvr2Tiled ?? this.seedvr2Tiled,
      seedvr2TileSize: seedvr2TileSize ?? this.seedvr2TileSize,
      seedvr2BlocksToSwap: seedvr2BlocksToSwap ?? this.seedvr2BlocksToSwap,
      seedvr2EmbedNaiMetadata:
          seedvr2EmbedNaiMetadata ?? this.seedvr2EmbedNaiMetadata,
    );
  }

  String get comfySeedvr2Model => comfySeedvr2ModelForBackend(null);

  String comfySeedvr2ModelForBackend(ComfySeedvr2Backend? backend) {
    final effectiveBackend =
        backend ??
        (seedvr2Engine == ComfySeedvr2Engine.legacy
            ? ComfySeedvr2Backend.legacy
            : ComfySeedvr2Backend.native);
    return switch (effectiveBackend) {
      ComfySeedvr2Backend.native => comfySeedvr2NativeModel,
      ComfySeedvr2Backend.legacy => comfySeedvr2LegacyModel,
    };
  }

  String comfyModelForModule(
    ComfyUpscaleModule module, {
    ComfySeedvr2Backend? seedvr2Backend,
  }) {
    return switch (module) {
      ComfyUpscaleModule.regular => comfyRegularModel,
      ComfyUpscaleModule.seedvr2 => comfySeedvr2ModelForBackend(seedvr2Backend),
      ComfyUpscaleModule.rtx => comfyModel,
    };
  }

  UpscaleWorkflowSettings copyWithComfyModelForModule(
    ComfyUpscaleModule module,
    String model, {
    ComfySeedvr2Backend? seedvr2Backend,
  }) {
    final normalizedModel = model.trim();
    return switch (module) {
      ComfyUpscaleModule.regular => copyWith(
        comfyModel: normalizedModel,
        comfyRegularModel: normalizedModel,
      ),
      ComfyUpscaleModule.seedvr2 => switch (seedvr2Backend ??
          (seedvr2Engine == ComfySeedvr2Engine.legacy
              ? ComfySeedvr2Backend.legacy
              : ComfySeedvr2Backend.native)) {
        ComfySeedvr2Backend.native => copyWith(
          comfyModel: normalizedModel,
          comfySeedvr2NativeModel: normalizedModel,
        ),
        ComfySeedvr2Backend.legacy => copyWith(
          comfyModel: normalizedModel,
          comfySeedvr2LegacyModel: normalizedModel,
        ),
      },
      ComfyUpscaleModule.rtx => copyWith(comfyModel: normalizedModel),
    };
  }
}

class EnhanceWorkflowSettings {
  const EnhanceWorkflowSettings({
    this.level = EnhanceLevels.defaultLevel,
    this.showIndividualSettings = false,
    this.upscaleFactor = 1.0,
    this.maxScale = false,
    this.strength = 0.5,
    this.noise = 0.0,
  });

  /// 官网口径的 1-5 档幅度。
  final int level;
  final bool showIndividualSettings;
  final double upscaleFactor;

  /// max 档：不按倍率放大，交给服务端放到 3.14MP 上限。
  final bool maxScale;
  final double strength;
  final double noise;

  EnhanceWorkflowSettings copyWith({
    int? level,
    bool? showIndividualSettings,
    double? upscaleFactor,
    bool? maxScale,
    double? strength,
    double? noise,
  }) {
    return EnhanceWorkflowSettings(
      level: level ?? this.level,
      showIndividualSettings:
          showIndividualSettings ?? this.showIndividualSettings,
      upscaleFactor: upscaleFactor ?? this.upscaleFactor,
      maxScale: maxScale ?? this.maxScale,
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
    bool? isPanelExpanded,
  }) {
    return ImageWorkflowState(
      enhance: enhance ?? const EnhanceWorkflowSettings(),
      upscale: upscale ?? const UpscaleWorkflowSettings(),
      isPanelExpanded: isPanelExpanded ?? false,
    );
  }

  @override
  ImageWorkflowState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _sourceImageRequestId++;
    });
    ref.listen<String>(
      generationParamsNotifierProvider.select((params) => params.model),
      (previous, next) {
        if (previous != next && state.mode == ImageWorkflowMode.enhance) {
          _applyEnhanceToParams();
        }
      },
    );
    ref.listen<bool>(
      generationPanelExpansionProvider.select(
        (value) => value.isExpanded(GenerationWorkbenchPanel.img2img),
      ),
      (previous, next) {
        if (state.isPanelExpanded != next) {
          state = state.copyWith(isPanelExpanded: next);
        }
      },
    );

    final persistedPanelExpanded = ref
        .read(generationPanelExpansionProvider)
        .isExpanded(GenerationWorkbenchPanel.img2img);
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
        : previousModel.isNotEmpty && !_isLegacySeedvr2ModelName(previousModel)
        ? previousModel
        : UpscaleWorkflowSettings.defaultComfyModel;
    final legacyModel = persistedLegacyModel.trim().isNotEmpty
        ? persistedLegacyModel.trim()
        : previousModel.isNotEmpty && _isLegacySeedvr2ModelName(previousModel)
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
    final persistedEnhance = _readPersistedEnhanceSettings();

    return _buildDefaultState(
      enhance: persistedEnhance,
      isPanelExpanded: persistedPanelExpanded,
      upscale: UpscaleWorkflowSettings(
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

  static bool _isLegacySeedvr2ModelName(String model) {
    final normalized = model.trim().toLowerCase();
    return normalized.contains('seedvr2_ema_') ||
        normalized.endsWith('.gguf') ||
        normalized.contains('_q4');
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

  void _persistUpscaleSettings(UpscaleWorkflowSettings settings) {
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

  void _persistEnhanceSettings(EnhanceWorkflowSettings settings) {
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
    if (state.baseWidth != null || state.baseHeight != null) {
      _restoreBaseParams();
    } else if (ImageModels.isInpaintingModel(_params.model)) {
      _paramsNotifier.updateModel(
        ImageModels.resolveBaseModel(_params.model),
        persist: false,
        followDefaults: false,
      );
    }

    _paramsNotifier.clearImg2Img();
    _paramsNotifier.setMaskImage(null);
    state = _buildDefaultState(
      enhance: state.enhance,
      upscale: state.upscale,
      isPanelExpanded: state.isPanelExpanded,
    );
  }

  void setPanelExpanded(bool value) {
    if (state.isPanelExpanded != value) {
      state = state.copyWith(isPanelExpanded: value);
    }
    unawaited(
      ref
          .read(generationPanelExpansionProvider.notifier)
          .setExpanded(GenerationWorkbenchPanel.img2img, value),
    );
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
    setPanelExpanded(true);
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

  void updateUpscaleComfyModel(
    String model, {
    ComfySeedvr2Backend? seedvr2Backend,
  }) {
    final nextSettings = state.upscale.copyWithComfyModelForModule(
      state.upscale.comfyModule,
      model,
      seedvr2Backend: seedvr2Backend,
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

  void updateSeedvr2Engine(ComfySeedvr2Engine engine) {
    final backend = engine == ComfySeedvr2Engine.legacy
        ? ComfySeedvr2Backend.legacy
        : ComfySeedvr2Backend.native;
    final nextSettings = state.upscale.copyWith(
      seedvr2Engine: engine,
      comfyModel: state.upscale.comfySeedvr2ModelForBackend(backend),
    );
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

  void updateSeedvr2EmbedNaiMetadata(bool value) {
    final nextSettings = state.upscale.copyWith(seedvr2EmbedNaiMetadata: value);
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

  void updateSeedvr2BlocksToSwap(double value) {
    final nextSettings = state.upscale.copyWith(
      seedvr2BlocksToSwap: value
          .round()
          .clamp(
            UpscaleWorkflowSettings.minSeedvr2BlocksToSwap,
            UpscaleWorkflowSettings.maxSeedvr2BlocksToSwap,
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
    setPanelExpanded(true);

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
    setPanelExpanded(true);
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
    setPanelExpanded(true);

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

  void updateEnhanceLevel(int level) {
    final clamped = level.clamp(EnhanceLevels.minLevel, EnhanceLevels.maxLevel);
    final resolved = EnhanceLevels.resolve(clamped);
    final nextSettings = state.enhance.copyWith(
      level: clamped,
      strength: state.enhance.showIndividualSettings
          ? state.enhance.strength
          : resolved.strength,
      noise: state.enhance.showIndividualSettings
          ? state.enhance.noise
          : resolved.noise,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);

    if (!state.enhance.showIndividualSettings) {
      _applyEnhanceToParams();
    }
  }

  void toggleEnhanceIndividualSettings(bool value) {
    final resolved = EnhanceLevels.resolve(state.enhance.level);
    final nextSettings = state.enhance.copyWith(
      showIndividualSettings: value,
      strength: value ? state.enhance.strength : resolved.strength,
      noise: value ? state.enhance.noise : resolved.noise,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  void updateEnhanceUpscaleFactor(double factor) {
    final nextSettings = state.enhance.copyWith(
      upscaleFactor: EnhanceScales.resolveFactor(
        factor,
        sourceWidth: state.sourceWidth ?? state.baseWidth,
        sourceHeight: state.sourceHeight ?? state.baseHeight,
      ),
      maxScale: false,
    );
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  /// 切到 max 档：不按倍率放大，服务端把结果放到 3.14MP 上限。
  void selectEnhanceMaxScale() {
    if (!isMaxEnhanceAvailable) {
      return;
    }
    final nextSettings = state.enhance.copyWith(maxScale: true);
    state = state.copyWith(enhance: nextSettings);
    _persistEnhanceSettings(nextSettings);
    _applyEnhanceToParams();
  }

  /// max 档在当前模型与源图尺寸下是否可用。
  bool get isMaxEnhanceAvailable => E2eUpscale.allowsMaxEnhance(
    _params.capabilities,
    sourceWidth: state.sourceWidth ?? state.baseWidth,
    sourceHeight: state.sourceHeight ?? state.baseHeight,
  );

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
    );
  }

  void _restoreBaseParams() {
    // 增强专属的一次性标记只属于增强请求，离开增强模式必须清掉，
    // 否则后续普通生成会带着 max 档参数或自动补的降权词发出去。
    _paramsNotifier.updateUpscaledEnhance(false);
    _paramsNotifier.updateIsEnhanceRequest(false);
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
  }

  void _applyEnhanceToParams() {
    if (_params.sourceImage == null) {
      return;
    }

    final baseWidth = state.sourceWidth ?? state.baseWidth ?? _params.width;
    final baseHeight = state.sourceHeight ?? state.baseHeight ?? _params.height;
    // max 档按原尺寸发请求，由服务端等比放到面积上限；模型不支持或原图太大时
    // 自动退回倍率档，避免 upscaled_enhance 发给不认识它的模型。
    final useMaxScale = state.enhance.maxScale && isMaxEnhanceAvailable;
    final factor = useMaxScale ? 1.0 : effectiveEnhanceFactor;
    final targetSize = EnhanceScales.resolveTargetSize(
      sourceWidth: baseWidth,
      sourceHeight: baseHeight,
      factor: factor,
    );
    final resolved = state.enhance.showIndividualSettings
        ? (strength: state.enhance.strength, noise: state.enhance.noise)
        : EnhanceLevels.resolve(state.enhance.level);

    _paramsNotifier.updateSize(
      targetSize.width,
      targetSize.height,
      persist: false,
    );
    _paramsNotifier.updateStrength(resolved.strength);
    _paramsNotifier.updateNoise(resolved.noise);
    _paramsNotifier.updateUpscaledEnhance(useMaxScale);
    _paramsNotifier.updateIsEnhanceRequest(true);
    _paramsNotifier.updateAction(ImageGenerationAction.img2img);
  }

  /// 当前源图尺寸下可用的放大倍率。
  List<double> get availableEnhanceFactors => EnhanceScales.availableFactors(
    sourceWidth: state.sourceWidth ?? state.baseWidth,
    sourceHeight: state.sourceHeight ?? state.baseHeight,
  );

  /// 持久化的倍率在当前源图不可用时回落到最大可用档。
  double get effectiveEnhanceFactor => EnhanceScales.resolveFactor(
    state.enhance.upscaleFactor,
    sourceWidth: state.sourceWidth ?? state.baseWidth,
    sourceHeight: state.sourceHeight ?? state.baseHeight,
  );

  void _applySourceSizeToParams() {
    final width = state.sourceWidth;
    final height = state.sourceHeight;
    if (width == null || height == null) {
      return;
    }

    _paramsNotifier.updateSize(width, height, persist: false);
  }

  void _syncInpaintRequestState() {
    if (state.mode != ImageWorkflowMode.inpaint) {
      return;
    }

    if (_params.maskImage != null) {
      _paramsNotifier.updateIsOutpaint(state.isOutpaint);
      _paramsNotifier.updateAction(ImageGenerationAction.infill);
      return;
    }

    _paramsNotifier.updateIsOutpaint(false);
    _paramsNotifier.updateAction(ImageGenerationAction.img2img);
  }

  bool _usesStableDiffusionImportBounds(String model) {
    final baseModel = ImageModels.resolveBaseModel(model);
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

    return NaiResolutionAdapter.readImageSize(imageBytes);
  }
}
