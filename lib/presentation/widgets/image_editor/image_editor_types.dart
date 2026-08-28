import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../core/services/anlas_calculator.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../data/services/efficient_vit_sam_service.dart';

enum ImageEditorMode { edit, inpaint }

/// Test-only fault injection and platform overrides for an editor session.
@immutable
class ImageEditorDebugOptions {
  const ImageEditorDebugOptions({
    this.initialOutpaintCommitPending = false,
    this.initialShowLayerPanel = true,
    this.failOutpaintSourceReplacement = false,
    this.failOutpaintAfterFocusedDisable = false,
    this.disableDropRegion = false,
    this.efficientVitSamSelector,
  });

  final bool initialOutpaintCommitPending;
  final bool initialShowLayerPanel;
  final bool failOutpaintSourceReplacement;
  final bool failOutpaintAfterFocusedDisable;
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
    this.mode = ImageEditorMode.edit,
    this.title = '',
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
      mode = ImageEditorMode.edit,
      title = '',
      debugOptions = const ImageEditorDebugOptions();

  final Uint8List? _initialImage;
  final Size? initialSize;
  final Uint8List? _existingMask;
  final Rect? existingFocusRect;
  final double initialMinimumContextMegaPixels;
  final bool initialFocusedInpaintEnabled;
  final ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig;
  final bool showMaskExport;
  final ImageEditorMode mode;
  final String title;
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
  final bool sourceWasNormalized;
  final int? outputWidth;
  final int? outputHeight;
  final bool compressionApplied;
}
