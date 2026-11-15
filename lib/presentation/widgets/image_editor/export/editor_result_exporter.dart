import 'dart:typed_data';
import 'dart:ui';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../controllers/editor_compression_controller.dart';
import '../core/editor_state.dart';
import '../frame/editor_frame_controller.dart';
import '../frame/focus_outpaint_export.dart';
import '../frame/frame_geometry.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../layers/image_layer_source.dart';
import 'image_exporter_new.dart';

/// 负责把当前画布、蒙版、取景框与压缩档位编码为会话导出的 [ImageEditorResult]。
class EditorResultExporter {
  const EditorResultExporter({
    required ImageEditorController Function() session,
    required ImageEditorSessionConfig Function() config,
    required this.frameController,
    required this.imageSource,
    required this.compressionController,
  }) : _session = session,
       _config = config;

  final ImageEditorController Function() _session;
  final ImageEditorSessionConfig Function() _config;
  final EditorFrameController frameController;
  final ImageLayerSource imageSource;
  final EditorCompressionController compressionController;

  ImageEditorController get session => _session();

  EditorState get editorState => session.editorState;

  ImageEditorSessionConfig get config => _config();

  bool get _isInpaintMode => config.mode == ImageEditorMode.inpaint;

  Future<ImageEditorResult> exportResult() {
    final pasteBackCanvas = _isInpaintMode
        ? frameController.pasteBackCanvas
        : null;
    return pasteBackCanvas == null
        ? buildEditorResult()
        : buildFocusOutpaintResult();
  }

  /// 只统计与取景框相交的蒙版；完全落在框外的内容不会送出
  bool hasMaskContent() {
    final frame = editorState.frame;
    for (final layer in editorState.layerManager.maskLayers) {
      if (!layer.visible) {
        continue;
      }
      if (layer.hasContent && layer.contentBounds.overlaps(frame)) {
        return true;
      }
    }
    return false;
  }

  Future<ImageEditorResult> buildEditorResult() async {
    final target = compressionController.activeTarget;
    final compressionApplied = compressionController.compressionApplied;
    final hasCanvasImageChanges =
        editorState.historyManager.canUndo ||
        editorState.layerManager.layers.any((l) => l.strokes.isNotEmpty) ||
        editorState.layerManager.layerCount > 1;
    final hasImageChanges =
        hasCanvasImageChanges || (!_isInpaintMode && compressionApplied);

    final virtualOutpaintMaskRects = frameController.outpaintMaskRects;
    final hasMaskChanges =
        hasMaskContent() || virtualOutpaintMaskRects.isNotEmpty;
    final workFocusAreaRect = session.focusedInpaintEnabled
        ? session.focusedSelectionState.committedRect
        : null;
    final focusedInpaintEnabled =
        session.focusedInpaintEnabled && workFocusAreaRect != null;
    final focusAreaRect = focusedInpaintEnabled
        ? compressionController.projectWorkRectToTarget(workFocusAreaRect)
        : null;
    final useFocusedSelectionAsMask = focusedInpaintEnabled && !hasMaskChanges;
    AppLogger.d(
      'Export editor result: inpaint=$_isInpaintMode, '
          'hasImageChanges=$hasImageChanges, hasMaskChanges=$hasMaskChanges, '
          'selection=${editorState.selectionPath != null}, '
          'workFocusRect=$workFocusAreaRect, focusRect=$focusAreaRect, '
          'focusedEnabled=$focusedInpaintEnabled, '
          'useFocusedSelectionAsMask=$useFocusedSelectionAsMask, '
          'work=${editorState.canvasSize.width.round()}x${editorState.canvasSize.height.round()}, '
          'target=${target.width}x${target.height}, '
          'compressionApplied=$compressionApplied, '
          'layers=${editorState.layerManager.layerCount}',
      'ImageEditor',
    );

    Uint8List? modifiedImage;
    if (!_isInpaintMode && hasImageChanges) {
      modifiedImage = await _exportMergedImageAtCompressionTarget();
    }
    final hasSourceImageChanges = _isInpaintMode && imageSource.hasChanges;

    final maskImage = await _exportResultMask(
      hasMaskChanges: hasMaskChanges,
      virtualOutpaintMaskRects: virtualOutpaintMaskRects,
      focusedSelection: useFocusedSelectionAsMask ? workFocusAreaRect : null,
    );

    final inpaintSource = _isInpaintMode
        ? await _prepareInpaintSourceAtCompressionTarget()
        : null;
    final hasOutpaintChanges = frameController.hasOutpaintChanges;

    return ImageEditorResult(
      modifiedImage: modifiedImage,
      maskImage: maskImage,
      hasImageChanges: !_isInpaintMode && hasImageChanges,
      hasSourceImageChanges: hasSourceImageChanges,
      hasMaskChanges:
          _isInpaintMode && (hasMaskChanges || useFocusedSelectionAsMask),
      focusAreaRect: focusAreaRect,
      minimumContextMegaPixels: session.minimumContextMegaPixels,
      focusedInpaintEnabled: focusedInpaintEnabled,
      outpaintSourceImage: _isInpaintMode && hasOutpaintChanges
          ? inpaintSource
          : null,
      outpaintSourceWidth: _isInpaintMode && hasOutpaintChanges
          ? target.width
          : null,
      outpaintSourceHeight: _isInpaintMode && hasOutpaintChanges
          ? target.height
          : null,
      hasOutpaintChanges: _isInpaintMode && hasOutpaintChanges,
      inpaintSourceImage: _isInpaintMode && !hasOutpaintChanges
          ? inpaintSource
          : null,
      inpaintSourceWidth: _isInpaintMode && !hasOutpaintChanges
          ? target.width
          : null,
      inpaintSourceHeight: _isInpaintMode && !hasOutpaintChanges
          ? target.height
          : null,
      sourceWasNormalized:
          _isInpaintMode &&
          !hasOutpaintChanges &&
          (session.sourceWasNormalized || compressionApplied),
      outputWidth: target.width,
      outputHeight: target.height,
      compressionApplied: compressionApplied,
    );
  }

