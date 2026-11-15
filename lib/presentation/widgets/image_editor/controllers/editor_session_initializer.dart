import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../core/editor_state.dart';
import '../core/layer_role_policy.dart';
import '../frame/editor_frame_controller.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../layers/image_layer_source.dart';
import '../layers/layer.dart';
import '../layers/layer_role.dart';
import 'editor_compression_controller.dart';

/// 负责编辑会话的画布、初始底图、图层角色、既有蒙版与既有取景框初始化。
class EditorSessionInitializer {
  const EditorSessionInitializer({
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

  Future<void> initializeCanvas(
    BuildContext context, {
    required bool Function() isMounted,
    required VoidCallback onMarkInitialized,
  }) async {
    final operationEpoch = session.beginOperation();
    final initialImage = config.initialImage;
    if (initialImage != null) {
      // 从已有图像初始化
      await _loadInitialImage(
        context,
        initialImage,
        operationEpoch,
        isMounted: isMounted,
      );
    } else {
      // 显示尺寸选择对话框或使用默认尺寸
      final size = config.initialSize ?? const Size(1024, 1024);
      editorState.initNewCanvas(
        size,
        initialLayerName: context.l10n.editor_defaultDrawingLayerName,
      );
      _localizeDefaultLayerName(context);
      _applyInpaintLayerRoles(context);
      _selectInitialLayers();
      session.focusedSelectionState.canvasSize = size;

      // 加载已有蒙版（如果有）
      await _loadExistingMask(context, operationEpoch, isMounted: isMounted);
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      _loadExistingFocusSelection();
    }

    if (!isMounted() || !session.accepts(operationEpoch)) return;
    compressionController.initializePlan();

    onMarkInitialized();

    if (_isInpaintMode) {
      editorState.setToolById(
        session.focusedInpaintEnabled && config.existingFocusRect == null
            ? 'rect_selection'
            : 'brush',
      );
    }

    // 适应视口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editorState.canvasController.fitToViewport(editorState.frame);
    });
  }

  Future<void> _loadInitialImage(
    BuildContext context,
    Uint8List initialImage,
    int operationEpoch, {
    required bool Function() isMounted,
  }) async {
    final defaultDrawingLayerName = context.l10n.editor_defaultDrawingLayerName;
    final baseLayerName = context.l10n.editor_baseLayerName;
    ui.Codec? codec;
    ui.Image? decodedImage;
    try {
      final editorImage = await NaiResolutionAdapter.prepareImageForEditorAsync(
        initialImage,
        alignForInpaint: _isInpaintMode,
      );
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      var workingBytes = editorImage?.bytes ?? initialImage;
      if (editorImage?.resizeMode == NaiEditorResizeMode.medium) {
        workingBytes = await _resizeEditorImageWithMedium(
          workingBytes,
          width: editorImage!.width,
          height: editorImage.height,
        );
        if (!isMounted() || !session.accepts(operationEpoch)) return;
      }
      session.initialSourceWidth = editorImage?.originalWidth;
      session.initialSourceHeight = editorImage?.originalHeight;
      session.sourceWasNormalized = editorImage?.wasNormalized ?? false;
      if (_isInpaintMode) {
        session.inpaintWorkingSourceImage = workingBytes;
        session.inpaintWorkingSourceWidth = editorImage?.width;
        session.inpaintWorkingSourceHeight = editorImage?.height;
      }

      codec = await ui.instantiateImageCodec(workingBytes);
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      final image = decodedImage;
      session.initialSourceWidth ??= image.width;
      session.initialSourceHeight ??= image.height;
      session.inpaintWorkingSourceWidth ??= image.width;
      session.inpaintWorkingSourceHeight ??= image.height;

      editorState.initNewCanvas(
        Size(image.width.toDouble(), image.height.toDouble()),
        initialLayerName: defaultDrawingLayerName,
      );
      session.focusedSelectionState.canvasSize = editorState.canvasSize;

      // 将图像添加为底图图层
      final sourceLayer = await editorState.layerManager.addLayerFromImage(
        workingBytes,
        name: baseLayerName,
      );
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      session.sourceLayerId = sourceLayer?.id;
      if (_isInpaintMode && sourceLayer != null) {
        frameController.attachSource(
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        );
      }

      if (!context.mounted) return;
      _localizeDefaultLayerName(context);
      _applyInpaintLayerRoles(context);
      _selectInitialLayers();

      // 加载已有蒙版
      await _loadExistingMask(context, operationEpoch, isMounted: isMounted);
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      _loadExistingFocusSelection();
      // 蒙版按整张原图载入，必须先于取景框恢复
      _restoreExistingFrame();
      imageSource.captureBaseline();
    } catch (e) {
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      if (!context.mounted) return;
      AppLogger.w('Failed to load initial image: $e', 'ImageEditor');
      editorState.initNewCanvas(
        config.initialSize ?? const Size(1024, 1024),
        initialLayerName: defaultDrawingLayerName,
      );
      _localizeDefaultLayerName(context);
      _applyInpaintLayerRoles(context);
      _selectInitialLayers();
      session.focusedSelectionState.canvasSize = editorState.canvasSize;
    } finally {
      decodedImage?.dispose();
      codec?.dispose();
    }
  }

