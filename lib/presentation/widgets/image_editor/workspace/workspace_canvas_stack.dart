import 'package:flutter/material.dart';

import '../../../../core/utils/inpaint_outpaint_utils.dart';
import '../canvas/editor_canvas.dart';
import '../canvas/layer_painter.dart';
import '../controllers/editor_compression_controller.dart';
import '../controllers/magic_wand_controller.dart';
import '../core/editor_state.dart';
import '../frame/editor_frame_controller.dart';
import '../image_editor_controller.dart';
import '../painters/focused_context_overlay_painter.dart';
import '../tools/closed_region_fill_tool.dart';
import '../tools/move_tool.dart';
import '../widgets/focused_selection_card.dart';
import '../widgets/magic_wand_progress_overlay.dart';
import '../widgets/outpaint_edge_drag_overlay.dart';
import '../widgets/transform_session_bar.dart';

typedef OutpaintEdgesCommitCallback =
    Future<void> Function(
      OutpaintEdges edges, {
      OutpaintHorizontalSnapTarget horizontalSnapTarget,
      OutpaintVerticalSnapTarget verticalSnapTarget,
    });

typedef OutpaintFrameDeltaCommitCallback =
    Future<void> Function(
      OutpaintFrameDelta delta, {
      OutpaintHorizontalSnapTarget horizontalSnapTarget,
      OutpaintVerticalSnapTarget verticalSnapTarget,
    });

/// 组装工作区中央画布与各类状态遮罩、控制悬浮卡及自由变换操作条。
class WorkspaceCanvasStack extends StatelessWidget {
  const WorkspaceCanvasStack({
    super.key,
    required this.session,
    required this.state,
    required this.isInpaintMode,
    required this.frameController,
    required this.magicWandController,
    required this.compressionController,
    required this.onApplyOutpaintEdges,
    required this.onApplyOutpaintFrameDelta,
    required this.onToggleFocusedInpaint,
    required this.onClearFocusedSelection,
    required this.onMinimumContextChanged,
  });

  final ImageEditorController session;
  final EditorState state;
  final bool isInpaintMode;
  final EditorFrameController frameController;
  final MagicWandController magicWandController;
  final EditorCompressionController compressionController;
  final OutpaintEdgesCommitCallback onApplyOutpaintEdges;
  final OutpaintFrameDeltaCommitCallback onApplyOutpaintFrameDelta;
  final VoidCallback onToggleFocusedInpaint;
  final VoidCallback onClearFocusedSelection;
  final ValueChanged<double> onMinimumContextChanged;

  bool get _isClosedRegionFillActive =>
      state.currentTool?.id == ClosedRegionFillTool.toolId;

  /// 封闭区域填充要点到取景框边缘附近、移动工具的变换手柄可能压在框边上，此时边缘拖动让出指针
  bool get _toolNeedsFrameEdges =>
      _isClosedRegionFillActive || state.currentTool?.id == MoveTool.toolId;

  bool _shouldSuppressCanvasPointerInput(Offset localPosition) {
    if (!isInpaintMode ||
        session.focusedInpaintEnabled ||
        _toolNeedsFrameEdges ||
        frameController.isCommitting) {
      return false;
    }

    final viewportSize = state.canvasController.viewportSize;
    if (viewportSize == Size.zero) {
      return false;
    }

    return OutpaintEdgeDragOverlay.isResizeInteractionPoint(
      localPosition: localPosition,
      viewportSize: viewportSize,
      frame: state.frame,
      controller: state.canvasController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusedInpaintEnabled = session.focusedInpaintEnabled;
    final focusedSelectionState = session.focusedSelectionState;
    final focusAreaRect = focusedInpaintEnabled
        ? focusedSelectionState.resolveActiveRect(
            previewPath: state.previewPath,
          )
        : null;
    final contextCrop = focusAreaRect == null
        ? null
        : compressionController.resolveFocusedContextCropOnWorkCanvas(
            focusAreaRect,
          );

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: EditorCanvas(
              state: state,
              showTransparentCanvasBackground:
                  isInpaintMode || session.hasTransparentCutout,
              revealOutsideFrame: isInpaintMode,
              shouldSuppressPointerInput: _shouldSuppressCanvasPointerInput,
              suppressSelectionOverlay: focusedSelectionState
                  .shouldSuppressSelectionOverlay(
                    focusedEnabled: isInpaintMode && focusedInpaintEnabled,
                    currentToolId: state.currentTool?.id,
                    previewPath: state.previewPath,
                  ),
            ),
          ),
        ),
        if (isInpaintMode && !focusedInpaintEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VirtualOutpaintMaskPainter(
                    state: state,
                    maskRectsFor: frameController.outpaintMaskRectsFor,
                  ),
                ),
              ),
            ),
          ),
        if (isInpaintMode && !focusedInpaintEnabled)
          Positioned.fill(
            child: ListenableBuilder(
              listenable: Listenable.merge([
                frameController,
                state.framePreviewNotifier,
                state.toolChangeNotifier,
              ]),
              builder: (context, _) => _toolNeedsFrameEdges
                  ? const SizedBox.shrink()
                  : OutpaintEdgeDragOverlay(
                      frame: state.displayFrame,
                      controller: state.canvasController,
                      enabled:
                          !frameController.isCommitting &&
                          state.framePreviewNotifier.value == null,
                      onCommitted: onApplyOutpaintEdges,
                      onFrameResizeCommitted: onApplyOutpaintFrameDelta,
                      isFrameAllowed: frameController.isFrameAllowed,
                    ),
            ),
          ),
        if (isInpaintMode && focusAreaRect != null && contextCrop != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: FocusedContextOverlayPainter(
                    state: state,
                    focusAreaRect: focusAreaRect,
                    contextCrop: contextCrop,
                    repaint: Listenable.merge([
                      state.renderNotifier,
                      state.canvasController,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        if (isInpaintMode)
          Positioned(
            top: 16,
            left: 16,
            child: FocusedSelectionCard(
              state: state,
              focusedInpaintEnabled: focusedInpaintEnabled,
              hasCommittedRect: focusedSelectionState.hasCommittedRect,
              minimumContextMegaPixels: session.minimumContextMegaPixels,
              costEstimate: compressionController
                  .resolveFocusedInpaintCostEstimate(),
              onToggleFocusedInpaint: onToggleFocusedInpaint,
              onClearSelection: onClearFocusedSelection,
              onMinimumContextChanged: onMinimumContextChanged,
            ),
          ),
        Positioned.fill(
          child: MagicWandProgressOverlay(controller: magicWandController),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Center(child: TransformSessionBar(state: state)),
        ),
      ],
    );
  }
}
