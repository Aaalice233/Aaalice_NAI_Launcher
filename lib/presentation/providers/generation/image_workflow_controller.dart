import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/comfyui/seedvr2_support.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/models/image/image_params.dart';
import 'generation_panel_expansion_provider.dart';
import 'generation_params_notifier.dart';
import 'image_workflow_geometry_helpers.dart';
import 'image_workflow_models.dart';
import 'image_workflow_params_sync_service.dart';
import 'image_workflow_persistence_service.dart';

export 'image_workflow_models.dart'
    show
        ComfyUpscaleModule,
        EnhanceWorkflowSettings,
        ImageWorkflowMode,
        ImageWorkflowState,
        UpscaleBackend,
        UpscaleWorkflowSettings;
export 'image_workflow_upscale_helpers.dart'
    show
        calculateComfySeedvr2TargetResolution,
        calculateComfySeedvr2TiledTargetResolution,
        comfyModelUpscaleTemplateId,
        comfyRtxUpscaleTemplateId,
        comfySeedvr2LegacyTiledUpscaleTemplateId,
        comfySeedvr2LegacyUpscaleTemplateId,
        comfySeedvr2NativeUpscaleTemplateId,
        defaultComfyUpscaleModelForModule,
        filterComfyUpscaleModelsForModule,
        isComfySeedvr2UpscaleModel,
        resolveComfyUpscaleModelForModule,
        resolveSeedvr2SwapIoComponents,
        seedvr2SwapIoComponentsThreshold,
        selectPreferredUpscaleModel,
        shouldAutoPersistResolvedUpscaleModel;

final imageWorkflowControllerProvider =
    NotifierProvider<ImageWorkflowController, ImageWorkflowState>(
      ImageWorkflowController.new,
    );

class ImageWorkflowController extends Notifier<ImageWorkflowState> {
  int _sourceImageRequestId = 0;
  bool _isDisposed = false;
  ImageWorkflowParamsSyncService? _paramsSyncService;

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
    final persistence = _persistence;
    final persistedUpscale = persistence.readUpscaleSettings();
    final persistedEnhance = persistence.readEnhanceSettings();

