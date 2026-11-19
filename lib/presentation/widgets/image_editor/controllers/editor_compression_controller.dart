import 'dart:ui';

import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../core/editor_state.dart';
import '../core/focused_selection_state.dart';
import '../frame/editor_frame_commands.dart';
import '../frame/editor_frame_controller.dart';
import '../frame/focus_outpaint_export.dart';
import '../frame/frame_geometry.dart';
import '../image_editor_controller.dart';
import '../image_editor_types.dart';
import '../tools/frame_tool.dart';

/// 维护导出分辨率压缩档位、发送请求估算与聚焦重绘选区约束。
class EditorCompressionController {
  EditorCompressionController({
    required ImageEditorController Function() session,
    required ImageEditorSessionConfig Function() config,
    required this.frameController,
  }) : _session = session,
       _config = config;

  final ImageEditorController Function() _session;
  final ImageEditorSessionConfig Function() _config;
  final EditorFrameController frameController;

  ImageEditorController get session => _session();

  EditorState get editorState => session.editorState;

  ImageEditorSessionConfig get config => _config();

  /// 当前压缩档位是按哪块交出区域算的
  Rect? _compressionPlanRegion;

  bool get isInpaintMode => config.mode == ImageEditorMode.inpaint;

  FocusedSelectionState get _focusedSelectionState =>
      session.focusedSelectionState;

  double get minimumContextMegaPixels => session.minimumContextMegaPixels;

  bool get focusedInpaintEnabled => session.focusedInpaintEnabled;

  EditorCompressionPlan? get plan => session.compressionPlan;

  EditorCompressionTarget? get _compressionTarget => session.compressionTarget;

  /// 点「完成」后交出的区域：贴回时是原图与取景框合起来的整张画布，否则就是取景框
  Rect get outputRegion => frameController.pasteBackCanvas ?? editorState.frame;

  /// 贴回时取景框在整张画布中的位置
  Rect? get pasteBackFrameInCanvas {
    final canvas = frameController.pasteBackCanvas;
    if (canvas == null) return null;
    return EditorFrameGeometry.frameInCanvas(
      frame: editorState.frame,
      canvas: canvas,
    );
  }

  /// 压缩档位以交出区域为工作尺寸；聚焦选区只在交出区域就是取景框时存在
  int get workWidth => outputRegion.width.round();

  int get workHeight => outputRegion.height.round();

  EditorCompressionTarget get activeTarget {
    final target = _compressionTarget;
    if (target != null) return target;
    return EditorCompressionTarget(
      width: workWidth,
      height: workHeight,
      isOriginal: true,
    );
  }

  bool get compressionApplied {
    final target = activeTarget;
    return target.width != workWidth || target.height != workHeight;
  }

  /// 超出请求面积上限的档位会在交接给生成页时收敛，UI 要显示实际会发送的尺寸。
  ({int width, int height})? get clampedRequestSize {
    final target = activeTarget;
    if (NaiResolutionAdapter.isGenerationCompatible(
      target.width,
      target.height,
    )) {
      return null;
    }
    final closest = NaiResolutionAdapter.findClosestResolution(
      target.width,
      target.height,
    );
    return (width: closest.width, height: closest.height);
  }

  /// 聚焦选区或贴回的取景框让原尺寸超出请求面积上限时，说明滑条为何收紧
  String? limitNotice(AppLocalizations l10n) {
    final currentPlan = plan;
    if (!isInpaintMode ||
        currentPlan == null ||
        currentPlan.targets.any((target) => target.isOriginal)) {
      return null;
    }
    if (frameController.pasteBackCanvas != null) {
      return l10n.editor_compressionFrameLimited;
    }
    return focusedInpaintEnabled ? l10n.editor_compressionFocusLimited : null;
  }

  void refreshPlan() {
    final region = outputRegion;
    final currentWorkWidth = region.width.round();
    final currentWorkHeight = region.height.round();
    final nextPlan = EditorCompressionPlan.resolve(
      workWidth: currentWorkWidth,
      workHeight: currentWorkHeight,
      focusedInpaintEnabled: isInpaintMode && focusedInpaintEnabled,
      focusedSelectionRect: _focusedSelectionState.committedRect,
      focusedContextCrop: pasteBackFrameInCanvas,
      minimumContextPixels: minimumContextMegaPixels,
    );

    var target = nextPlan.highestTarget;
    final selection = session.compressionSelection;
    if (selection != null) {
      final exactIndex =
          selection.workWidth == currentWorkWidth &&
              selection.workHeight == currentWorkHeight
          ? nextPlan.indexOf(selection.target)
          : -1;
      target = exactIndex >= 0
          ? nextPlan.targets[exactIndex]
          : nextPlan.targetAtOrBelowScale(
              selection.target.linearScaleFor(
                selection.workWidth,
                selection.workHeight,
              ),
            );
    }
    session.compressionPlan = nextPlan;
    session.compressionTarget = target;
    _compressionPlanRegion = region;
    syncFocusedSelectionConstraint();
    publishRequestEstimate();
  }

