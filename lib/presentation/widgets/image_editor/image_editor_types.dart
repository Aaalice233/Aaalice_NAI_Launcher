import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/anlas_calculator.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/services/efficient_vit_sam_service.dart';

enum ImageEditorMode { edit, inpaint }

/// Test-only fault injection and platform overrides for an editor session.
@immutable
class ImageEditorDebugOptions {
  const ImageEditorDebugOptions({
    this.initialOutpaintCommitPending = false,
    this.initialShowLayerPanel = true,
    this.disableDropRegion = false,
    this.efficientVitSamSelector,
  });

  final bool initialOutpaintCommitPending;
  final bool initialShowLayerPanel;
  final bool disableDropRegion;
  final EfficientVitSamSelector? efficientVitSamSelector;
}

/// Immutable inputs for one editor session.
///
/// The legacy [ImageEditorScreen] constructor creates this object so feature
/// controllers receive one stable value instead of reading widget fields.
@immutable
class ImageEditorSessionConfig {
  ImageEditorSessionConfig({
    Uint8List? initialImage,
    this.initialSize,
    Uint8List? existingMask,
    this.existingFocusRect,
    this.initialMinimumContextMegaPixels = 88.0,
    this.initialFocusedInpaintEnabled = false,
    this.focusedInpaintCostConfig,
    this.showMaskExport = true,
    this.supportsFocusOutpaint = false,
    this.existingFrameRect,
    this.mode = ImageEditorMode.edit,
    this.title = '',
    this.completionLabel,
    this.debugOptions = const ImageEditorDebugOptions(),
  }) : _initialImage = initialImage == null
           ? null
           : Uint8List.fromList(initialImage),
       _existingMask = existingMask == null
           ? null
           : Uint8List.fromList(existingMask);

  const ImageEditorSessionConfig.empty()
    : _initialImage = null,
      initialSize = null,
      _existingMask = null,
      existingFocusRect = null,
      initialMinimumContextMegaPixels = 88.0,
      initialFocusedInpaintEnabled = false,
      focusedInpaintCostConfig = null,
      showMaskExport = true,
      supportsFocusOutpaint = false,
      existingFrameRect = null,
      mode = ImageEditorMode.edit,
      title = '',
      completionLabel = null,
      debugOptions = const ImageEditorDebugOptions();

  final Uint8List? _initialImage;
  final Size? initialSize;
  final Uint8List? _existingMask;
  final Rect? existingFocusRect;
  final double initialMinimumContextMegaPixels;
  final bool initialFocusedInpaintEnabled;
  final ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig;
  final bool showMaskExport;

  /// 调用方能处理 [ImageEditorResult.focusOutpaint]：不裁切时交出整张画布并只送取景框
  final bool supportsFocusOutpaint;

  /// 上次聚焦外扩的取景框（[initialImage] 像素坐标），重新打开时恢复
  final Rect? existingFrameRect;
  final ImageEditorMode mode;
  final String title;
  final String? completionLabel;
  final ImageEditorDebugOptions debugOptions;

  Uint8List? get initialImage =>
      _initialImage == null ? null : Uint8List.fromList(_initialImage);
  Uint8List? get existingMask =>
      _existingMask == null ? null : Uint8List.fromList(_existingMask);
}

class ImageEditorFocusedInpaintCostConfig {
  const ImageEditorFocusedInpaintCostConfig({
    required this.model,
    required this.steps,
    required this.batchCount,
    required this.batchSize,
    required this.smea,
    required this.smeaDyn,
    required this.subscriptionTier,
    this.opusQuotaExhausted = false,
    this.strength = 1.0,
    this.extraPerSampleCost = 0,
    this.currentWidth,
    this.currentHeight,
  });

  final String model;
  final int steps;
  final int batchCount;
  final int batchSize;
  final bool smea;
  final bool smeaDyn;
  final int subscriptionTier;
  final bool opusQuotaExhausted;
  final double strength;
  final int extraPerSampleCost;

  /// 生成页当前的请求尺寸；未压缩的源图交回后按它决定实际请求尺寸
  final int? currentWidth;
  final int? currentHeight;

  /// 与生成页导入源图时的尺寸推导一致
  ({int width, int height}) resolveImportRequestSize({
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final resolved = NaiResolutionAdapter.findImportResolution(
      sourceWidth,
      sourceHeight,
      currentWidth: currentWidth,
      currentHeight: currentHeight,
      isStableDiffusionFamily: ImageModels.usesStableDiffusionImportBounds(
        model,
      ),
    );
    return (width: resolved.width, height: resolved.height);
  }

  int estimate({required int width, required int height}) {
    return AnlasCalculator.calculateRequestCost(
      width: width,
      height: height,
      steps: steps,
      batchCount: batchCount,
      batchSize: batchSize,
      smea: smea,
      smeaDyn: smeaDyn,
      model: model,
      subscriptionTier: subscriptionTier,
      opusQuotaExhausted: opusQuotaExhausted,
      strength: strength,
      extraPerSampleCost: extraPerSampleCost,
    );
  }
}

class FocusedInpaintCostEstimate {
  const FocusedInpaintCostEstimate({
    required this.geometry,
    required this.cost,
  });

  final FocusedInpaintGeometry geometry;
  final int cost;
}

/// 聚焦外扩交回的整张画布：[crop] 是取景框在画布中的位置，生成时只送这块再贴回
@immutable
class FocusOutpaintResult {
  const FocusOutpaintResult({
    required this.sourceImage,
    required this.width,
    required this.height,
    required this.crop,
  });

  final Uint8List sourceImage;
  final int width;
  final int height;
  final Rect crop;
}

class ImageEditorResult {
  const ImageEditorResult({
    this.modifiedImage,
    this.maskImage,
    this.hasImageChanges = false,
    this.hasMaskChanges = false,
    this.focusAreaRect,
    this.minimumContextMegaPixels = 88.0,
    this.focusedInpaintEnabled = false,
    this.outpaintSourceImage,
    this.outpaintSourceWidth,
    this.outpaintSourceHeight,
    this.hasOutpaintChanges = false,
    this.inpaintSourceImage,
    this.inpaintSourceWidth,
    this.inpaintSourceHeight,
    this.focusOutpaint,
    this.sourceWasNormalized = false,
    this.outputWidth,
    this.outputHeight,
    this.compressionApplied = false,
  });

  final Uint8List? modifiedImage;
  final Uint8List? maskImage;
  final bool hasImageChanges;
  final bool hasMaskChanges;
  final Rect? focusAreaRect;
  final double minimumContextMegaPixels;
  final bool focusedInpaintEnabled;
  final Uint8List? outpaintSourceImage;
  final int? outpaintSourceWidth;
  final int? outpaintSourceHeight;
  final bool hasOutpaintChanges;
  final Uint8List? inpaintSourceImage;
  final int? inpaintSourceWidth;
  final int? inpaintSourceHeight;

  /// 非空时 [maskImage] 与它同尺寸，且只含取景框内的部分
  final FocusOutpaintResult? focusOutpaint;
  final bool sourceWasNormalized;
  final int? outputWidth;
  final int? outputHeight;
  final bool compressionApplied;
}
