import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/services/efficient_vit_sam_service.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../widgets/common/app_toast.dart';
import 'controllers/editor_canvas_resize_controller.dart';
import 'controllers/editor_compression_controller.dart';
import 'controllers/editor_exit_coordinator.dart';
import 'controllers/editor_session_initializer.dart';
import 'controllers/inpaint_mask_actions_controller.dart';
import 'controllers/magic_wand_controller.dart';
import 'core/editor_state.dart';
import 'effects/image_editor_effects_controller.dart';
import 'export/editor_result_exporter.dart';
import 'frame/editor_frame_controller.dart';
import 'frame/frame_tool_panel.dart';
import 'image_editor_controller.dart';
import 'image_editor_types.dart';
import 'layers/image_layer_source.dart';
import 'widgets/panels/editor_compression_controls.dart';
import 'widgets/panels/editor_shortcut_help_sheet.dart';
import 'workspace/editor_drop_region.dart';
import 'workspace/workspace_canvas_stack.dart';
import 'workspace/workspace_desktop_layout.dart';
import 'workspace/workspace_mobile_layout.dart';

/// Layout host for one image editor session.
class ImageEditorWorkspace extends StatefulWidget {
  const ImageEditorWorkspace({
    super.key,
    required this.controller,
    required this.config,
  });

  final ImageEditorController controller;
  final ImageEditorSessionConfig config;

  Uint8List? get initialImage => config.initialImage;
  Size? get initialSize => config.initialSize;
  Uint8List? get existingMask => config.existingMask;
  Rect? get existingFocusRect => config.existingFocusRect;
  double get initialMinimumContextMegaPixels =>
      config.initialMinimumContextMegaPixels;
  bool get initialFocusedInpaintEnabled => config.initialFocusedInpaintEnabled;
  ImageEditorFocusedInpaintCostConfig? get focusedInpaintCostConfig =>
      config.focusedInpaintCostConfig;
  bool get showMaskExport => config.showMaskExport;
  bool get supportsFocusOutpaint => config.supportsFocusOutpaint;
  Rect? get existingFrameRect => config.existingFrameRect;
  ImageEditorMode get mode => config.mode;
  String get title => config.title;
  String? get completionLabel => config.completionLabel;
  bool get initialOutpaintCommitPending =>
      config.debugOptions.initialOutpaintCommitPending;
  bool get initialShowLayerPanel => config.debugOptions.initialShowLayerPanel;
  bool get debugDisableDropRegion => config.debugOptions.disableDropRegion;
  EfficientVitSamSelector? get debugEfficientVitSamSelector =>
      config.debugOptions.efficientVitSamSelector;

  @override
  State<ImageEditorWorkspace> createState() => ImageEditorWorkspaceState();
}

class ImageEditorWorkspaceState extends State<ImageEditorWorkspace> {
  ImageEditorController get _controller => widget.controller;
  EditorState get _state => _controller.editorState;
  bool get _isInitialized => _controller.isInitialized;
  set _isInitialized(bool value) => _controller.isInitialized = value;
  bool get _didStartInitialization => _controller.didStartInitialization;
  set _didStartInitialization(bool value) =>
      _controller.didStartInitialization = value;
  bool get _isOutpaintCommitPending => _controller.isOutpaintCommitPending;
  bool get _hasOutpaintChanges => _frameController.hasOutpaintChanges;
  bool get _isImportingDroppedImage => _controller.isImportingDroppedImage;

  bool _showLayerPanel = true;

  late final ImageEditorEffectsController _effectsController;
  late final MagicWandController _magicWandController;
  late final EditorFrameController _frameController;
  late final EditorCompressionController _compressionController;
  late final EditorCanvasResizeController _canvasResizeController;
  late final EditorResultExporter _resultExporter;
  late final EditorExitCoordinator _exitCoordinator;
  late final InpaintMaskActionsController _maskActionsController;
  late final EditorSessionInitializer _sessionInitializer;
  late final ImageLayerSource _imageSource = ImageLayerSource(
    _state.layerManager,
  );