  Future<Uint8List> _resizeEditorImageWithMedium(
    Uint8List sourceBytes, {
    required int width,
    required int height,
  }) {
    return session.processingService.resize(
      sourceBytes,
      width: width,
      height: height,
    );
  }

  Future<void> _loadExistingMask(
    BuildContext context,
    int operationEpoch, {
    required bool Function() isMounted,
  }) async {
    final existingMask = config.existingMask;
    if (existingMask == null) return;

    try {
      final resizedMask = await InpaintMaskUtils.resizeMaskBytesAsync(
        existingMask,
        targetWidth: editorState.canvasSize.width.round(),
        targetHeight: editorState.canvasSize.height.round(),
      );
      final overlayBytes = await InpaintMaskUtils.maskToEditorOverlayAsync(
        resizedMask,
      );
      if (!isMounted() || !session.accepts(operationEpoch)) return;
      if (!context.mounted) return;

      // 将已有蒙版添加为图层
      final layer = await _addMaskLayerAboveSource(
        overlayBytes,
        name: context.l10n.editor_existingMaskLayerName,
        offset: editorState.frame.topLeft,
      );

      if (layer != null) {
        AppLogger.i(
          'Existing mask loaded as layer: ${layer.id}',
          'ImageEditor',
        );
      } else {
        AppLogger.w('Failed to load existing mask as layer', 'ImageEditor');
      }
    } catch (e) {
      AppLogger.e('Error loading existing mask: $e', 'ImageEditor');
    }
  }

  void _loadExistingFocusSelection() {
    final rect = config.existingFocusRect;
    if (!_isInpaintMode || rect == null) {
      return;
    }
    final sourceWidth = session.initialSourceWidth;
    final sourceHeight = session.initialSourceHeight;
    if (sourceWidth == null || sourceHeight == null) {
      session.focusedSelectionState.load(rect);
      compressionController.constrainCommittedFocusedSelection();
      return;
    }
    session.focusedSelectionState.load(
      Rect.fromLTRB(
        rect.left * editorState.canvasSize.width / sourceWidth,
        rect.top * editorState.canvasSize.height / sourceHeight,
        rect.right * editorState.canvasSize.width / sourceWidth,
        rect.bottom * editorState.canvasSize.height / sourceHeight,
      ),
    );
    compressionController.constrainCommittedFocusedSelection();
  }

  /// 按导入时的缩放把上次的取景框换算到编辑器坐标
  void _restoreExistingFrame() {
    final rect = config.existingFrameRect;
    final sourceWidth = session.initialSourceWidth;
    final sourceHeight = session.initialSourceHeight;
    if (!_isInpaintMode ||
        rect == null ||
        sourceWidth == null ||
        sourceHeight == null) {
      return;
    }
    final scaleX = editorState.canvasSize.width / sourceWidth;
    final scaleY = editorState.canvasSize.height / sourceHeight;
    frameController.restoreFrame(
      Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      ),
    );
    if (session.focusedInpaintEnabled && frameController.hasOutpaintChanges) {
      compressionController.disableFocusedInpaintForOutpaint();
    }
  }

  void _localizeDefaultLayerName(BuildContext context) {
    if (!context.mounted) return;
    for (final layer in editorState.layerManager.layers) {
      if (layer.name == '\u56fe\u5c42 1' || layer.name == 'Layer 1') {
        editorState.layerManager.renameLayer(
          layer.id,
          context.l10n.editor_defaultDrawingLayerName,
        );
        return;
      }
    }
  }

  /// 重绘会话启用图层角色：原图层是受保护的图片层，最上方另建蒙版层；
  /// 默认绘制层与编辑会话一样留作图片层，编辑组的笔迹与擦除都落在它上面而不碰原图
  void _applyInpaintLayerRoles(BuildContext context) {
    if (!_isInpaintMode || !context.mounted) return;
    editorState.layerManager.addLayer(
      name: context.l10n.editor_maskLayerName,
      index: 0,
      role: LayerRole.mask,
    );
    editorState.setRolePolicy(
      LayerRolePolicy.inpaint(protectedLayerId: session.sourceLayerId),
    );
  }

  void _selectInitialLayers() {
    final layers = editorState.layerManager;
    layers.selectInitialLayers(
      layers.layers.firstWhere(
        (layer) => !layer.isMask && layer.id != session.sourceLayerId,
        orElse: () => layers.layers.last,
      ),
    );
  }

  /// 蒙版层总在全部图片层之上
  int _resolveMaskLayerInsertIndex() {
    return editorState.rolePolicy.insertIndexFor(
      editorState.layerManager,
      LayerRole.mask,
    );
  }

  /// [offset] 为蒙版图像左上角的文档坐标
  Future<Layer?> _addMaskLayerAboveSource(
    Uint8List imageBytes, {
    required String name,
    Offset offset = Offset.zero,
  }) {
    return editorState.layerManager.addLayerFromImage(
      imageBytes,
      name: name,
      index: _resolveMaskLayerInsertIndex(),
      offset: offset,
      role: LayerRole.mask,
    );
  }
}