  /// 有蒙版内容时导出图层蒙版，否则用聚焦选区充当蒙版
  Future<Uint8List?> _exportResultMask({
    required bool hasMaskChanges,
    required List<Rect> virtualOutpaintMaskRects,
    required Rect? focusedSelection,
  }) async {
    if (!_isInpaintMode || !config.showMaskExport) return null;
    if (hasMaskChanges) {
      final mask = await _exportInpaintLayerMaskAtCompressionTarget(
        virtualOutpaintMaskRects,
      );
      AppLogger.d('Exported inpaint mask bytes: ${mask.length}', 'ImageEditor');
      return mask;
    }
    if (focusedSelection == null) return null;
    final mask = await _exportFocusedSelectionMaskAtCompressionTarget(
      focusedSelection,
    );
    AppLogger.d(
      'Exported focused selection mask bytes: ${mask.length}',
      'ImageEditor',
    );
    return mask;
  }

  /// 不裁切时交出整张画布：生成页只送取景框，结果按蒙版贴回
  Future<ImageEditorResult> buildFocusOutpaintResult() async {
    final target = compressionController.activeTarget;
    final compressionApplied = compressionController.compressionApplied;
    final canvas = frameController.pasteBackCanvas;
    if (canvas == null) {
      throw StateError('Unable to read current source image.');
    }
    final source = await _resolveSourceImage(canvas);
    final frameMask = await ImageExporterNew.exportMaskRasterFromLayers(
      editorState.layerManager.maskLayers,
      editorState.frame,
      additionalMaskRects: frameController.outpaintMaskRects,
    );
    final export = await FocusOutpaintExporter(session.processingService)
        .export(
          sourceImage: source.bytes,
          sourceRect: source.rect,
          frame: editorState.frame,
          frameMask: frameMask,
          target: target,
        );
    final maskImage = export.maskImage;
    AppLogger.d(
      'Export focus outpaint: source=${source.rect}, frame=${editorState.frame}, '
          'canvas=${export.width}x${export.height}, crop=${export.crop}, '
          'masked=${maskImage != null}, compressionApplied=$compressionApplied',
      'ImageEditor',
    );
    final sourceWasNormalized =
        session.sourceWasNormalized || compressionApplied;
    if (maskImage == null) {
      // 框内没有要生成的像素说明框落在原图内，整张画布就是原图
      return ImageEditorResult(
        minimumContextMegaPixels: session.minimumContextMegaPixels,
        hasSourceImageChanges: imageSource.hasChanges,
        inpaintSourceImage: export.sourceImage,
        inpaintSourceWidth: export.width,
        inpaintSourceHeight: export.height,
        sourceWasNormalized: sourceWasNormalized,
        outputWidth: export.width,
        outputHeight: export.height,
        compressionApplied: compressionApplied,
      );
    }
    return ImageEditorResult(
      maskImage: maskImage,
      hasMaskChanges: true,
      hasSourceImageChanges: imageSource.hasChanges,
      minimumContextMegaPixels: session.minimumContextMegaPixels,
      focusedInpaintEnabled: true,
      focusOutpaint: FocusOutpaintResult(
        sourceImage: export.sourceImage,
        width: export.width,
        height: export.height,
        crop: export.crop,
      ),
      sourceWasNormalized: sourceWasNormalized,
      outputWidth: export.width,
      outputHeight: export.height,
      compressionApplied: compressionApplied,
    );
  }