  bool get _isInpaintMode => widget.mode == ImageEditorMode.inpaint;
  bool get _canExportAndClose =>
      !_isOutpaintCommitPending && !_frameController.isCroppingToFrame;

  Size get debugCanvasSize => _state.canvasSize;
  Rect get debugFrame => _state.frame;
  Size get debugCompressionTargetSize => Size(
    _compressionController.activeTarget.width.toDouble(),
    _compressionController.activeTarget.height.toDouble(),
  );
  int get debugCompressionTargetCount =>
      _compressionController.plan?.targets.length ?? 0;
  bool get debugCompressionApplied => _compressionController.compressionApplied;
  void debugSetCompressionTargetIndex(int index) =>
      _selectCompressionTarget(index);
  bool get debugFocusedInpaintEnabled => _controller.focusedInpaintEnabled;
  bool get debugHasOutpaintChanges => _hasOutpaintChanges;
  bool get debugOutpaintCommitPending => _isOutpaintCommitPending;
  List<Rect> get debugVirtualOutpaintMaskRects =>
      _frameController.outpaintMaskRects;
  int? get debugOutpaintSourceWidth => _controller.outpaintSourceWidth;
  int? get debugOutpaintSourceHeight => _controller.outpaintSourceHeight;
  String? get debugCurrentToolId => _state.currentTool?.id;
  String? get debugActiveLayerId => _state.layerManager.activeLayerId;
  String? get debugActiveLayerName => _state.layerManager.activeLayer?.name;
  int get debugActiveLayerStrokeCount =>
      _state.layerManager.activeLayer?.strokes.length ?? 0;
  bool get debugIsDrawing => _state.isDrawing;
  bool get debugActiveLayerHasBaseImage =>
      _state.layerManager.activeLayer?.hasBaseImage ?? false;
  int get debugCurrentStrokePointCount => _state.currentStrokePoints.length;
  bool get debugHasMaskContent => _resultExporter.hasMaskContent();
  bool get debugMagicWandProcessing => _magicWandController.snapshot.processing;

  Future<void> debugApplyMagicWand(
    Offset canvasPoint, {
    MagicWandSelectionMode mode = MagicWandSelectionMode.colorArea,
    int tolerance = 32,
    bool invert = false,
  }) => _magicWandController.apply(
    context,
    canvasPoint,
    mode: mode,
    tolerance: tolerance,
    invert: invert,
  );

  bool debugUndo() => _state.undo();
  Offset debugCanvasToScreen(Offset point) =>
      _state.canvasController.canvasToScreen(point, frame: _state.frame);
  Rect? get debugFocusedRect => _controller.focusedSelectionState.committedRect;
  Rect? get debugSelectionBounds => _state.selectionPath?.getBounds();
  Rect? get debugPreviewBounds => _state.previewPath?.getBounds();
  List<String> get debugLayerNames =>
      _state.layerManager.layers.map((layer) => layer.name).toList();

