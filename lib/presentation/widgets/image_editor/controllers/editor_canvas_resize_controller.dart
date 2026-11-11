import 'package:flutter/widgets.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../common/app_toast.dart';
import '../core/editor_state.dart';
import '../frame/editor_frame_controller.dart';
import '../frame/frame_geometry.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../layers/layer.dart';
import '../widgets/panels/canvas_size_dialog.dart';
import '../widgets/panels/shift_edges_dialog.dart';
import 'editor_compression_controller.dart';

/// 负责画布尺寸调整、重绘取景框缩放与边缘偏移操作，并在取景框变化后同步关联状态。
class EditorCanvasResizeController {
  const EditorCanvasResizeController({
    required ImageEditorController Function() session,
    required ImageEditorSessionConfig Function() config,
    required this.frameController,
    required this.compressionController,
  }) : _session = session,
       _config = config;

  final ImageEditorController Function() _session;
  final ImageEditorSessionConfig Function() _config;
  final EditorFrameController frameController;
  final EditorCompressionController compressionController;

  ImageEditorController get session => _session();

  EditorState get editorState => session.editorState;

  ImageEditorSessionConfig get config => _config();

  bool get _isInpaintMode => config.mode == ImageEditorMode.inpaint;

  Future<void> changeCanvasSize(BuildContext context) async {
    final l10n = context.l10n;
    final compressionScale = compressionController.compressionLinearScale;
    final result = await CanvasSizeDialog.show(
      context,
      initialSize: editorState.canvasSize,
      title: _isInpaintMode
          ? l10n.editor_changeFrameSize
          : l10n.editor_changeCanvasSize,
      allowStretch: !_isInpaintMode,
    );
    if (result == null || !context.mounted) return;

    if (result.size != editorState.canvasSize) {
      try {
        // 验证尺寸范围
        final newWidth = result.size.width.toInt();
        final newHeight = result.size.height.toInt();
        const minSize = 64;
        const maxSize = 4096;

        if (newWidth < minSize || newHeight < minSize) {
          AppToast.error(context, l10n.editor_canvasTooSmall(minSize, minSize));
          return;
        }

        if (newWidth > maxSize || newHeight > maxSize) {
          AppToast.error(context, l10n.editor_canvasTooLarge(maxSize, maxSize));
          return;
        }

        if (_isInpaintMode) {
          final outcome = _applyFrameResize(result.size);
          if (!context.mounted) return;
          _presentFrameResizeOutcome(context, outcome);
          return;
        }

        // 将 ContentHandlingMode 转换为 CanvasResizeMode
        final mode = _convertContentModeToResizeMode(result.mode);

        // 使用新的 resizeCanvas 方法，支持图层内容变换
        editorState.resizeCanvas(result.size, mode);
        session.focusedSelectionState.canvasSize = result.size;
        compressionController.refreshPlan(desiredScale: compressionScale);
        compressionController.constrainCommittedFocusedSelection();
        compressionController.refreshPlan();

        // 显示成功消息
        if (context.mounted) {
          AppToast.success(
            context,
            l10n.editor_canvasResized(newWidth, newHeight),
          );
        }
      } catch (e) {
        // 显示错误信息
        if (context.mounted) {
          AppToast.error(context, l10n.editor_canvasResizeFailed(e));
        }
        AppLogger.e('Failed to resize canvas: $e', 'ImageEditor');
      }
    }
  }

  /// 重绘模式的尺寸对话框只调整取景框：左上角锚定，尺寸按 64 对齐
  FrameResizeOutcome _applyFrameResize(Size size) {
    final frame = editorState.frame;
    return frameController.applyFrameDelta(
      OutpaintFrameDelta(
        right: size.width.round() - frame.width.round(),
        bottom: size.height.round() - frame.height.round(),
      ),
      horizontalSnapTarget: OutpaintHorizontalSnapTarget.right,
      verticalSnapTarget: OutpaintVerticalSnapTarget.bottom,
    );
  }

  void _presentFrameResizeOutcome(
    BuildContext context,
    FrameResizeOutcome outcome,
  ) {
    if (outcome == FrameResizeOutcome.rejected) {
      _showFrameResizeRejected(context);
      return;
    }
    if (outcome != FrameResizeOutcome.applied) return;
    editorState.canvasController.fitToViewport(editorState.frame);
    AppToast.success(
      context,
      context.l10n.editor_frameResized(
        editorState.frame.width.round(),
        editorState.frame.height.round(),
      ),
    );
  }

  Future<void> showShiftEdgesDialog(
    BuildContext context, {
    required bool Function() isMounted,
  }) async {
    if (!_isInpaintMode) return;
    final result = await ShiftEdgesDialog.show(
      context,
      sourceWidth: editorState.canvasSize.width.round(),
      sourceHeight: editorState.canvasSize.height.round(),
    );
    if (result == null || !isMounted() || !context.mounted) return;
    await applyOutpaintEdges(
      context,
      result.requestedEdges,
      horizontalSnapTarget: result.horizontalSnapTarget,
      verticalSnapTarget: result.verticalSnapTarget,
      isMounted: isMounted,
    );
  }

  Future<void> applyOutpaintEdges(
    BuildContext context,
    OutpaintEdges edges, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
    required bool Function() isMounted,
  }) {
    return applyOutpaintFrameDelta(
      context,
      OutpaintFrameDelta.fromExpansionEdges(edges),
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
      isMounted: isMounted,
    );
  }

  Future<void> applyOutpaintFrameDelta(
    BuildContext context,
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
    required bool Function() isMounted,
  }) async {
    if (!_isInpaintMode || delta.isEmpty) {
      return;
    }
    if (frameController.sourceRect == null) {
      if (isMounted() && context.mounted) {
        AppToast.error(context, 'Unable to read current source image.');
      }
      return;
    }

    final outcome = frameController.applyFrameDelta(
      delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
    switch (outcome) {
      case FrameResizeOutcome.applied:
        editorState.canvasController.fitToViewport(editorState.frame);
      case FrameResizeOutcome.rejected:
        if (isMounted() && context.mounted) {
          _showFrameResizeRejected(context);
        }
      case FrameResizeOutcome.unchanged:
        break;
    }
  }

  /// 拖边、平移、尺寸对话框与撤销重做都经由这里同步依赖取景框的状态
  bool syncOnFrameChanged() {
    if (!_isInpaintMode ||
        !session.isInitialized ||
        !frameController.isAttached) {
      return false;
    }
    final frame = editorState.frame;
    session.outpaintSourceImage = null;
    session.outpaintSourceWidth = frame.width.round();
    session.outpaintSourceHeight = frame.height.round();
    session.focusedSelectionState.canvasSize = frame.size;
    if (session.focusedInpaintEnabled && frameController.hasOutpaintChanges) {
      compressionController.disableFocusedInpaintForOutpaint();
    }
    compressionController.refreshPlan(
      desiredScale: compressionController.planLinearScale,
    );
    return true;
  }

  void _showFrameResizeRejected(BuildContext context) {
    AppToast.warning(
      context,
      context.l10n.editor_frameResizeRejected(
        EditorFrameGeometry.minimumSourceOverlap,
        InpaintOutpaintUtils.maxDimension,
      ),
    );
  }

  CanvasResizeMode _convertContentModeToResizeMode(ContentHandlingMode mode) {
    switch (mode) {
      case ContentHandlingMode.crop:
        return CanvasResizeMode.crop;
      case ContentHandlingMode.pad:
        return CanvasResizeMode.pad;
      case ContentHandlingMode.stretch:
        return CanvasResizeMode.stretch;
    }
  }
}