    return ImageWorkflowState(
      enhance: persistedEnhance,
      upscale: persistedUpscale,
      isPanelExpanded: persistedPanelExpanded,
    );
  }

  GenerationParamsNotifier get _paramsNotifier =>
      ref.read(generationParamsNotifierProvider.notifier);

  ImageParams get _params => ref.read(generationParamsNotifierProvider);

  ImageWorkflowPersistenceService get _persistence =>
      ImageWorkflowPersistenceService(ref.read(localStorageServiceProvider));

  ImageWorkflowParamsSyncService get _paramsSync =>
      _paramsSyncService ??= ImageWorkflowParamsSyncService(
        paramsNotifier: () => _paramsNotifier,
        readParams: () => _params,
      );

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
      importInfo = describeWorkflowSourceForImport(
        imageBytes,
        currentWidth: _params.width,
        currentHeight: _params.height,
        model: _params.model,
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
    final importInfo = await describeWorkflowSourceForImportAsync(
      imageBytes,
      currentWidth: params.width,
      currentHeight: params.height,
      model: params.model,
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

    final sizes = resolveWorkflowCommittedSizes(
      effectiveBytes,
      effectiveWidth: effectiveWidth,
      effectiveHeight: effectiveHeight,
      importInfo: importInfo,
    );
    state = state.copyWith(
      sourceWidth: sizes.requestSize?.$1,
      sourceHeight: sizes.requestSize?.$2,
      sourceImageWidth: sizes.sourceImageSize?.$1,
      sourceImageHeight: sizes.sourceImageSize?.$2,
      isOutpaint: false,
      resetFocusedInpaint: true,
    );

    switch (state.mode) {
      case ImageWorkflowMode.enhance:
        _ensureBaseSizeSnapshot();
        _applyEnhanceToParams();
        break;
      case ImageWorkflowMode.upscale:
        _ensureBaseSizeSnapshot();
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
          resetFocusedInpaint: true,
        );
        _paramsNotifier.updateAction(ImageGenerationAction.img2img);
        break;
      case ImageWorkflowMode.base:
        _ensureBaseSizeSnapshot();
        _applySourceSizeToParams();
        _paramsNotifier.updateAction(ImageGenerationAction.img2img);
        break;
    }
  }

  void clearSourceImage() {
    _paramsSync.clearSourceParams(state, restoreBaseParams: _restoreBaseParams);
    state = ImageWorkflowState(
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
    if (_params.sourceImage == null) return;

    if (state.mode == ImageWorkflowMode.enhance ||
        state.mode == ImageWorkflowMode.inpaint) {
      _restoreBaseParams();
    }

    _ensureBaseSizeSnapshot();
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
    if (state.mode != ImageWorkflowMode.upscale) return;
    enterBaseMode(clearMask: false);
  }

  void _updateUpscaleSettings(UpscaleWorkflowSettings nextSettings) {
    state = state.copyWith(upscale: nextSettings);
    _persistence.persistUpscaleSettings(nextSettings);
  }

  void updateUpscaleComfyScale(double scale) =>
      _updateUpscaleSettings(state.upscale.withComfyScale(scale));

  void updateUpscaleComfyModel(
    String model, {
    ComfySeedvr2Backend? seedvr2Backend,
  }) => _updateUpscaleSettings(
    state.upscale.copyWithComfyModelForModule(
      state.upscale.comfyModule,
      model,
      seedvr2Backend: seedvr2Backend,
    ),
  );

  void updateComfyUpscaleModule(ComfyUpscaleModule module) =>
      _updateUpscaleSettings(state.upscale.withComfyModule(module));

  void updateUpscaleBackend(UpscaleBackend backend) =>
      _updateUpscaleSettings(state.upscale.copyWith(backend: backend));

  void updateSeedvr2Engine(ComfySeedvr2Engine engine) =>
      _updateUpscaleSettings(state.upscale.withSeedvr2Engine(engine));

  void updateSeedvr2VaeTileSize(double value) =>
      _updateUpscaleSettings(state.upscale.withSeedvr2VaeTileSize(value));

  void updateSeedvr2Tiled(bool value) =>
      _updateUpscaleSettings(state.upscale.copyWith(seedvr2Tiled: value));

  void updateSeedvr2EmbedNaiMetadata(bool value) => _updateUpscaleSettings(
    state.upscale.copyWith(seedvr2EmbedNaiMetadata: value),
  );

  void updateSeedvr2TileSize(double value) =>
      _updateUpscaleSettings(state.upscale.withSeedvr2TileSize(value));

  void updateSeedvr2BlocksToSwap(double value) =>
      _updateUpscaleSettings(state.upscale.withSeedvr2BlocksToSwap(value));

  void setFocusedInpaintEnabled(bool value) {
    state = state.copyWith(
      focusedInpaintEnabled: value,
      clearFocusedSelectionRect: !value,
      clearFocusedContextCrop: !value,
    );
  }

  void setMinimumContextMegaPixels(double value) {
    final context = value.clamp(16.0, 192.0);
    final constrainedSelection = constrainWorkflowFocusedSelection(
      state.focusedSelectionRect,
      state: state,
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
    final constrainedSelection = constrainWorkflowFocusedSelection(
      rect,
      state: state,
      minimumContextMegaPixels: state.minimumContextMegaPixels,
    );
    state = state.copyWith(
      focusedSelectionRect: constrainedSelection,
      clearFocusedSelectionRect: constrainedSelection == null,
      clearFocusedContextCrop: true,
    );
  }

  /// [focusedContextCrop] 为聚焦外扩的取景框（[sourceImage] 像素坐标），给定时忽略选区
  void applyInpaintEditorResult({
    Uint8List? sourceImage,
    int? sourceWidth,
    int? sourceHeight,
    required Uint8List? maskImage,
    required bool focusedInpaintEnabled,
    required Rect? focusedSelectionRect,
    required double minimumContextMegaPixels,
    Rect? focusedContextCrop,
    bool forceDisableFocusedInpaint = false,
    bool sourceIsOutpaint = true,
    ({int width, int height})? requestSize,
  }) {
    final hasReplacementSource = sourceImage != null;
    validateInpaintEditorSourceDimensions(
      hasReplacementSource: hasReplacementSource,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      sourceIsOutpaint: sourceIsOutpaint,
    );

    if (_params.sourceImage == null && !hasReplacementSource) return;

    if (state.mode == ImageWorkflowMode.enhance ||
        state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    NaiImportImageInfo? importInfo;
    if (hasReplacementSource) {
      _paramsNotifier.setSourceImage(sourceImage);
      if (requestSize == null) {
        importInfo = describeWorkflowSourceForImport(
          sourceImage,
          currentWidth: _params.width,
          currentHeight: _params.height,
          model: _params.model,
        );
      }
    }

    final exactRequestSize = hasReplacementSource && importInfo == null
        ? requestSize ??
              clampWorkflowSizeToRequestLimits(sourceWidth!, sourceHeight!)
        : null;

    _ensureBaseSizeSnapshot();

    state = resolveInpaintEditorWorkflowState(
      currentState: state,
      hasReplacementSource: hasReplacementSource,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      importInfo: importInfo,
      exactRequestSize: exactRequestSize,
      focusedInpaintEnabled: focusedInpaintEnabled,
      focusedSelectionRect: focusedSelectionRect,
      minimumContextMegaPixels: minimumContextMegaPixels,
      focusedContextCrop: focusedContextCrop,
      forceDisableFocusedInpaint: forceDisableFocusedInpaint,
      sourceIsOutpaint: sourceIsOutpaint,
    );
    setPanelExpanded(true);

    _applySourceSizeToParams();
    _paramsNotifier.setMaskImage(maskImage);
    _syncInpaintRequestState();
  }

  void enterEnhanceMode() {
    if (_params.sourceImage == null) return;

    if (state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    _ensureBaseSizeSnapshot();
    _captureEnhanceEntryParams();
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
    if (state.mode != ImageWorkflowMode.enhance) return;
    enterBaseMode(clearMask: false);
  }

  void enterInpaintMode() {
    if (_params.sourceImage == null) return;

    if (state.mode == ImageWorkflowMode.enhance ||
        state.mode == ImageWorkflowMode.upscale) {
      _restoreBaseParams();
    }

    _ensureBaseSizeSnapshot();
    state = state.copyWith(
      mode: ImageWorkflowMode.inpaint,
      isPanelExpanded: true,
      isOutpaint: false,
    );
    setPanelExpanded(true);

    _applySourceSizeToParams();
    _syncInpaintRequestState();
  }

  /// 离开任一模式回到 base 的唯一实现：退出增强/超分都委托到这里，避免两条路径给出不同尺寸。
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
      resetFocusedInpaint: clearMask,
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

  void _updateEnhanceSettings(
    EnhanceWorkflowSettings nextSettings, {
    bool applyToParams = true,
  }) {
    state = state.copyWith(enhance: nextSettings);
    _persistence.persistEnhanceSettings(nextSettings);
    if (applyToParams) {
      _applyEnhanceToParams();
    }
  }

  void updateEnhanceLevel(int level) => _updateEnhanceSettings(
    state.enhance.withLevel(level),
    applyToParams: !state.enhance.showIndividualSettings,
  );

  void toggleEnhanceIndividualSettings(bool value) =>
      _updateEnhanceSettings(state.enhance.withShowIndividualSettings(value));

  void updateEnhanceUpscaleFactor(double factor) => _updateEnhanceSettings(
    state.enhance.withUpscaleFactor(
      factor,
      sourceWidth: state.effectiveEnhanceSourceWidth,
      sourceHeight: state.effectiveEnhanceSourceHeight,
    ),
  );

  /// 切到 max 档：不按倍率放大，服务端把结果放到 3.14MP 上限。
  void selectEnhanceMaxScale() {
    if (!isMaxEnhanceAvailable) return;
    _updateEnhanceSettings(state.enhance.copyWith(maxScale: true));
  }

  /// max 档在当前模型与源图尺寸下是否可用。
  bool get isMaxEnhanceAvailable =>
      state.allowsMaxEnhance(_params.capabilities);

  void updateEnhanceIndividualSettings({double? strength, double? noise}) =>
      _updateEnhanceSettings(
        state.enhance.withIndividualValues(strength: strength, noise: noise),
      );

  /// 尺寸在载入源图时就被源图尺寸覆盖，因此各模式共用一份、清空源图时还原。
  void _ensureBaseSizeSnapshot() {
    if (state.baseWidth != null && state.baseHeight != null) return;
    state = state.copyWith(
      baseWidth: _params.width,
      baseHeight: _params.height,
    );
  }

  void _captureEnhanceEntryParams() {
    state = state.copyWith(
      enhanceEntryStrength: _params.strength,
      enhanceEntryNoise: _params.noise,
    );
  }

  void _restoreBaseParams() {
    if (_paramsSync.restoreBaseParams(state)) {
      state = state.copyWith(clearEnhanceEntryParams: true);
    }
  }

  void _applyEnhanceToParams() => _paramsSync.applyEnhanceToParams(state);

  /// 当前源图尺寸下可用的放大倍率。
  List<double> get availableEnhanceFactors => state.availableEnhanceFactors;

  /// 持久化的倍率在当前源图不可用时回落到最大可用档。
  double get effectiveEnhanceFactor => state.effectiveEnhanceFactor;

  void _applySourceSizeToParams() => _paramsSync.applySourceSizeToParams(state);

  void _syncInpaintRequestState() => _paramsSync.syncInpaintRequestState(state);
}