  Future<void> debugApplyOutpaintEdges(
    OutpaintEdges edges, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _applyOutpaintEdges(
    edges,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
  );

  Future<void> debugApplyOutpaintFrameDelta(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _applyOutpaintFrameDelta(
    delta,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
  );

  Future<void> debugExportAndClose() => _exportAndClose();

  Future<void> debugImportDroppedImageLayer(
    String fileName,
    Uint8List imageBytes,
  ) => importDroppedImageLayer(
    context,
    fileName,
    imageBytes,
    state: _state,
    isMounted: () => mounted,
    updateState: setState,
  );

  void debugSetToolById(String toolId) => _state.setToolById(toolId);
  void debugSetSelectionRect(Rect rect) =>
      _state.setSelection(Path()..addRect(rect), saveHistory: false);
  void debugSetPreviewRect(Rect rect) =>
      _state.setPreviewPath(Path()..addRect(rect));

  static void debugShowShortcutHelpForContext(
    BuildContext context, {
    bool includeFrameTool = false,
    bool includeCloneStamp = true,
  }) {
    presentEditorShortcutHelp(
      context,
      includeFrameTool: includeFrameTool,
      includeCloneStamp: includeCloneStamp,
    );
  }

  String _editorTitle() =>
      widget.title.isEmpty ? context.l10n.editor_defaultTitle : widget.title;

  /// 图层角色变化后当前工具可能不再可用，退回画笔
  void _handleActiveLayerChanged() {
    final tool = _state.currentTool;
    if (tool != null && !tool.isAvailableIn(_state)) {
      _state.setToolById('brush');
    }
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _effectsController = ImageEditorEffectsController(
      session: _controller,
      editorState: _state,
    );
    _magicWandController = MagicWandController(
      session: _controller,
      editorState: _state,
      config: widget.config,
    );
    _controller.initializeSession(
      canvasSize: const Size(1024, 1024),
      initialFocusRect: widget.existingFocusRect,
      minimumContextMegaPixels: widget.initialMinimumContextMegaPixels.clamp(
        16.0,
        192.0,
      ),
      focusedInpaintEnabled:
          widget.initialFocusedInpaintEnabled ||
          widget.existingFocusRect != null,
      outpaintCommitPending: widget.initialOutpaintCommitPending,
    );
    _frameController = EditorFrameController(
      session: _controller,
      editorState: _state,
    );
    _compressionController = EditorCompressionController(
      session: () => _controller,
      config: () => widget.config,
      frameController: _frameController,
    );
    _canvasResizeController = EditorCanvasResizeController(
      session: () => _controller,
      config: () => widget.config,
      frameController: _frameController,
      compressionController: _compressionController,
    );
    _resultExporter = EditorResultExporter(
      session: () => _controller,
      config: () => widget.config,
      frameController: _frameController,
      imageSource: _imageSource,
      compressionController: _compressionController,
    );
    _exitCoordinator = EditorExitCoordinator(
      session: () => _controller,
      resultExporter: _resultExporter,
    );
    _maskActionsController = InpaintMaskActionsController(
      session: () => _controller,
      config: () => widget.config,
      compressionController: _compressionController,
    );
    _sessionInitializer = EditorSessionInitializer(
      session: () => _controller,
      config: () => widget.config,
      frameController: _frameController,
      imageSource: _imageSource,
      compressionController: _compressionController,
    );
    if (_isInpaintMode) {
      _state.setFrameCommands(_frameController);
      _frameController.supportsPasteBack =
          widget.supportsFocusOutpaint && widget.showMaskExport;
    }
    _state.frameNotifier.addListener(_handleFrameChanged);
    _state.layerManager.addListener(_handleLayersChanged);
    _state.layerManager.activeLayerNotifier.addListener(
      _handleActiveLayerChanged,
    );
    if (_isInpaintMode) {
      _state.setClosedRegionFillHandler(_fillClosedMaskRegionsAt);
    }
    _state.setMagicWandHandler(
      (point, {required mode, required tolerance, required invert}) =>
          _magicWandController.apply(
            context,
            point,
            mode: mode,
            tolerance: tolerance,
            invert: invert,
          ),
    );
    _state.selectionManager.selectionNotifier.addListener(
      _consumeFocusedSelection,
    );
    _compressionController.syncFocusedSelectionConstraint();
    _showLayerPanel = widget.initialShowLayerPanel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStartInitialization) {
      _didStartInitialization = true;
      unawaited(
        _sessionInitializer.initializeCanvas(
          context,
          isMounted: () => mounted,
          onMarkInitialized: () => setState(() => _isInitialized = true),
        ),
      );
    }
  }

  @override
  void dispose() {
    _magicWandController.dispose();
    _state.selectionManager.selectionNotifier.removeListener(
      _consumeFocusedSelection,
    );
    _state.setMagicWandHandler(null);
    _state.setClosedRegionFillHandler(null);
    _state.frameNotifier.removeListener(_handleFrameChanged);
    _state.layerManager.removeListener(_handleLayersChanged);
    _state.layerManager.activeLayerNotifier.removeListener(
      _handleActiveLayerChanged,
    );
    _state.setFrameCommands(null);
    _frameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(_editorTitle())),
        body: Center(
          child: CircularProgressIndicator(
            value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
          ),
        ),
      );
    }

    return PopScope<ImageEditorResult>(
      canPop: _exitCoordinator.allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: EditorImageDropRegion(
        disableDropRegion: widget.debugDisableDropRegion,
        isImporting: () => _isImportingDroppedImage,
        onPerformDrop: _handleDroppedImageLayerDrop,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sizeClass = AdaptiveBreakpoints.classifyWidth(
              constraints.maxWidth,
            );
            final hasLargeText =
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final useDesktopLayout =
                sizeClass.isExpandedOrWider &&
                constraints.maxHeight >= 480 &&
                !hasLargeText;
            return useDesktopLayout
                ? WorkspaceDesktopLayout(
                    availableWidth: constraints.maxWidth,
                    title: _editorTitle(),
                    completionLabel: widget.completionLabel,
                    state: _state,
                    isInpaintMode: _isInpaintMode,
                    showLayerPanel: _showLayerPanel,
                    frameController: _frameController,
                    compressionController: _compressionController,
                    canExportAndClose: () => _canExportAndClose,
                    buildCanvasArea: _buildCanvasArea,
                    onConfirmExit: _confirmExit,
                    onSelectCompressionTarget: _selectCompressionTarget,
                    onShowCompressionSheet: _showCompressionSheet,
                    onShowEffectsDialog: _showEffectsDialog,
                    onChangeCanvasSize: _changeCanvasSize,
                    onLoadMask: _loadMask,
                    onShowShiftEdgesDialog: _showShiftEdgesDialog,
                    onCropToFrame: _cropToFrame,
                    onToggleLayerPanel: () {
                      _updateLayoutState(() {
                        _showLayerPanel = !_showLayerPanel;
                      });
                    },
                    onShowShortcutHelp: _showShortcutHelp,
                    onExportAndClose: _exportAndClose,
                    onResetInpaintMask: _resetInpaintMask,
                  )
                : WorkspaceMobileLayout(
                    availableWidth: constraints.maxWidth,
                    title: _editorTitle(),
                    completionLabel: widget.completionLabel,
                    state: _state,
                    isInpaintMode: _isInpaintMode,
                    frameController: _frameController,
                    canExportAndClose: () => _canExportAndClose,
                    buildCanvasArea: _buildCanvasArea,
                    onShowLayerSheet: _showMobileLayerSheet,
                    onShowCompressionSheet: _showCompressionSheet,
                    onLoadMask: _loadMask,
                    onShowShiftEdgesDialog: _showShiftEdgesDialog,
                    onCropToFrame: _cropToFrame,
                    onShowEffectsDialog: _showEffectsDialog,
                    onExportAndClose: _exportAndClose,
                    onResetInpaintMask: _resetInpaintMask,
                  );
          },
        ),
      ),
    );
  }

  Widget _buildCanvasArea() => WorkspaceCanvasStack(
    session: _controller,
    state: _state,
    isInpaintMode: _isInpaintMode,
    frameController: _frameController,
    magicWandController: _magicWandController,
    compressionController: _compressionController,
    onApplyOutpaintEdges: _applyOutpaintEdges,
    onApplyOutpaintFrameDelta: _applyOutpaintFrameDelta,
    onToggleFocusedInpaint: _toggleFocusedInpaint,
    onClearFocusedSelection: () {
      _updateLayoutState(_compressionController.clearFocusedSelection);
    },
    onMinimumContextChanged: (value) {
      _updateLayoutState(
        () => _compressionController.updateMinimumContextMegaPixels(value),
      );
    },
  );

  void _updateLayoutState(VoidCallback update) => setState(update);

  void _selectCompressionTarget(int index) {
    if (!_compressionController.canSelectTarget) return;
    _updateLayoutState(() => _compressionController.selectTargetAt(index));
  }

  Future<void> _showCompressionSheet() {
    return showEditorCompressionSheet(
      context,
      controller: _compressionController,
      onSelectTarget: _selectCompressionTarget,
    );
  }

  Future<void> _showMobileLayerSheet() =>
      showWorkspaceMobileLayerSheet(context, _state);

  Future<void> _showEffectsDialog() => _effectsController.showDialog(
    context,
    onChanged: () => _updateLayoutState(() {}),
  );

  void _showShortcutHelp() => presentEditorShortcutHelp(
    context,
    includeFrameTool: _isInpaintMode,
    includeCloneStamp: !_isInpaintMode,
  );

  void _toggleFocusedInpaint() {
    if (_hasOutpaintChanges && !_controller.focusedInpaintEnabled) {
      AppToast.warning(
        context,
        'Outpaint cannot be used together with Focused Inpaint.',
      );
      return;
    }
    _updateLayoutState(_compressionController.toggleFocusedInpaint);
  }

  void _consumeFocusedSelection() {
    if (!_compressionController.consumeFocusedSelection()) return;
    if (mounted) {
      _updateLayoutState(() {});
    }
  }

  Future<void> _fillClosedMaskRegionsAt(Offset canvasPoint) =>
      _maskActionsController.fillClosedMaskRegionsAt(
        context,
        canvasPoint,
        isMounted: () => mounted,
      );

  Future<void> _loadMask() =>
      _maskActionsController.loadMaskFile(context, isMounted: () => mounted);

  void _resetInpaintMask() {
    if (_maskActionsController.resetInpaintMask(context)) {
      setState(() {});
    }
  }

  Future<void> _changeCanvasSize() =>
      _canvasResizeController.changeCanvasSize(context);

  Future<void> _cropToFrame() =>
      cropToFrameWithFeedback(context, _frameController);

  Future<void> _showShiftEdgesDialog() => _canvasResizeController
      .showShiftEdgesDialog(context, isMounted: () => mounted);

  Future<void> _applyOutpaintEdges(
    OutpaintEdges edges, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _canvasResizeController.applyOutpaintEdges(
    context,
    edges,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
    isMounted: () => mounted,
  );

  Future<void> _applyOutpaintFrameDelta(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) => _canvasResizeController.applyOutpaintFrameDelta(
    context,
    delta,
    horizontalSnapTarget: horizontalSnapTarget,
    verticalSnapTarget: verticalSnapTarget,
    isMounted: () => mounted,
  );

  void _handleFrameChanged() {
    if (_canvasResizeController.syncOnFrameChanged() && mounted) {
      setState(() {});
    }
  }

  void _handleLayersChanged() {
    if (_compressionController.refreshOnLayersChangedIfNeeded() && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleDroppedImageLayerDrop(PerformDropEvent event) =>
      handleDroppedImageLayerDrop(
        context,
        event,
        session: _controller,
        state: _state,
        isMounted: () => mounted,
        updateState: setState,
      );

  Future<void> _confirmExit() => _exitCoordinator.confirmExit(
    context,
    canExportAndClose: () => _canExportAndClose,
    isMounted: () => mounted,
    updateState: setState,
  );

  Future<void> _exportAndClose() => _exitCoordinator.exportAndClose(
    context,
    canExportAndClose: () => _canExportAndClose,
    isMounted: () => mounted,
    updateState: setState,
  );
}