  Uint8List? get _sourceLayerBytes {
    final sourceLayerId = session.sourceLayerId;
    return sourceLayerId == null
        ? null
        : editorState.layerManager.getLayerById(sourceLayerId)?.baseImageBytes;
  }

  /// 送出区域 [region] 对应的画面：图片层没改过时沿用原图字节与原图区域，
  /// 改过则把区域内全部可见图片层重新合成，区域本身即新的原图区域
  Future<({Uint8List bytes, Rect rect})> _resolveSourceImage(
    Rect region,
  ) async {
    if (!imageSource.hasChanges) {
      final bytes = _sourceLayerBytes;
      final rect = frameController.sourceRect;
      if (bytes == null || rect == null) {
        throw StateError('Unable to read current source image.');
      }
      return (bytes: bytes, rect: rect);
    }
    return (bytes: await imageSource.renderComposite(region), rect: region);
  }

  /// 按取景框从当前画面取出送去生成的源图，框外空白保持透明
  Future<Uint8List> _materializeFrameSource({
    int? targetWidth,
    int? targetHeight,
  }) async {
    final frame = editorState.frame;
    final source = await _resolveSourceImage(frame);
    final result = await session.processingService.materializeOutpaint(
      sourceImage: source.bytes,
      frame: EditorFrameGeometry.virtualFrame(
        frame: frame,
        sourceRect: source.rect,
      ),
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    session.outpaintSourceImage = result.sourceImage;
    session.outpaintSourceWidth = result.width;
    session.outpaintSourceHeight = result.height;
    return result.sourceImage;
  }

  Future<Uint8List> _exportMergedImageAtCompressionTarget() async {
    final raw = await ImageExporterNew.exportMergedRgba(
      editorState.layerManager,
      editorState.frame,
      transparentBackground: session.hasTransparentCutout,
    );
    final target = compressionController.activeTarget;
    return EditorCompressionEncoder.encodeRgbaPngAsync(
      raw,
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }

  Future<Uint8List> _exportInpaintLayerMaskAtCompressionTarget(
    List<Rect> additionalMaskRects,
  ) async {
    final maskLayers = editorState.layerManager.maskLayers;
    final target = compressionController.activeTarget;
    final region = editorState.frame;
    final raster = await ImageExporterNew.tryExportHardEdgeMaskRasterFromLayers(
      maskLayers,
      region,
      additionalMaskRects: additionalMaskRects,
    );
    if (raster != null) {
      return InpaintMaskUtils.resizeBinaryMaskToPngAsync(
        raster.mask,
        sourceWidth: raster.width,
        sourceHeight: raster.height,
        targetWidth: target.width,
        targetHeight: target.height,
      );
    }

    final mask = await ImageExporterNew.exportMaskFromLayers(
      maskLayers,
      region,
      forceHardEdges: true,
      additionalMaskRects: additionalMaskRects,
    );
    return InpaintMaskUtils.resizeMaskBytesAsync(
      mask,
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }

  Future<Uint8List> _exportFocusedSelectionMaskAtCompressionTarget(
    Rect workSelection,
  ) {
    final target = compressionController.activeTarget;
    return InpaintMaskUtils.createRectMaskBytesAsync(
      width: target.width,
      height: target.height,
      rect: compressionController.projectWorkRectToTarget(workSelection),
    );
  }

  Future<Uint8List?> _prepareInpaintSourceAtCompressionTarget() async {
    final target = compressionController.activeTarget;
    Uint8List? source;
    if (frameController.hasOutpaintChanges) {
      source = await _materializeFrameSource(
        targetWidth: target.width,
        targetHeight: target.height,
      );
    } else if (imageSource.hasChanges) {
      source = await imageSource.renderComposite(editorState.frame);
    } else {
      source = session.inpaintWorkingSourceImage;
    }
    if (source == null) return null;

    final normalized = await NaiResolutionAdapter.normalizeImageForRequestAsync(
      source,
      targetWidth: target.width,
      targetHeight: target.height,
    );
    if (normalized == null) {
      throw StateError('Failed to encode the compressed inpaint source.');
    }
    return normalized;
  }
}
