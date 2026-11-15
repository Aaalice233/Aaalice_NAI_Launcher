import 'dart:ui';

import '../../../core/comfyui/seedvr2_support.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/model_capabilities.dart';
import 'generation_request_preparation_service.dart';

enum ImageWorkflowMode { base, inpaint, enhance, upscale }

enum UpscaleBackend { comfyui, novelai }

enum ComfyUpscaleModule { regular, seedvr2, rtx }

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

  UpscaleWorkflowSettings withComfyScale(double scale) =>
      copyWith(comfyScale: scale.clamp(minScale, maxScale));

  UpscaleWorkflowSettings withComfyModule(ComfyUpscaleModule module) =>
      copyWith(comfyModule: module, comfyModel: comfyModelForModule(module));

  UpscaleWorkflowSettings withSeedvr2Engine(ComfySeedvr2Engine engine) {
    final backend = engine == ComfySeedvr2Engine.legacy
        ? ComfySeedvr2Backend.legacy
        : ComfySeedvr2Backend.native;
    return copyWith(
      seedvr2Engine: engine,
      comfyModel: comfySeedvr2ModelForBackend(backend),
    );
  }

  UpscaleWorkflowSettings withSeedvr2VaeTileSize(double value) => copyWith(
    seedvr2VaeTileSize: value
        .round()
        .clamp(minSeedvr2VaeTileSize, maxSeedvr2VaeTileSize)
        .toInt(),
  );

  UpscaleWorkflowSettings withSeedvr2TileSize(double value) => copyWith(
    seedvr2TileSize: value
        .round()
        .clamp(minSeedvr2TileSize, maxSeedvr2TileSize)
        .toInt(),
  );

  UpscaleWorkflowSettings withSeedvr2BlocksToSwap(double value) => copyWith(
    seedvr2BlocksToSwap: value
        .round()
        .clamp(minSeedvr2BlocksToSwap, maxSeedvr2BlocksToSwap)
        .toInt(),
  );
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

  EnhanceWorkflowSettings withLevel(int nextLevel) {
    final clamped = nextLevel.clamp(
      EnhanceLevels.minLevel,
      EnhanceLevels.maxLevel,
    );
    final resolved = EnhanceLevels.resolve(clamped);
    return copyWith(
      level: clamped,
      strength: showIndividualSettings ? strength : resolved.strength,
      noise: showIndividualSettings ? noise : resolved.noise,
    );
  }

  EnhanceWorkflowSettings withShowIndividualSettings(bool value) {
    final resolved = EnhanceLevels.resolve(level);
    return copyWith(
      showIndividualSettings: value,
      strength: value ? strength : resolved.strength,
      noise: value ? noise : resolved.noise,
    );
  }

  EnhanceWorkflowSettings withUpscaleFactor(
    double factor, {
    required int? sourceWidth,
    required int? sourceHeight,
  }) {
    return copyWith(
      upscaleFactor: EnhanceScales.resolveFactor(
        factor,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      ),
      maxScale: false,
    );
  }

  EnhanceWorkflowSettings withIndividualValues({
    double? strength,
    double? noise,
  }) {
    return copyWith(
      showIndividualSettings: true,
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
    this.enhanceEntryStrength,
    this.enhanceEntryNoise,
    this.enhance = const EnhanceWorkflowSettings(),
    this.upscale = const UpscaleWorkflowSettings(),
    this.isPanelExpanded = false,
    this.isOutpaint = false,
    this.focusedInpaintEnabled = false,
    this.minimumContextMegaPixels = 88.0,
    this.focusedSelectionRect,
    this.focusedContextCrop,
  });

  final ImageWorkflowMode mode;
  final int? sourceWidth;
  final int? sourceHeight;
  final int? sourceImageWidth;
  final int? sourceImageHeight;
  final int? baseWidth;
  final int? baseHeight;

  // 只在进入增强时拍照：增强是唯一覆盖 strength/noise 的模式，提前拍会回写用户之后改的值
  final double? enhanceEntryStrength;
  final double? enhanceEntryNoise;
  final EnhanceWorkflowSettings enhance;
  final UpscaleWorkflowSettings upscale;
  final bool isPanelExpanded;
  final bool isOutpaint;
  final bool focusedInpaintEnabled;
  final double minimumContextMegaPixels;
  final Rect? focusedSelectionRect;

  /// 聚焦外扩的取景框（源图像素坐标）：只送这块去生成，结果贴回整张源图；与选区互斥
  final Rect? focusedContextCrop;

  bool get isEnhance => mode == ImageWorkflowMode.enhance;
  bool get isInpaint => mode == ImageWorkflowMode.inpaint;
  bool get isUpscale => mode == ImageWorkflowMode.upscale;

  GenerationFocusedSnapshot get focusedSnapshot => GenerationFocusedSnapshot(
    enabled: focusedInpaintEnabled,
    minimumContextMegaPixels: minimumContextMegaPixels,
    selectionRect: focusedSelectionRect,
    contextCrop: focusedContextCrop,
  );

  /// 聚焦重绘既没有选区也没有取景框，聚焦区域取蒙版外接矩形。
  bool get focusesOnMaskExtent =>
      focusedInpaintEnabled &&
      focusedSelectionRect == null &&
      focusedContextCrop == null;

  int? get effectiveEnhanceSourceWidth => sourceWidth ?? baseWidth;
  int? get effectiveEnhanceSourceHeight => sourceHeight ?? baseHeight;

  bool allowsMaxEnhance(ModelCapabilities capabilities) =>
      E2eUpscale.allowsMaxEnhance(
        capabilities,
        sourceWidth: effectiveEnhanceSourceWidth,
        sourceHeight: effectiveEnhanceSourceHeight,
      );

  List<double> get availableEnhanceFactors => EnhanceScales.availableFactors(
    sourceWidth: effectiveEnhanceSourceWidth,
    sourceHeight: effectiveEnhanceSourceHeight,
  );

  double get effectiveEnhanceFactor => EnhanceScales.resolveFactor(
    enhance.upscaleFactor,
    sourceWidth: effectiveEnhanceSourceWidth,
    sourceHeight: effectiveEnhanceSourceHeight,
  );

  ImageWorkflowState copyWith({
    ImageWorkflowMode? mode,
    int? sourceWidth,
    int? sourceHeight,
    int? sourceImageWidth,
    int? sourceImageHeight,
    int? baseWidth,
    int? baseHeight,
    double? enhanceEntryStrength,
    double? enhanceEntryNoise,
    EnhanceWorkflowSettings? enhance,
    UpscaleWorkflowSettings? upscale,
    bool? isPanelExpanded,
    bool? isOutpaint,
    bool? focusedInpaintEnabled,
    double? minimumContextMegaPixels,
    Rect? focusedSelectionRect,
    Rect? focusedContextCrop,
    bool clearSourceSize = false,
    bool clearBaseSnapshot = false,
    bool clearEnhanceEntryParams = false,
    bool clearFocusedSelectionRect = false,
    bool clearFocusedContextCrop = false,
    // 聚焦重绘归属于当前这张源图：换图或退出重绘时开关和选区必须一起归零，
    // 只清选区会让下一次进重绘仍带着上一张图的聚焦状态。
    bool resetFocusedInpaint = false,
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
      enhanceEntryStrength: clearBaseSnapshot || clearEnhanceEntryParams
          ? null
          : (enhanceEntryStrength ?? this.enhanceEntryStrength),
      enhanceEntryNoise: clearBaseSnapshot || clearEnhanceEntryParams
          ? null
          : (enhanceEntryNoise ?? this.enhanceEntryNoise),
      enhance: enhance ?? this.enhance,
      upscale: upscale ?? this.upscale,
      isPanelExpanded: isPanelExpanded ?? this.isPanelExpanded,
      isOutpaint: isOutpaint ?? this.isOutpaint,
      focusedInpaintEnabled: resetFocusedInpaint
          ? false
          : (focusedInpaintEnabled ?? this.focusedInpaintEnabled),
      minimumContextMegaPixels:
          minimumContextMegaPixels ?? this.minimumContextMegaPixels,
      focusedSelectionRect: clearFocusedSelectionRect || resetFocusedInpaint
          ? null
          : (focusedSelectionRect ?? this.focusedSelectionRect),
      focusedContextCrop: clearFocusedContextCrop || resetFocusedInpaint
          ? null
          : (focusedContextCrop ?? this.focusedContextCrop),
    );
  }
}
