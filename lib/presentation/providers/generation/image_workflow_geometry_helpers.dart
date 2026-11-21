import 'dart:typed_data';
import 'dart:ui';

import '../../../core/constants/api_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import 'image_workflow_models.dart';

NaiImportImageInfo? describeWorkflowSourceForImport(
  Uint8List imageBytes, {
  required int currentWidth,
  required int currentHeight,
  required String model,
}) {
  return NaiResolutionAdapter.describeImageForImport(
    imageBytes,
    currentWidth: currentWidth,
    currentHeight: currentHeight,
    isStableDiffusionFamily: ImageModels.usesStableDiffusionImportBounds(model),
  );
}

Future<NaiImportImageInfo?> describeWorkflowSourceForImportAsync(
  Uint8List imageBytes, {
  required int currentWidth,
  required int currentHeight,
  required String model,
}) {
  return NaiResolutionAdapter.describeImageForImportAsync(
    imageBytes,
    currentWidth: currentWidth,
    currentHeight: currentHeight,
    isStableDiffusionFamily: ImageModels.usesStableDiffusionImportBounds(model),
  );
}

(int, int)? resolveWorkflowImageSize(
  Uint8List imageBytes, {
  int? width,
  int? height,
}) {
  if (width != null && height != null) {
    return (width, height);
  }

  return NaiResolutionAdapter.readImageSize(imageBytes);
}

({(int, int)? requestSize, (int, int)? sourceImageSize})
resolveWorkflowCommittedSizes(
  Uint8List effectiveBytes, {
  int? effectiveWidth,
  int? effectiveHeight,
  NaiImportImageInfo? importInfo,
}) {
  final requestSize = resolveWorkflowImageSize(
    effectiveBytes,
    width: effectiveWidth,
    height: effectiveHeight,
  );
  final sourceImageSize = importInfo == null
      ? resolveWorkflowImageSize(effectiveBytes)
      : (importInfo.originalWidth, importInfo.originalHeight);
  return (requestSize: requestSize, sourceImageSize: sourceImageSize);
}

Rect? constrainWorkflowFocusedSelection(
  Rect? rect, {
  required ImageWorkflowState state,
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

({int width, int height}) clampWorkflowSizeToRequestLimits(
  int width,
  int height,
) {
  if (NaiResolutionAdapter.isGenerationCompatible(width, height)) {
    return (width: width, height: height);
  }
  final closest = NaiResolutionAdapter.findClosestResolution(width, height);
  AppLogger.i(
    'Editor source clamped to request limits: '
        '${width}x$height -> ${closest.width}x${closest.height}',
    'ImageWorkflow',
  );
  return (width: closest.width, height: closest.height);
}

void validateInpaintEditorSourceDimensions({
  required bool hasReplacementSource,
  required int? sourceWidth,
  required int? sourceHeight,
  required bool sourceIsOutpaint,
}) {
  if (!hasReplacementSource) return;
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

ImageWorkflowState resolveInpaintEditorWorkflowState({
  required ImageWorkflowState currentState,
  required bool hasReplacementSource,
  required int? sourceWidth,
  required int? sourceHeight,
  required NaiImportImageInfo? importInfo,
  required ({int width, int height})? exactRequestSize,
  required bool focusedInpaintEnabled,
  required Rect? focusedSelectionRect,
  required double minimumContextMegaPixels,
  required Rect? focusedContextCrop,
  required bool forceDisableFocusedInpaint,
  required bool sourceIsOutpaint,
}) {
  final actualSourceWidth = hasReplacementSource
      ? (importInfo?.originalWidth ?? sourceWidth)
      : (currentState.sourceImageWidth ?? currentState.sourceWidth);
  final actualSourceHeight = hasReplacementSource
      ? (importInfo?.originalHeight ?? sourceHeight)
      : (currentState.sourceImageHeight ?? currentState.sourceHeight);
  // 保留固定取景框到请求校验，丢弃越界框会把聚焦外扩变成整图重绘。
  final contextCrop = forceDisableFocusedInpaint ? null : focusedContextCrop;
  final constrainedSelection = switch ((
    forceDisableFocusedInpaint || contextCrop != null,
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
      (constrainedSelection != null || contextCrop != null);
  return currentState.copyWith(
    mode: ImageWorkflowMode.inpaint,
    sourceWidth: hasReplacementSource
        ? (importInfo?.width ?? exactRequestSize?.width ?? sourceWidth)
        : null,
    sourceHeight: hasReplacementSource
        ? (importInfo?.height ?? exactRequestSize?.height ?? sourceHeight)
        : null,
    sourceImageWidth: hasReplacementSource ? actualSourceWidth : null,
    sourceImageHeight: hasReplacementSource ? actualSourceHeight : null,
    isPanelExpanded: true,
    isOutpaint: hasReplacementSource && sourceIsOutpaint,
    focusedInpaintEnabled: effectiveFocusedInpaintEnabled,
    minimumContextMegaPixels: minimumContextMegaPixels.clamp(16.0, 192.0),
    focusedSelectionRect: constrainedSelection,
    clearFocusedSelectionRect:
        !effectiveFocusedInpaintEnabled || constrainedSelection == null,
    focusedContextCrop: effectiveFocusedInpaintEnabled ? contextCrop : null,
    clearFocusedContextCrop:
        !effectiveFocusedInpaintEnabled || contextCrop == null,
  );
}
