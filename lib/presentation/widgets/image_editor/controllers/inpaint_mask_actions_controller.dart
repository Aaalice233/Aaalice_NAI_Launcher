import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../export/image_exporter_new.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../layers/layer_role.dart';
import '../widgets/editor_image_import.dart';
import 'editor_compression_controller.dart';

/// 重绘会话的蒙版操作协调器：封闭区域填充、外部蒙版加载与蒙版层重置。
class InpaintMaskActionsController {
  const InpaintMaskActionsController({
    required ImageEditorController Function() session,
    required ImageEditorSessionConfig Function() config,
    required this.compressionController,
  }) : _session = session,
       _config = config;

  final ImageEditorController Function() _session;
  final ImageEditorSessionConfig Function() _config;
  final EditorCompressionController compressionController;

  ImageEditorController get session => _session();

  EditorState get editorState => session.editorState;

  ImageEditorSessionConfig get config => _config();

  bool get _isInpaintMode => config.mode == ImageEditorMode.inpaint;

  Future<void> fillClosedMaskRegionsAt(
    BuildContext context,
    Offset canvasPoint, {
    required bool Function() isMounted,
  }) async {
    if (!_isInpaintMode || !isMounted()) {
      return;
    }
    final l10n = context.l10n;

    try {
      // 蒙版按点击时的取景框导出，填充结果落回同一位置
      final region = editorState.frame;
      final originalMask = await ImageExporterNew.exportMaskFromLayers(
        editorState.layerManager.maskLayers,
        region,
        forceHardEdges: true,
        preferCpuHardEdgeExport: true,
      );
      if (!isMounted()) {
        return;
      }

      final fillResult =
          await InpaintMaskUtils.fillEditorMaskRegionAtPointAsync(
            originalMask,
            x: (canvasPoint.dx - region.left).floor(),
            y: (canvasPoint.dy - region.top).floor(),
          );
      if (!isMounted() || !context.mounted) {
        return;
      }
      switch (fillResult.status) {
        case MaskFillRegionStatus.emptyMask:
          AppToast.warning(context, l10n.editor_drawClosedMaskOutlineFirst);
          return;
        case MaskFillRegionStatus.outOfBounds:
        case MaskFillRegionStatus.clickedMaskedPixel:
        case MaskFillRegionStatus.openRegion:
          AppToast.info(context, l10n.editor_noClosedRegionAtPosition);
          return;
        case MaskFillRegionStatus.filled:
          break;
      }

      final patch = fillResult.addedPatch;
      if (patch == null) {
        throw Exception(l10n.editor_generateMaskOverlayFailed);
      }
      final ui.Image image;
      try {
        image = await session.processingService.decode(patch.bytes);
      } on Object {
        throw Exception(l10n.editor_updateMaskLayerFailed);
      }
      if (!isMounted()) {
        image.dispose();
        return;
      }
      editorState.layerCommands.addMaskPixels(
        image,
        offset: region.topLeft.translate(
          patch.left.toDouble(),
          patch.top.toDouble(),
        ),
        newLayerName: l10n.editor_maskLayerName,
        description: 'Fill Closed Mask Region',
      );

      editorState.requestUiUpdate();
      if (isMounted() && context.mounted) {
        AppToast.success(context, l10n.editor_closedRegionFilled);
      }
    } catch (e) {
      if (isMounted() && context.mounted) {
        AppToast.error(context, l10n.editor_fillMaskFailed(e));
      }
    }
  }

  /// 加载蒙版文件
  Future<void> loadMaskFile(
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    final l10n = context.l10n;
    final maskLayerName = l10n.editor_maskLayerName;
    try {
      final picked = await pickEditorImageFile(context);
      if (picked == null || !isMounted()) {
        return;
      }

      // 蒙版层按 alpha 显示、导出按亮度判定，黑白蒙版不转 overlay 时黑色部分会显示成蒙版
      final overlayBytes = await InpaintMaskUtils.maskToEditorOverlayAsync(
        picked.bytes,
      );
      if (!isMounted()) {
        return;
      }
      final layer = await editorState.layerCommands.addImageLayer(
        overlayBytes,
        name: maskLayerName,
        offset: editorState.frame.topLeft,
        role: LayerRole.mask,
      );
      if (!isMounted()) return;

      if (layer != null) {
        AppLogger.i('Mask layer added: ${layer.id}', 'ImageEditor');
        if (context.mounted) {
          AppToast.success(context, l10n.editor_maskLayerAdded);
        }
      } else {
        // 图像解码失败或格式不支持
        AppLogger.w(
          'Failed to decode image or unsupported format',
          'ImageEditor',
        );
        if (context.mounted) {
          AppToast.error(context, l10n.editor_parseImageFailed);
        }
      }
    } catch (e) {
      AppLogger.e('Unexpected error loading mask file: $e', 'ImageEditor');
      if (isMounted() && context.mounted) {
        AppToast.error(context, l10n.editor_loadMaskFailed(e));
      }
    }
  }

  /// 重置重绘蒙版层；返回 true 表示已重置蒙版层，外层布局需要刷新。
  bool resetInpaintMask(BuildContext context) {
    if (!_isInpaintMode || !editorState.isMaskLayerActive) {
      editorState.clearActiveLayerWithHistory();
      return false;
    }

    editorState.layerCommands.resetMaskLayers(
      name: context.l10n.editor_maskLayerName,
    );
    editorState.clearSelection(saveHistory: false);
    editorState.clearPreview();
    session.focusedSelectionState.clear();
    editorState.setToolById(
      session.focusedInpaintEnabled ? 'rect_selection' : 'brush',
    );
    compressionController.refreshPlan();
    editorState.requestUiUpdate();
    return true;
  }
}