  bool get canSelectTarget {
    final currentPlan = plan;
    return currentPlan != null && currentPlan.targets.isNotEmpty;
  }

  void selectTargetAt(int index) {
    final currentPlan = plan;
    if (currentPlan == null || currentPlan.targets.isEmpty) return;
    final resolvedIndex = index.clamp(0, currentPlan.targets.length - 1);
    final target = currentPlan.targets[resolvedIndex];
    session.compressionSelection = (
      workWidth: currentPlan.workWidth,
      workHeight: currentPlan.workHeight,
      target: target,
    );
    session.compressionTarget = target;
    syncFocusedSelectionConstraint();
    publishRequestEstimate();
  }

  /// 裁切到取景框及其撤销只改原图、不动取景框，交出区域要跟着原图重算
  bool refreshOnLayersChangedIfNeeded() {
    if (!isInpaintMode ||
        !session.isInitialized ||
        outputRegion == _compressionPlanRegion) {
      return false;
    }
    refreshPlan();
    return true;
  }

  void publishRequestEstimate() {
    if (!isInpaintMode) return;
    frameController.updateRequestEstimate(_resolveRequestEstimate());
  }

  /// 按「完成」后生成页实际会走的请求方式估算发送尺寸与点数；
  /// 没有生成页的请求上下文时无法预测实际尺寸，不给估算
  EditorRequestEstimate? _resolveRequestEstimate() {
    final costConfig = config.focusedInpaintCostConfig;
    if (costConfig == null) return null;
    final size = _resolveRequestSize(costConfig);
    if (size == null) return null;
    return EditorRequestEstimate(
      requestWidth: size.width,
      requestHeight: size.height,
      cost: costConfig.estimate(width: size.width, height: size.height),
    );
  }

  ({int width, int height})? _resolveRequestSize(
    ImageEditorFocusedInpaintCostConfig costConfig,
  ) {
    final target = activeTarget;
    final canvas = frameController.pasteBackCanvas;
    if (canvas != null) {
      final geometry = FocusedInpaintUtils.resolveGeometryForCrop(
        sourceWidth: target.width,
        sourceHeight: target.height,
        crop: FocusOutpaintExporter.projectCrop(
          frame: editorState.frame,
          canvas: canvas,
          target: target,
        ),
      );
      return geometry == null
          ? null
          : (width: geometry.requestWidth, height: geometry.requestHeight);
    }
    final focusRect = focusedInpaintEnabled
        ? _focusedSelectionState.committedRect
        : null;
    if (focusRect != null) {
      final geometry = resolveFocusedGeometryForWorkRect(focusRect);
      return geometry == null
          ? null
          : (width: geometry.requestWidth, height: geometry.requestHeight);
    }
    // 生成页收到未压缩的源图时按当前请求尺寸重新推导，压缩过的只收敛到上限内
    if (compressionApplied) {
      return clampedRequestSize ?? (width: target.width, height: target.height);
    }
    return costConfig.resolveImportRequestSize(
      sourceWidth: target.width,
      sourceHeight: target.height,
    );
  }

  Rect projectWorkRectToTarget(Rect rect) {
    final target = activeTarget;
    return EditorCompressionGeometry.projectRect(
      rect,
      sourceWidth: workWidth,
      sourceHeight: workHeight,
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }

  FocusedInpaintGeometry? resolveFocusedGeometryForWorkRect(Rect rect) {
    return EditorCompressionGeometry.resolveFocusedGeometry(
      workWidth: workWidth,
      workHeight: workHeight,
      target: activeTarget,
      workSelectionRect: rect,
      minimumContextPixels: minimumContextMegaPixels,
    );
  }

  Rect? constrainFocusedWorkRect(Rect rect, {Offset? fixedAnchor}) {
    return EditorCompressionGeometry.constrainWorkSelection(
      workWidth: workWidth,
      workHeight: workHeight,
      target: activeTarget,
      workSelectionRect: rect,
      minimumContextPixels: minimumContextMegaPixels,
      fixedWorkAnchor: fixedAnchor,
    );
  }

  Rect? resolveFocusedContextCropOnWorkCanvas(Rect selection) {
    final geometry = resolveFocusedGeometryForWorkRect(selection);
    if (geometry == null) return null;
    return EditorCompressionGeometry.projectTargetCropToWorkCanvas(
      targetCrop: geometry.contextCrop,
      workWidth: workWidth,
      workHeight: workHeight,
      target: activeTarget,
    );
  }

  /// 档位实际会发送的尺寸，超出请求面积上限的档位按生成页规则收敛
  static String sizeText(EditorCompressionTarget target) {
    final issue = NaiResolutionAdapter.validateGenerationResolution(
      target.width,
      target.height,
    );
    return '${issue?.suggestedWidth ?? target.width} x '
        '${issue?.suggestedHeight ?? target.height}';
  }

  static String sliderText(EditorCompressionPlan plan, double index) =>
      sizeText(plan.targets[index.round().clamp(0, plan.targets.length - 1)]);

  FocusedInpaintCostEstimate? resolveFocusedInpaintCostEstimate() {
    final costConfig = config.focusedInpaintCostConfig;
    if (!isInpaintMode || !focusedInpaintEnabled || costConfig == null) {
      return null;
    }

    final focusAreaRect = _focusedSelectionState.resolveActiveRect(
      previewPath: editorState.previewPath,
    );
    if (focusAreaRect == null) {
      return null;
    }

    final geometry = resolveFocusedGeometryForWorkRect(focusAreaRect);
    if (geometry == null) {
      return null;
    }

    final cost = costConfig.estimate(
      width: geometry.requestWidth,
      height: geometry.requestHeight,
    );

    return FocusedInpaintCostEstimate(geometry: geometry, cost: cost);
  }

  void disableFocusedInpaintForOutpaint() {
    session.focusedInpaintEnabled = false;
    syncFocusedSelectionConstraint();
    _focusedSelectionState.clear();
    editorState.clearSelection(saveHistory: false);
    editorState.clearPreview();
    // 正在用取景框工具调整时不打断
    if (editorState.currentTool?.id != FrameTool.toolId) {
      editorState.setToolById('brush');
    }
  }

  void toggleFocusedInpaint() {
    session.focusedInpaintEnabled = !focusedInpaintEnabled;
    if (focusedInpaintEnabled) {
      if (!_focusedSelectionState.hasCommittedRect) {
        editorState.setToolById('rect_selection');
      }
    } else {
      editorState.clearSelection(saveHistory: false);
      editorState.clearPreview();
      _focusedSelectionState.clear();
      editorState.setToolById('brush');
    }
    refreshPlan();
  }

  void clearFocusedSelection() {
    _focusedSelectionState.clear();
    editorState.clearSelection(saveHistory: false);
    editorState.clearPreview();
    editorState.setToolById('rect_selection');
    refreshPlan();
  }

  void updateMinimumContextMegaPixels(double value) {
    session.minimumContextMegaPixels = value;
    constrainCommittedFocusedSelection();
    refreshPlan();
  }

  void syncFocusedSelectionConstraint() {
    if (!isInpaintMode || !focusedInpaintEnabled) {
      editorState.setRectSelectionConstraint(null);
      return;
    }
    editorState.setRectSelectionConstraint((candidate, fixedAnchor) {
      return constrainFocusedWorkRect(candidate, fixedAnchor: fixedAnchor) ??
          candidate;
    });
  }

  void constrainCommittedFocusedSelection() {
    final selection = _focusedSelectionState.committedRect;
    if (selection == null) return;
    final constrained = constrainFocusedWorkRect(selection);
    _focusedSelectionState.load(constrained);
  }

  bool consumeFocusedSelection() {
    if (!isInpaintMode || !focusedInpaintEnabled) {
      return false;
    }
    if (editorState.currentTool?.id != 'rect_selection') {
      return false;
    }
    final consumed = _focusedSelectionState.captureSelection(
      editorState.selectionPath,
    );
    if (!consumed) {
      return false;
    }

    editorState.clearSelection(saveHistory: false);
    editorState.clearPreview();
    editorState.setToolById('brush');
    refreshPlan();
    editorState.requestUiUpdate();
    return true;
  }
}
