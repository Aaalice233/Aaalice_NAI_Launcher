import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/editor_compression_utils.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/inpaint_mask_utils.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../../data/services/efficient_vit_sam_service.dart';
import '../../adaptive/adaptive_layout.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../utils/dropped_file_reader.dart';
import '../../utils/internal_drag_protocol.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/common/app_toast.dart';
import 'document_transaction.dart';
import 'controllers/magic_wand_controller.dart';
import 'core/canvas_controller.dart';
import 'core/editor_state.dart';
import 'effects/image_editor_effects_controller.dart';
import 'core/focused_selection_state.dart';
import 'layers/layer.dart';
import 'painters/focused_overlay_painter.dart';
import 'tools/tool_base.dart';
import 'canvas/editor_canvas.dart';
import 'widgets/toolbar/desktop_toolbar.dart';
import 'widgets/toolbar/mobile_toolbar.dart';
import 'widgets/panels/layer_panel.dart';
import 'widgets/panels/color_panel.dart';
import 'widgets/panels/canvas_size_dialog.dart';
import 'widgets/panels/shift_edges_dialog.dart';
import 'widgets/outpaint_edge_drag_overlay.dart';
import 'widgets/magic_wand_progress_overlay.dart';
import 'canvas/layer_painter.dart';
import 'export/image_exporter_new.dart';
import '../../widgets/common/themed_divider.dart';
import 'image_editor_controller.dart';
import 'image_editor_types.dart';

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
  ImageEditorMode get mode => config.mode;
  String get title => config.title;
  String? get completionLabel => config.completionLabel;
  bool get initialOutpaintCommitPending =>
      config.debugOptions.initialOutpaintCommitPending;
  bool get initialShowLayerPanel => config.debugOptions.initialShowLayerPanel;
  bool get debugFailOutpaintSourceReplacement =>
      config.debugOptions.failOutpaintSourceReplacement;
  bool get debugFailOutpaintAfterFocusedDisable =>
      config.debugOptions.failOutpaintAfterFocusedDisable;
  bool get debugDisableDropRegion => config.debugOptions.disableDropRegion;
  EfficientVitSamSelector? get debugEfficientVitSamSelector =>
      config.debugOptions.efficientVitSamSelector;

  @override
  State<ImageEditorWorkspace> createState() => ImageEditorWorkspaceState();
}

class ImageEditorWorkspaceState extends State<ImageEditorWorkspace> {
  static const bool _useVirtualOutpaint = true;
  static const int _maxImportedImageBytes = 50 * 1024 * 1024;
  static const Set<String> _inpaintToolIds = {
    'brush',
    'eraser',
    'fill',
    'magic_wand',
    'rect_selection',
    'ellipse_selection',
    'lasso_selection',
  };

  ImageEditorController get _controller => widget.controller;
  EditorState get _state => _controller.editorState;
  FocusedSelectionState get _focusedSelectionState =>
      _controller.focusedSelectionState;
  double get _minimumContextMegaPixels => _controller.minimumContextMegaPixels;
  set _minimumContextMegaPixels(double value) =>
      _controller.minimumContextMegaPixels = value;
  bool get _focusedInpaintEnabled => _controller.focusedInpaintEnabled;
  set _focusedInpaintEnabled(bool value) =>
      _controller.focusedInpaintEnabled = value;
  EditorCompressionPlan? get _compressionPlan => _controller.compressionPlan;
  set _compressionPlan(EditorCompressionPlan? value) =>
      _controller.compressionPlan = value;
  EditorCompressionTarget? get _compressionTarget =>
      _controller.compressionTarget;
  set _compressionTarget(EditorCompressionTarget? value) =>
      _controller.compressionTarget = value;
  bool get _isInitialized => _controller.isInitialized;
  set _isInitialized(bool value) => _controller.isInitialized = value;
  bool get _didStartInitialization => _controller.didStartInitialization;
  set _didStartInitialization(bool value) =>
      _controller.didStartInitialization = value;
  bool get _isOutpaintCommitPending => _controller.isOutpaintCommitPending;
  set _isOutpaintCommitPending(bool value) =>
      _controller.isOutpaintCommitPending = value;
  String? get _sourceLayerId => _controller.sourceLayerId;
  set _sourceLayerId(String? value) => _controller.sourceLayerId = value;
  Uint8List? get _outpaintSourceImage => _controller.outpaintSourceImage;
  set _outpaintSourceImage(Uint8List? value) =>
      _controller.outpaintSourceImage = value;
  int? get _outpaintSourceWidth => _controller.outpaintSourceWidth;
  set _outpaintSourceWidth(int? value) =>
      _controller.outpaintSourceWidth = value;
  int? get _outpaintSourceHeight => _controller.outpaintSourceHeight;
  set _outpaintSourceHeight(int? value) =>
      _controller.outpaintSourceHeight = value;
  Uint8List? get _inpaintWorkingSourceImage =>
      _controller.inpaintWorkingSourceImage;
  set _inpaintWorkingSourceImage(Uint8List? value) =>
      _controller.inpaintWorkingSourceImage = value;
  int? get _inpaintWorkingSourceWidth => _controller.inpaintWorkingSourceWidth;
  set _inpaintWorkingSourceWidth(int? value) =>
      _controller.inpaintWorkingSourceWidth = value;
  int? get _inpaintWorkingSourceHeight =>
      _controller.inpaintWorkingSourceHeight;
  set _inpaintWorkingSourceHeight(int? value) =>
      _controller.inpaintWorkingSourceHeight = value;
  int? get _initialSourceWidth => _controller.initialSourceWidth;
  set _initialSourceWidth(int? value) => _controller.initialSourceWidth = value;
  int? get _initialSourceHeight => _controller.initialSourceHeight;
  set _initialSourceHeight(int? value) =>
      _controller.initialSourceHeight = value;
  bool get _sourceWasNormalized => _controller.sourceWasNormalized;
  set _sourceWasNormalized(bool value) =>
      _controller.sourceWasNormalized = value;
  OutpaintVirtualFrame? get _virtualOutpaintFrame =>
      _controller.virtualOutpaintFrame;
  set _virtualOutpaintFrame(OutpaintVirtualFrame? value) =>
      _controller.virtualOutpaintFrame = value;
  bool get _hasOutpaintChanges => _controller.hasOutpaintChanges;
  set _hasOutpaintChanges(bool value) => _controller.hasOutpaintChanges = value;
  bool get _isImportingDroppedImage => _controller.isImportingDroppedImage;
  set _isImportingDroppedImage(bool value) =>
      _controller.isImportingDroppedImage = value;
  bool _isMaskFillMode = false;
  bool _showLayerPanel = true;
  bool _allowRoutePop = false;
  bool _exitDialogVisible = false;
  late final ImageEditorEffectsController _effectsController;
  late final MagicWandController _magicWandController;

  bool get _isInpaintMode => widget.mode == ImageEditorMode.inpaint;
  bool get _canExportAndClose => !_isOutpaintCommitPending;

  OutpaintVirtualFrame get _effectiveOutpaintFrame {
    return _virtualOutpaintFrame ??
        OutpaintVirtualFrame.fromSource(
          sourceWidth: _state.canvasSize.width.round(),
          sourceHeight: _state.canvasSize.height.round(),
        );
  }

  Size get debugCanvasSize => _state.canvasSize;

  Size get debugCompressionTargetSize => Size(
    _activeCompressionTarget.width.toDouble(),
    _activeCompressionTarget.height.toDouble(),
  );

  int get debugCompressionTargetCount => _compressionPlan?.targets.length ?? 0;

  bool get debugCompressionApplied => _compressionApplied;

  void debugSetCompressionTargetIndex(int index) {
    _selectCompressionTarget(index);
  }

  bool get debugFocusedInpaintEnabled => _focusedInpaintEnabled;

  bool get debugHasOutpaintChanges => _hasOutpaintChanges;

  bool get debugOutpaintCommitPending => _isOutpaintCommitPending;

  List<Rect> get debugVirtualOutpaintMaskRects {
    return _virtualOutpaintFrame?.outpaintMaskRects ?? const [];
  }

  int? get debugOutpaintSourceWidth => _outpaintSourceWidth;

  int? get debugOutpaintSourceHeight => _outpaintSourceHeight;

  String? get debugCurrentToolId => _state.currentTool?.id;

  String? get debugActiveLayerId => _state.layerManager.activeLayerId;

  String? get debugActiveLayerName => _state.layerManager.activeLayer?.name;

  int get debugActiveLayerStrokeCount {
    return _state.layerManager.activeLayer?.strokes.length ?? 0;
  }

  bool get debugIsDrawing => _state.isDrawing;

  bool get debugActiveLayerHasBaseImage =>
      _state.layerManager.activeLayer?.hasBaseImage ?? false;

  int get debugCurrentStrokePointCount => _state.currentStrokePoints.length;

  bool get debugHasMaskContent => _hasMaskContent();

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

  Offset debugCanvasToScreen(Offset point) {
    return _state.canvasController.canvasToScreen(
      point,
      canvasSize: _state.canvasSize,
    );
  }

  Rect? get debugFocusedRect => _focusedSelectionState.committedRect;

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
  }) {
    return _applyOutpaintEdges(
      edges,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
  }

  Future<void> debugApplyOutpaintFrameDelta(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) {
    return _applyOutpaintFrameDelta(
      delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
  }

  Future<void> debugApplyOutpaintFrameDeltaMaterialized(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) {
    return _applyOutpaintFrameDeltaMaterialized(
      delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
  }

  Future<void> debugExportAndClose() => _exportAndClose();

  Future<void> debugImportDroppedImageLayer(
    String fileName,
    Uint8List imageBytes,
  ) {
    return _importDroppedImageLayer(fileName, imageBytes);
  }

  void debugSetToolById(String toolId) {
    _state.setToolById(toolId);
  }

  void debugSetSelectionRect(Rect rect) {
    _state.setSelection(Path()..addRect(rect), saveHistory: false);
  }

  void debugSetPreviewRect(Rect rect) {
    _state.setPreviewPath(Path()..addRect(rect));
  }

  String _editorTitle() =>
      widget.title.isEmpty ? context.l10n.editor_defaultTitle : widget.title;

  void _localizeDefaultLayerName() {
    for (final layer in _state.layerManager.layers) {
      if (layer.name == '\u56fe\u5c42 1' || layer.name == 'Layer 1') {
        _state.layerManager.renameLayer(
          layer.id,
          context.l10n.editor_defaultDrawingLayerName,
        );
        return;
      }
    }
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
      addMaskLayer: (name) => _addEmptyMaskLayerAboveSource(name: name),
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
    _syncFocusedSelectionConstraint();
    _showLayerPanel = widget.initialShowLayerPanel;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didStartInitialization) {
      _didStartInitialization = true;
      unawaited(_initializeCanvas());
    }
  }

  Future<void> _initializeCanvas() async {
    final operationEpoch = _controller.beginOperation();
    if (widget.initialImage != null) {
      // 从已有图像初始化
      await _loadInitialImage(operationEpoch);
    } else {
      // 显示尺寸选择对话框或使用默认尺寸
      final size = widget.initialSize ?? const Size(1024, 1024);
      _state.initNewCanvas(
        size,
        initialLayerName: context.l10n.editor_defaultDrawingLayerName,
      );
      _localizeDefaultLayerName();
      _focusedSelectionState.canvasSize = size;

      // 加载已有蒙版（如果有）
      await _loadExistingMask();
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      _loadExistingFocusSelection();
    }

    if (!mounted || !_controller.accepts(operationEpoch)) return;
    _initializeCompressionPlan();

    setState(() {
      _isInitialized = true;
    });

    if (_isInpaintMode) {
      _state.setForegroundColor(const Color(0xFF60AAFF));
      _state.setBrushOpacity(0.55);
      _state.setBrushHardness(1.0);
      _state.setToolById(
        _focusedInpaintEnabled && widget.existingFocusRect == null
            ? 'rect_selection'
            : 'brush',
      );
    }

    // 适应视口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.canvasController.fitToViewport(_state.canvasSize);
    });
  }

  Future<void> _loadInitialImage(int operationEpoch) async {
    final defaultDrawingLayerName = context.l10n.editor_defaultDrawingLayerName;
    final baseLayerName = context.l10n.editor_baseLayerName;
    ui.Codec? codec;
    ui.Image? decodedImage;
    try {
      final editorImage = await NaiResolutionAdapter.prepareImageForEditorAsync(
        widget.initialImage!,
        alignForInpaint: _isInpaintMode,
      );
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      var workingBytes = editorImage?.bytes ?? widget.initialImage!;
      if (editorImage?.resizeMode == NaiEditorResizeMode.medium) {
        workingBytes = await _resizeEditorImageWithMedium(
          workingBytes,
          width: editorImage!.width,
          height: editorImage.height,
        );
        if (!mounted || !_controller.accepts(operationEpoch)) return;
      }
      _initialSourceWidth = editorImage?.originalWidth;
      _initialSourceHeight = editorImage?.originalHeight;
      _sourceWasNormalized = editorImage?.wasNormalized ?? false;
      if (_isInpaintMode) {
        _inpaintWorkingSourceImage = workingBytes;
        _inpaintWorkingSourceWidth = editorImage?.width;
        _inpaintWorkingSourceHeight = editorImage?.height;
      }

      codec = await ui.instantiateImageCodec(workingBytes);
      final frame = await codec.getNextFrame();
      decodedImage = frame.image;
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      final image = decodedImage;
      _initialSourceWidth ??= image.width;
      _initialSourceHeight ??= image.height;
      _inpaintWorkingSourceWidth ??= image.width;
      _inpaintWorkingSourceHeight ??= image.height;

      _state.initNewCanvas(
        Size(image.width.toDouble(), image.height.toDouble()),
        initialLayerName: defaultDrawingLayerName,
      );
      _focusedSelectionState.canvasSize = _state.canvasSize;

      // 将图像添加为底图图层
      final sourceLayer = await _state.layerManager.addLayerFromImage(
        workingBytes,
        name: baseLayerName,
      );
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      _sourceLayerId = sourceLayer?.id;
      if (_isInpaintMode && sourceLayer != null) {
        _virtualOutpaintFrame = OutpaintVirtualFrame.fromSource(
          sourceWidth: image.width,
          sourceHeight: image.height,
        );
      }
      if (_isInpaintMode && sourceLayer != null) {
        sourceLayer.locked = true;
      }

      _localizeDefaultLayerName();

      // Select the default drawing layer rather than the base image layer.
      final layer1 = _state.layerManager.layers.firstWhere(
        (l) => l.name == defaultDrawingLayerName,
        orElse: () => _state.layerManager.layers.last,
      );
      _state.layerManager.setActiveLayer(layer1.id);

      // 加载已有蒙版
      await _loadExistingMask();
      _loadExistingFocusSelection();
    } catch (e) {
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      AppLogger.w('Failed to load initial image: $e', 'ImageEditor');
      _state.initNewCanvas(
        widget.initialSize ?? const Size(1024, 1024),
        initialLayerName: defaultDrawingLayerName,
      );
      _localizeDefaultLayerName();
      _focusedSelectionState.canvasSize = _state.canvasSize;
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
    return _controller.processingService.resize(
      sourceBytes,
      width: width,
      height: height,
    );
  }

  Future<void> _loadExistingMask() async {
    if (widget.existingMask == null) return;

    try {
      final resizedMask = InpaintMaskUtils.resizeMaskBytes(
        widget.existingMask!,
        targetWidth: _state.canvasSize.width.round(),
        targetHeight: _state.canvasSize.height.round(),
      );
      final overlayBytes = InpaintMaskUtils.maskToEditorOverlay(resizedMask);

      // 将已有蒙版添加为图层
      final layer = await _addMaskLayerAboveSource(
        overlayBytes,
        name: context.l10n.editor_existingMaskLayerName,
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
    if (!_isInpaintMode || widget.existingFocusRect == null) {
      return;
    }
    final sourceWidth = _initialSourceWidth;
    final sourceHeight = _initialSourceHeight;
    final rect = widget.existingFocusRect!;
    if (sourceWidth == null || sourceHeight == null) {
      _focusedSelectionState.load(rect);
      _constrainCommittedFocusedSelection();
      return;
    }
    _focusedSelectionState.load(
      Rect.fromLTRB(
        rect.left * _state.canvasSize.width / sourceWidth,
        rect.top * _state.canvasSize.height / sourceHeight,
        rect.right * _state.canvasSize.width / sourceWidth,
        rect.bottom * _state.canvasSize.height / sourceHeight,
      ),
    );
    _constrainCommittedFocusedSelection();
  }

  @override
  void dispose() {
    _magicWandController.dispose();
    _state.selectionManager.selectionNotifier.removeListener(
      _consumeFocusedSelection,
    );
    _state.setMagicWandHandler(null);
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
      canPop: _allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: _buildDroppedImageLayerRegion(
        LayoutBuilder(
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
                ? _buildDesktopLayout(availableWidth: constraints.maxWidth)
                : _buildMobileLayout(availableWidth: constraints.maxWidth);
          },
        ),
      ),
    );
  }

  void _updateLayoutState(VoidCallback update) => setState(update);

  Future<void> _changeCanvasSize() async {
    final l10n = context.l10n;
    final compressionScale = _compressionLinearScale;
    final result = await CanvasSizeDialog.show(
      context,
      initialSize: _state.canvasSize,
      title: l10n.editor_changeCanvasSize,
    );

    if (result != null && result.size != _state.canvasSize) {
      try {
        // 验证尺寸范围
        final newWidth = result.size.width.toInt();
        final newHeight = result.size.height.toInt();
        const minSize = 64;
        const maxSize = 4096;

        if (newWidth < minSize || newHeight < minSize) {
          _showError(l10n.editor_canvasTooSmall(minSize, minSize));
          return;
        }

        if (newWidth > maxSize || newHeight > maxSize) {
          _showError(l10n.editor_canvasTooLarge(maxSize, maxSize));
          return;
        }

        // 将 ContentHandlingMode 转换为 CanvasResizeMode
        final mode = _convertContentModeToResizeMode(result.mode);

        // 使用新的 resizeCanvas 方法，支持图层内容变换
        _state.resizeCanvas(result.size, mode);
        _focusedSelectionState.canvasSize = result.size;
        _refreshCompressionPlan(desiredScale: compressionScale);
        _constrainCommittedFocusedSelection();
        _refreshCompressionPlan();

        // 显示成功消息
        if (mounted) {
          AppToast.success(
            context,
            l10n.editor_canvasResized(newWidth, newHeight),
          );
        }
      } catch (e) {
        // 显示错误信息
        _showError(l10n.editor_canvasResizeFailed(e));
        AppLogger.e('Failed to resize canvas: $e', 'ImageEditor');
      }
    }
  }

  Future<void> _showShiftEdgesDialog() async {
    if (!_isInpaintMode) return;
    final result = await ShiftEdgesDialog.show(
      context,
      sourceWidth: _state.canvasSize.width.round(),
      sourceHeight: _state.canvasSize.height.round(),
    );
    if (result == null || !mounted) return;
    await _applyOutpaintEdges(
      result.requestedEdges,
      horizontalSnapTarget: result.horizontalSnapTarget,
      verticalSnapTarget: result.verticalSnapTarget,
    );
  }

  /// 显示错误消息
  void _showError(String message) {
    if (mounted) {
      AppToast.error(context, message);
    }
  }

  /// 将内容处理模式转换为画布调整模式
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

  Future<void> _completeAndPop([ImageEditorResult? result]) async {
    if (!mounted) return;
    setState(() => _allowRoutePop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  /// 确认退出
  Future<void> _confirmExit() async {
    if (_exitDialogVisible || _allowRoutePop) return;

    // 检查是否有修改：检查历史记录或图层内容
    final hasChanges =
        _state.historyManager.canUndo ||
        _state.layerManager.layers.any(
          (l) => l.strokes.isNotEmpty || l.baseImage != null,
        );

    if (hasChanges) {
      _exitDialogVisible = true;
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.editor_confirmExitTitle),
          content: Text(context.l10n.editor_confirmExitContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.common_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.editor_exit),
            ),
            FilledButton(
              onPressed: _canExportAndClose
                  ? () async {
                      Navigator.pop(context, false);
                      await _exportAndClose();
                    }
                  : null,
              child: Text(context.l10n.editor_saveAndExit),
            ),
          ],
        ),
      );
      _exitDialogVisible = false;

      if (shouldExit != true) return;
    }

    await _completeAndPop();
  }

  /// 导出并关闭
  Future<void> _exportAndClose() async {
    if (!mounted) return;
    if (!_canExportAndClose) return;

    bool loadingDialogShown = false;

    try {
      loadingDialogShown = true;
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (context) => Center(
            child: CircularProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
            ),
          ),
        ),
      );

      final target = _activeCompressionTarget;
      final compressionApplied = _compressionApplied;
      final hasCanvasImageChanges =
          _state.historyManager.canUndo ||
          _state.layerManager.layers.any((l) => l.strokes.isNotEmpty) ||
          _state.layerManager.layerCount > 1;
      final hasImageChanges =
          hasCanvasImageChanges || (!_isInpaintMode && compressionApplied);

      final virtualOutpaintMaskRects =
          _virtualOutpaintFrame?.outpaintMaskRects ?? const <Rect>[];
      final hasMaskChanges =
          _hasMaskContent() || virtualOutpaintMaskRects.isNotEmpty;
      final workFocusAreaRect = _focusedInpaintEnabled
          ? _focusedSelectionState.committedRect
          : null;
      final focusedInpaintEnabled =
          _focusedInpaintEnabled && workFocusAreaRect != null;
      final focusAreaRect = focusedInpaintEnabled
          ? _projectWorkRectToCompressionTarget(workFocusAreaRect)
          : null;
      final useFocusedSelectionAsMask =
          focusedInpaintEnabled && !hasMaskChanges;
      AppLogger.d(
        'Export editor result: inpaint=$_isInpaintMode, '
            'hasImageChanges=$hasImageChanges, hasMaskChanges=$hasMaskChanges, '
            'selection=${_state.selectionPath != null}, '
            'workFocusRect=$workFocusAreaRect, focusRect=$focusAreaRect, '
            'focusedEnabled=$focusedInpaintEnabled, '
            'useFocusedSelectionAsMask=$useFocusedSelectionAsMask, '
            'work=${_state.canvasSize.width.round()}x${_state.canvasSize.height.round()}, '
            'target=${target.width}x${target.height}, '
            'compressionApplied=$compressionApplied, '
            'layers=${_state.layerManager.layerCount}',
        'ImageEditor',
      );

      Uint8List? modifiedImage;
      if (!_isInpaintMode && hasImageChanges) {
        modifiedImage = await _exportMergedImageAtCompressionTarget();
      }

      Uint8List? maskImage;
      if (_isInpaintMode && widget.showMaskExport && hasMaskChanges) {
        maskImage = await _exportInpaintLayerMaskAtCompressionTarget(
          virtualOutpaintMaskRects,
        );
        AppLogger.d(
          'Exported inpaint mask bytes: ${maskImage.length}',
          'ImageEditor',
        );
      } else if (_isInpaintMode &&
          widget.showMaskExport &&
          useFocusedSelectionAsMask) {
        maskImage = await _exportFocusedSelectionMaskAtCompressionTarget(
          workFocusAreaRect,
        );
        AppLogger.d(
          'Exported focused selection mask bytes: ${maskImage.length}',
          'ImageEditor',
        );
      }

      final inpaintSource = _isInpaintMode
          ? await _prepareInpaintSourceAtCompressionTarget()
          : null;

      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      if (mounted) {
        await _completeAndPop(
          ImageEditorResult(
            modifiedImage: modifiedImage,
            maskImage: maskImage,
            hasImageChanges: !_isInpaintMode && hasImageChanges,
            hasMaskChanges:
                _isInpaintMode && (hasMaskChanges || useFocusedSelectionAsMask),
            focusAreaRect: focusAreaRect,
            minimumContextMegaPixels: _minimumContextMegaPixels,
            focusedInpaintEnabled: focusedInpaintEnabled,
            outpaintSourceImage: _isInpaintMode && _hasOutpaintChanges
                ? inpaintSource
                : null,
            outpaintSourceWidth: _isInpaintMode && _hasOutpaintChanges
                ? target.width
                : null,
            outpaintSourceHeight: _isInpaintMode && _hasOutpaintChanges
                ? target.height
                : null,
            hasOutpaintChanges: _isInpaintMode && _hasOutpaintChanges,
            inpaintSourceImage: _isInpaintMode && !_hasOutpaintChanges
                ? inpaintSource
                : null,
            inpaintSourceWidth: _isInpaintMode && !_hasOutpaintChanges
                ? target.width
                : null,
            inpaintSourceHeight: _isInpaintMode && !_hasOutpaintChanges
                ? target.height
                : null,
            sourceWasNormalized:
                _isInpaintMode &&
                !_hasOutpaintChanges &&
                (_sourceWasNormalized || compressionApplied),
            outputWidth: target.width,
            outputHeight: target.height,
            compressionApplied: compressionApplied,
          ),
        );
      }
    } catch (e) {
      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        AppToast.error(context, context.l10n.editor_exportFailed(e));
      }
    }
  }

  Future<Uint8List?> _materializeVirtualOutpaintSourceIfNeeded({
    int? targetWidth,
    int? targetHeight,
  }) async {
    final frame = _virtualOutpaintFrame;
    final sourceLayerId = _sourceLayerId;
    if (!_isInpaintMode || frame == null || !frame.hasOutpaintChanges) {
      return _outpaintSourceImage;
    }
    if (sourceLayerId == null) {
      throw Exception('Unable to read current source image.');
    }
    final sourceLayer = _state.layerManager.getLayerById(sourceLayerId);
    final sourceBytes = sourceLayer?.baseImageBytes;
    if (sourceBytes == null) {
      throw Exception('Unable to read current source image.');
    }
    final result = await _controller.processingService.materializeOutpaint(
      sourceImage: sourceBytes,
      frame: frame,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    _outpaintSourceImage = result.sourceImage;
    _outpaintSourceWidth = result.width;
    _outpaintSourceHeight = result.height;
    return result.sourceImage;
  }

  bool _hasMaskContent() {
    for (final layer in _state.layerManager.layers) {
      if (!layer.visible || layer.id == _sourceLayerId) {
        continue;
      }
      if (layer.hasBaseImage || layer.strokes.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _handleFillClosedMaskRegions() {
    if (!_isInpaintMode) {
      return;
    }

    setState(() {
      _isMaskFillMode = !_isMaskFillMode;
    });

    if (_isMaskFillMode) {
      AppToast.info(context, context.l10n.editor_clickInsideClosedRegion);
    }
  }

  Future<void> _fillClosedMaskRegionsAt(Offset localPosition) async {
    if (!_isInpaintMode || !mounted) {
      return;
    }
    final l10n = context.l10n;
    final maskLayerName = l10n.editor_maskLayerName;

    try {
      final canvasPoint = _state.canvasController.screenToCanvas(
        localPosition,
        canvasSize: _state.canvasSize,
      );
      final originalMask = await ImageExporterNew.exportMaskFromLayers(
        _state.layerManager,
        _state.canvasSize,
        excludedBaseImageLayerIds: {
          if (_sourceLayerId != null) _sourceLayerId!,
        },
        forceHardEdges: true,
        preferCpuHardEdgeExport: true,
      );
      if (!mounted) {
        return;
      }

      final fillResult =
          await InpaintMaskUtils.fillEditorMaskRegionAtPointAsync(
            originalMask,
            x: canvasPoint.dx.floor(),
            y: canvasPoint.dy.floor(),
          );
      if (!mounted) {
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

      final overlayBytes = fillResult.overlayBytes;
      if (overlayBytes == null) {
        throw Exception(l10n.editor_generateMaskOverlayFailed);
      }
      _removeAllMaskLayers();
      final layer = await _addMaskLayerAboveSource(
        overlayBytes,
        name: maskLayerName,
      );
      if (layer == null) {
        throw Exception(l10n.editor_updateMaskLayerFailed);
      }

      _state.requestUiUpdate();
      if (mounted) {
        _isMaskFillMode = false;
        setState(() {});
        AppToast.success(context, l10n.editor_closedRegionFilled);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, l10n.editor_fillMaskFailed(e));
      }
    }
  }

  int? _resolveMaskLayerInsertIndex() {
    if (_sourceLayerId == null) {
      return null;
    }

    final sourceIndex = _state.layerManager.layers.indexWhere(
      (layer) => layer.id == _sourceLayerId,
    );
    if (sourceIndex == -1) {
      return null;
    }

    // 蒙版图层应插入到底图上方，否则会被底图完全覆盖。
    return sourceIndex;
  }

  Future<Layer?> _addMaskLayerAboveSource(
    Uint8List imageBytes, {
    required String name,
  }) {
    return _state.layerManager.addLayerFromImage(
      imageBytes,
      name: name,
      index: _resolveMaskLayerInsertIndex(),
    );
  }

  Layer _addEmptyMaskLayerAboveSource({required String name}) {
    return _state.layerManager.addLayer(
      name: name,
      index: _resolveMaskLayerInsertIndex(),
    );
  }

  void _removeAllMaskLayers({Set<String> preservedLayerIds = const {}}) {
    final removableLayerIds = _state.layerManager.layers
        .where(
          (layer) =>
              layer.id != _sourceLayerId &&
              !preservedLayerIds.contains(layer.id),
        )
        .map((layer) => layer.id)
        .toList(growable: false);

    for (final layerId in removableLayerIds) {
      _state.layerManager.removeLayer(layerId);
    }
  }

  bool _hasVisibleMaskContent(String sourceLayerId) {
    return _state.layerManager.layers.any(
      (layer) => layer.id != sourceLayerId && layer.visible && layer.hasContent,
    );
  }

  Future<void> _applyOutpaintEdges(
    OutpaintEdges edges, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) async {
    return _applyOutpaintFrameDelta(
      OutpaintFrameDelta.fromExpansionEdges(edges),
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
  }

  Future<void> _applyOutpaintFrameDelta(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) async {
    if (!_useVirtualOutpaint) {
      return _applyOutpaintFrameDeltaMaterialized(
        delta,
        horizontalSnapTarget: horizontalSnapTarget,
        verticalSnapTarget: verticalSnapTarget,
      );
    }

    if (!_isInpaintMode || delta.isEmpty || _isOutpaintCommitPending) {
      return;
    }

    final compressionScale = _compressionLinearScale;
    final sourceLayerId = _sourceLayerId;
    if (sourceLayerId == null) {
      if (mounted) {
        AppToast.error(context, 'Unable to read current source image.');
      }
      return;
    }

    final applied = _effectiveOutpaintFrame.applyDelta(
      delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
    if (!applied.geometry.hasAppliedChange) {
      return;
    }

    final sourceLayer = _state.layerManager.getLayerById(sourceLayerId);
    if (sourceLayer == null) {
      if (mounted) {
        AppToast.error(context, 'Unable to read current source image.');
      }
      return;
    }

    final nonSourceLayerIds = _state.layerManager.layers
        .where((layer) => layer.id != sourceLayerId)
        .map((layer) => layer.id)
        .toList(growable: false);
    final resizedCanvasSize = applied.frame.canvasSize;

    _state.canvasController.beginBatch();
    try {
      _state.runBatch(() {
        sourceLayer.setBaseImageOffset(applied.frame.sourceDrawOffset);
        _state.layerManager.translateLayersContent(
          nonSourceLayerIds,
          applied.contentShift,
        );
        _state.layerManager.invalidateSnapshot();

        _virtualOutpaintFrame = applied.frame;
        _outpaintSourceImage = null;
        _outpaintSourceWidth = applied.frame.width;
        _outpaintSourceHeight = applied.frame.height;
        _hasOutpaintChanges = applied.frame.hasOutpaintChanges;

        _state.setCanvasSize(resizedCanvasSize);
        _focusedSelectionState.canvasSize = resizedCanvasSize;
        _disableFocusedInpaintForOutpaint();
        _refreshCompressionPlan(desiredScale: compressionScale);
        _state.canvasController.fitToViewport(_state.canvasSize);
        _state.requestUiUpdate();
      });
    } finally {
      _state.canvasController.endBatch();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyOutpaintFrameDeltaMaterialized(
    OutpaintFrameDelta delta, {
    OutpaintHorizontalSnapTarget horizontalSnapTarget =
        OutpaintHorizontalSnapTarget.right,
    OutpaintVerticalSnapTarget verticalSnapTarget =
        OutpaintVerticalSnapTarget.bottom,
  }) async {
    if (!_isInpaintMode || delta.isEmpty || _isOutpaintCommitPending) {
      return;
    }

    final compressionScale = _compressionLinearScale;
    final sourceLayerId = _sourceLayerId;
    if (sourceLayerId == null) {
      if (mounted) {
        AppToast.error(context, 'Unable to read current source image.');
      }
      return;
    }
    final maskLayerName = context.l10n.editor_maskLayerName;

    final pendingGeometry = InpaintOutpaintUtils.tryResolveFrameGeometry(
      sourceWidth: _state.canvasSize.width.round(),
      sourceHeight: _state.canvasSize.height.round(),
      delta: delta,
      horizontalSnapTarget: horizontalSnapTarget,
      verticalSnapTarget: verticalSnapTarget,
    );
    if (pendingGeometry == null || !pendingGeometry.hasAppliedChange) {
      return;
    }

    if (mounted) {
      setState(() {
        _isOutpaintCommitPending = true;
      });
    } else {
      _isOutpaintCommitPending = true;
    }

    final operationEpoch = _controller.beginOperation();
    try {
      final sourceLayer = _state.layerManager.getLayerById(sourceLayerId);
      final sourceBytes = sourceLayer?.baseImageBytes;
      if (sourceBytes == null) {
        if (mounted) {
          AppToast.error(context, 'Unable to read current source image.');
        }
        return;
      }

      final existingMask = _hasVisibleMaskContent(sourceLayerId)
          ? await ImageExporterNew.exportMaskFromLayers(
              _state.layerManager,
              _state.canvasSize,
              excludedBaseImageLayerIds: {sourceLayerId},
              forceHardEdges: true,
            )
          : null;
      if (!mounted || !_controller.accepts(operationEpoch)) return;
      final result = await InpaintOutpaintUtils.resizeFrameAsync(
        sourceImage: sourceBytes,
        existingMask: existingMask,
        delta: delta,
        horizontalSnapTarget: horizontalSnapTarget,
        verticalSnapTarget: verticalSnapTarget,
        includeEditorOverlay: true,
      );
      if (!mounted || !_controller.accepts(operationEpoch)) return;

      final resizedCanvasSize = Size(
        result.width.toDouble(),
        result.height.toDouble(),
      );
      final hasResultMask = InpaintMaskUtils.hasMaskedPixels(result.maskImage);
      final overlayBytes = hasResultMask
          ? result.editorOverlayImage ??
                await InpaintMaskUtils.maskToEditorOverlayAsync(
                  result.maskImage,
                )
          : null;

      final previousOutpaintSourceImage = _outpaintSourceImage;
      final previousOutpaintSourceWidth = _outpaintSourceWidth;
      final previousOutpaintSourceHeight = _outpaintSourceHeight;
      final previousHasOutpaintChanges = _hasOutpaintChanges;
      final previousVirtualOutpaintFrame = _virtualOutpaintFrame;
      final previousCanvasSize = _state.canvasSize;
      final previousFocusedCanvasSize = _focusedSelectionState.committedRect;
      final previousFocusedInpaintEnabled = _focusedInpaintEnabled;
      final previousControllerScale = _state.canvasController.scale;
      final previousControllerOffset = _state.canvasController.offset;
      final previousSourceBytes = sourceBytes;
      final previousSourceOffset = sourceLayer?.baseImageOffset ?? Offset.zero;
      final previousActiveLayerId = _state.layerManager.activeLayerId;
      final previousToolId = _state.currentTool?.id;
      final previousSelectionPath = _state.selectionPath == null
          ? null
          : Path.from(_state.selectionPath!);
      final previousPreviewPath = _state.previewPath == null
          ? null
          : Path.from(_state.previewPath!);

      void restoreOutpaintTrackingFields() {
        _outpaintSourceImage = previousOutpaintSourceImage;
        _outpaintSourceWidth = previousOutpaintSourceWidth;
        _outpaintSourceHeight = previousOutpaintSourceHeight;
        _hasOutpaintChanges = previousHasOutpaintChanges;
        _virtualOutpaintFrame = previousVirtualOutpaintFrame;
      }

      void restoreScreenState() {
        restoreOutpaintTrackingFields();
        _state.setCanvasSize(previousCanvasSize);
        _focusedSelectionState.canvasSize = previousCanvasSize;
        _focusedSelectionState.load(previousFocusedCanvasSize);
        _focusedInpaintEnabled = previousFocusedInpaintEnabled;
        _refreshCompressionPlan(desiredScale: compressionScale);
        _state.setSelection(previousSelectionPath, saveHistory: false);
        _state.setPreviewPath(previousPreviewPath);
        if (previousToolId != null) {
          _state.setToolById(previousToolId);
        }
        if (previousActiveLayerId != null &&
            _state.layerManager.getLayerById(previousActiveLayerId) != null) {
          _state.layerManager.setActiveLayer(previousActiveLayerId);
        }
        _state.canvasController.runBatch(() {
          _state.canvasController.setScale(previousControllerScale);
          _state.canvasController.setOffset(previousControllerOffset);
        });
      }

      _state.canvasController.beginBatch();
      try {
        await _state.runBatchAsync(() async {
          await _state.layerManager.runBatchAsync(() async {
            Layer? maskLayer;
            var sourceReplaced = false;

            await _controller.runDocumentTransaction<void>(
              snapshot: DocumentSnapshot(
                bytes: {'source': previousSourceBytes},
                values: {
                  'canvasSize': previousCanvasSize,
                  'focusedRect': previousFocusedCanvasSize,
                  'focusedEnabled': previousFocusedInpaintEnabled,
                  'controllerScale': previousControllerScale,
                  'controllerOffset': previousControllerOffset,
                  'sourceOffset': previousSourceOffset,
                  'activeLayerId': previousActiveLayerId,
                  'toolId': previousToolId,
                  'selectionPath': previousSelectionPath,
                  'previewPath': previousPreviewPath,
                },
              ),
              restore: (snapshot) async {
                if (maskLayer != null) {
                  _state.layerManager.removeLayer(maskLayer!.id);
                }
                if (sourceReplaced) {
                  await _state.layerManager.replaceLayerImage(
                    sourceLayerId,
                    snapshot.bytes['source']!,
                  );
                  _state.layerManager
                      .getLayerById(sourceLayerId)
                      ?.setBaseImageOffset(previousSourceOffset);
                }
                restoreScreenState();
              },
              mutation: () async {
                if (overlayBytes != null) {
                  maskLayer = await _addMaskLayerAboveSource(
                    overlayBytes,
                    name: maskLayerName,
                  );
                  if (maskLayer == null) {
                    throw Exception('Unable to add outpaint mask layer.');
                  }
                  if (!_controller.accepts(operationEpoch)) {
                    throw StateError('Outpaint operation was superseded.');
                  }
                }

                if (widget.debugFailOutpaintSourceReplacement) {
                  throw StateError(
                    'Simulated outpaint source replacement failure.',
                  );
                }

                final replaced = await _state.layerManager.replaceLayerImage(
                  sourceLayerId,
                  result.sourceImage,
                );
                if (!replaced) {
                  throw Exception('Unable to replace current source image.');
                }
                sourceReplaced = true;
                if (!_controller.accepts(operationEpoch)) {
                  throw StateError('Outpaint operation was superseded.');
                }

                _outpaintSourceImage = result.sourceImage;
                _outpaintSourceWidth = result.width;
                _outpaintSourceHeight = result.height;
                _hasOutpaintChanges = true;
                _virtualOutpaintFrame = OutpaintVirtualFrame.fromSource(
                  sourceWidth: result.width,
                  sourceHeight: result.height,
                );

                _state.setCanvasSize(resizedCanvasSize);
                _focusedSelectionState.canvasSize = resizedCanvasSize;
                _disableFocusedInpaintForOutpaint();
                _state.canvasController.fitToViewport(_state.canvasSize);

                if (widget.debugFailOutpaintAfterFocusedDisable) {
                  throw StateError(
                    'Simulated outpaint failure after focused disable.',
                  );
                }

                if (maskLayer != null) {
                  _removeAllMaskLayers(preservedLayerIds: {maskLayer!.id});
                } else {
                  _removeAllMaskLayers();
                  _addEmptyMaskLayerAboveSource(name: maskLayerName);
                }
                _state.requestUiUpdate();
              },
            );
          });
        });
      } finally {
        _state.canvasController.endBatch();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted && _controller.accepts(operationEpoch)) {
        AppToast.error(context, 'Apply outpaint failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOutpaintCommitPending = false;
        });
      } else {
        _isOutpaintCommitPending = false;
      }
    }
  }

  void _disableFocusedInpaintForOutpaint() {
    _focusedInpaintEnabled = false;
    _syncFocusedSelectionConstraint();
    _focusedSelectionState.clear();
    _state.clearSelection(saveHistory: false);
    _state.clearPreview();
    _state.setToolById('brush');
  }

  void _resetInpaintMask() {
    if (!_isInpaintMode) {
      _state.clearActiveLayerWithHistory();
      return;
    }

    _removeAllMaskLayers();
    _state.clearSelection(saveHistory: false);
    _state.clearPreview();
    _focusedSelectionState.clear();
    _isMaskFillMode = false;
    _addEmptyMaskLayerAboveSource(name: context.l10n.editor_maskLayerName);
    _state.setToolById(_focusedInpaintEnabled ? 'rect_selection' : 'brush');
    _refreshCompressionPlan();
    _state.requestUiUpdate();
    setState(() {});
  }

  Widget _buildDroppedImageLayerRegion(Widget child) {
    if (_isInpaintMode ||
        widget.debugDisableDropRegion ||
        !PlatformCapabilities.current.supportsExternalFileDrop) {
      return child;
    }

    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (_isImportingDroppedImage) {
          return DropOperation.none;
        }

        final isInternalDrag = event.session.items.any(
          (item) => isGalleryInternalDragLocalData(item.localData),
        );
        if (isInternalDrag) {
          return DropOperation.none;
        }

        return event.session.allowedOperations.contains(DropOperation.copy)
            ? DropOperation.copy
            : DropOperation.none;
      },
      onPerformDrop: (event) async {
        unawaited(_handleDroppedImageLayerDrop(event));
      },
      child: child,
    );
  }

  Future<void> _handleDroppedImageLayerDrop(PerformDropEvent event) async {
    if (_isInpaintMode || _isImportingDroppedImage) {
      return;
    }

    setState(() => _isImportingDroppedImage = true);
    try {
      var handledAny = false;
      final generationState = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(imageGenerationNotifierProvider);
      for (final item in event.session.items) {
        final internalPayload = resolveInternalHistoryDropPayload(
          item.localData,
          generationState,
        );
        if (internalPayload != null) {
          handledAny = true;
          await _importDroppedImageLayer(
            internalPayload.fileName,
            internalPayload.bytes,
          );
          continue;
        }

        final reader = item.dataReader;
        if (reader == null) {
          continue;
        }

        final fileData = await DroppedFileReader.read(
          reader,
          allowVibeFiles: false,
          logTag: 'ImageEditorDrop',
        );
        if (fileData == null) {
          continue;
        }

        handledAny = true;
        await _importDroppedImageLayer(fileData.fileName, fileData.bytes);
      }

      if (!handledAny && mounted) {
        AppToast.error(
          context,
          context.l10n.toast_unreadableDroppedImageSource,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingDroppedImage = false);
      } else {
        _isImportingDroppedImage = false;
      }
    }
  }

  Future<void> _importDroppedImageLayer(
    String fileName,
    Uint8List imageBytes,
  ) async {
    if (!mounted || _isInpaintMode) {
      return;
    }

    final l10n = context.l10n;
    if (imageBytes.isEmpty) {
      AppLogger.w('Dropped image is empty: $fileName', 'ImageEditorDrop');
      AppToast.error(context, l10n.editor_emptyImageFile);
      return;
    }
    if (imageBytes.length > _maxImportedImageBytes) {
      final sizeMB = (imageBytes.length / (1024 * 1024)).toStringAsFixed(1);
      AppLogger.w(
        'Dropped image too large: ${imageBytes.length} bytes',
        'ImageEditorDrop',
      );
      AppToast.error(context, l10n.editor_fileTooLarge(sizeMB));
      return;
    }

    try {
      final layerBytes = await _coverDroppedImageToCanvas(imageBytes);
      if (!mounted) {
        return;
      }

      final layer = await _state.layerManager.addLayerFromImage(
        layerBytes,
        name: _droppedImageLayerName(fileName),
        index: 0,
      );
      if (!mounted) {
        return;
      }
      if (layer == null) {
        AppToast.error(context, l10n.editor_parseImageFailed);
        return;
      }

      _state.clearSelection(saveHistory: false);
      _state.clearPreview();
      _state.requestUiUpdate();
      setState(() {});
    } catch (e) {
      AppLogger.w(
        'Failed to import dropped image layer: $fileName, error=$e',
        'ImageEditorDrop',
      );
      if (mounted) {
        AppToast.error(context, l10n.editor_parseImageFailed);
      }
    }
  }

  Future<Uint8List> _coverDroppedImageToCanvas(Uint8List imageBytes) async {
    final canvasWidth = _state.canvasSize.width.round();
    final canvasHeight = _state.canvasSize.height.round();
    final targetWidth = canvasWidth < 1 ? 1 : canvasWidth;
    final targetHeight = canvasHeight < 1 ? 1 : canvasHeight;

    ui.Codec? codec;
    ui.Image? sourceImage;
    ui.Image? targetImage;
    try {
      codec = await ui.instantiateImageCodec(imageBytes);
      final frame = await codec.getNextFrame();
      sourceImage = frame.image;

      if (sourceImage.width == targetWidth &&
          sourceImage.height == targetHeight) {
        return imageBytes;
      }

      final sourceAspect = sourceImage.width / sourceImage.height;
      final targetAspect = targetWidth / targetHeight;
      final Rect sourceRect;
      if (sourceAspect > targetAspect) {
        final cropWidth = sourceImage.height * targetAspect;
        sourceRect = Rect.fromLTWH(
          (sourceImage.width - cropWidth) / 2,
          0,
          cropWidth,
          sourceImage.height.toDouble(),
        );
      } else {
        final cropHeight = sourceImage.width / targetAspect;
        sourceRect = Rect.fromLTWH(
          0,
          (sourceImage.height - cropHeight) / 2,
          sourceImage.width.toDouble(),
          cropHeight,
        );
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        sourceImage,
        sourceRect,
        Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );
      targetImage = await recorder.endRecording().toImage(
        targetWidth,
        targetHeight,
      );
      final byteData = await targetImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('Failed to encode dropped image layer');
      }
      return byteData.buffer.asUint8List();
    } finally {
      targetImage?.dispose();
      sourceImage?.dispose();
      codec?.dispose();
    }
  }

  String _droppedImageLayerName(String fileName) {
    final trimmed = fileName.trim();
    return trimmed.isEmpty ? 'dropped_image.png' : trimmed;
  }

  Widget _buildCanvasArea() {
    final focusAreaRect = _focusedInpaintEnabled
        ? _focusedSelectionState.resolveActiveRect(
            previewPath: _state.previewPath,
          )
        : null;
    final contextCrop = focusAreaRect == null
        ? null
        : _resolveFocusedContextCropOnWorkCanvas(focusAreaRect);
    final virtualOutpaintMaskRects =
        _virtualOutpaintFrame?.outpaintMaskRects ?? const <Rect>[];

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: EditorCanvas(
              state: _state,
              showTransparentCanvasBackground:
                  _isInpaintMode || _controller.hasTransparentCutout,
              shouldSuppressPointerInput: _shouldSuppressCanvasPointerInput,
              suppressSelectionOverlay: _focusedSelectionState
                  .shouldSuppressSelectionOverlay(
                    focusedEnabled: _isInpaintMode && _focusedInpaintEnabled,
                    currentToolId: _state.currentTool?.id,
                    previewPath: _state.previewPath,
                  ),
            ),
          ),
        ),
        if (_isInpaintMode &&
            !_focusedInpaintEnabled &&
            virtualOutpaintMaskRects.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: VirtualOutpaintMaskPainter(
                    state: _state,
                    maskRects: virtualOutpaintMaskRects,
                  ),
                ),
              ),
            ),
          ),
        if (_isInpaintMode && !_focusedInpaintEnabled && !_isMaskFillMode)
          Positioned.fill(
            child: OutpaintEdgeDragOverlay(
              canvasSize: _state.canvasSize,
              controller: _state.canvasController,
              enabled: !_isOutpaintCommitPending,
              onCommitted: _applyOutpaintEdges,
              onFrameResizeCommitted: _applyOutpaintFrameDelta,
            ),
          ),
        if (_isInpaintMode && focusAreaRect != null && contextCrop != null)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FocusedContextOverlayPainter(
                    canvasController: _state.canvasController,
                    focusAreaRect: focusAreaRect,
                    contextCrop: contextCrop,
                    repaint: Listenable.merge([
                      _state.renderNotifier,
                      _state.canvasController,
                    ]),
                  ),
                ),
              ),
            ),
          ),
        if (_isInpaintMode && _isMaskFillMode)
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  unawaited(_fillClosedMaskRegionsAt(event.localPosition));
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        if (_isInpaintMode)
          Positioned(top: 16, left: 16, child: _buildFocusedSelectionCard()),
        Positioned.fill(
          child: MagicWandProgressOverlay(controller: _magicWandController),
        ),
      ],
    );
  }

  bool _shouldSuppressCanvasPointerInput(Offset localPosition) {
    if (!_isInpaintMode ||
        _focusedInpaintEnabled ||
        _isMaskFillMode ||
        _isOutpaintCommitPending) {
      return false;
    }

    final viewportSize = _state.canvasController.viewportSize;
    if (viewportSize == Size.zero) {
      return false;
    }

    return OutpaintEdgeDragOverlay.isResizeInteractionPoint(
      localPosition: localPosition,
      viewportSize: viewportSize,
      canvasSize: _state.canvasSize,
      controller: _state.canvasController,
    );
  }

  /// 加载蒙版文件
  Future<void> _loadMaskFile() async {
    final l10n = context.l10n;
    final maskLayerName = l10n.editor_maskLayerName;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消了文件选择
        return;
      }

      final file = result.files.first;

      // 验证文件扩展名（额外的安全检查）
      if (file.path != null) {
        final extension = file.path!.split('.').last.toLowerCase();
        const validImageExtensions = [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'bmp',
          'gif',
        ];

        if (!validImageExtensions.contains(extension)) {
          AppLogger.w('Invalid file extension: $extension', 'ImageEditor');
          if (mounted) {
            AppToast.error(
              context,
              context.l10n.editor_unsupportedImageFormat(extension),
            );
          }
          return;
        }
      }

      // 读取文件字节数据
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (e) {
          AppLogger.e('Failed to read file: $e', 'ImageEditor');
          if (mounted) {
            AppToast.error(context, context.l10n.editor_readFileFailed(e));
          }
          return;
        }
      }

      // 验证字节数据
      if (bytes == null) {
        AppLogger.w('File bytes is null', 'ImageEditor');
        if (mounted) {
          AppToast.error(context, l10n.editor_noFileData);
        }
        return;
      }

      // 检查文件是否为空
      if (bytes.isEmpty) {
        AppLogger.w('File is empty (0 bytes)', 'ImageEditor');
        if (mounted) {
          AppToast.error(context, l10n.editor_emptyImageFile);
        }
        return;
      }

      // 检查文件大小（限制为 50MB 以防止内存问题）
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (bytes.length > maxFileSize) {
        final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        AppLogger.w('File too large: ${bytes.length} bytes', 'ImageEditor');
        if (mounted) {
          AppToast.error(context, l10n.editor_fileTooLarge(sizeMB));
        }
        return;
      }

      // 将蒙版添加为新图层
      final layer = await _addMaskLayerAboveSource(bytes, name: maskLayerName);

      if (layer != null) {
        AppLogger.i('Mask layer added: ${layer.id}', 'ImageEditor');
        if (mounted) {
          AppToast.success(context, l10n.editor_maskLayerAdded);
        }
      } else {
        // 图像解码失败或格式不支持
        AppLogger.w(
          'Failed to decode image or unsupported format',
          'ImageEditor',
        );
        if (mounted) {
          AppToast.error(context, l10n.editor_parseImageFailed);
        }
      }
    } catch (e) {
      AppLogger.e('Unexpected error loading mask file: $e', 'ImageEditor');
      if (mounted) {
        AppToast.error(context, l10n.editor_loadMaskFailed(e));
      }
    }
  }

  /// 加载蒙版
  Future<void> _loadMask() async {
    await _loadMaskFile();
  }

  EditorCompressionTarget get _activeCompressionTarget {
    final target = _compressionTarget;
    if (target != null) return target;
    return EditorCompressionTarget(
      width: _state.canvasSize.width.round(),
      height: _state.canvasSize.height.round(),
      isOriginal: true,
    );
  }

  bool get _compressionApplied {
    final target = _activeCompressionTarget;
    return target.width != _state.canvasSize.width.round() ||
        target.height != _state.canvasSize.height.round();
  }

  bool get _compressionIsFocusLimited {
    final plan = _compressionPlan;
    return _isInpaintMode &&
        _focusedInpaintEnabled &&
        plan != null &&
        !plan.targets.any((target) => target.isOriginal);
  }

  double get _compressionLinearScale {
    return _activeCompressionTarget.linearScaleFor(
      _state.canvasSize.width.round(),
      _state.canvasSize.height.round(),
    );
  }

  void _initializeCompressionPlan() {
    _refreshCompressionPlan(desiredScale: 1);
  }

  void _refreshCompressionPlan({double? desiredScale}) {
    final workWidth = _state.canvasSize.width.round();
    final workHeight = _state.canvasSize.height.round();
    final previousTarget = _compressionTarget;
    final previousScale = previousTarget?.linearScaleFor(
      _compressionPlan?.workWidth ?? workWidth,
      _compressionPlan?.workHeight ?? workHeight,
    );
    final plan = EditorCompressionPlan.resolve(
      workWidth: workWidth,
      workHeight: workHeight,
      focusedInpaintEnabled: _isInpaintMode && _focusedInpaintEnabled,
      focusedSelectionRect: _focusedSelectionState.committedRect,
      minimumContextPixels: _minimumContextMegaPixels,
    );

    EditorCompressionTarget target;
    if (desiredScale != null) {
      target = plan.targetAtOrBelowScale(desiredScale);
    } else {
      final exactIndex = plan.indexOf(previousTarget);
      target = exactIndex >= 0
          ? plan.targets[exactIndex]
          : plan.targetAtOrBelowScale(previousScale ?? 1);
    }
    _compressionPlan = plan;
    _compressionTarget = target;
    _syncFocusedSelectionConstraint();
  }

  void _selectCompressionTarget(int index) {
    final plan = _compressionPlan;
    if (plan == null || plan.targets.isEmpty) return;
    final resolvedIndex = index.clamp(0, plan.targets.length - 1);
    _updateLayoutState(() {
      _compressionTarget = plan.targets[resolvedIndex];
      _syncFocusedSelectionConstraint();
    });
  }

  Rect _projectWorkRectToCompressionTarget(Rect rect) {
    final target = _activeCompressionTarget;
    return EditorCompressionGeometry.projectRect(
      rect,
      sourceWidth: _state.canvasSize.width.round(),
      sourceHeight: _state.canvasSize.height.round(),
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }

  FocusedInpaintGeometry? _resolveFocusedGeometryForWorkRect(Rect rect) {
    return EditorCompressionGeometry.resolveFocusedGeometry(
      workWidth: _state.canvasSize.width.round(),
      workHeight: _state.canvasSize.height.round(),
      target: _activeCompressionTarget,
      workSelectionRect: rect,
      minimumContextPixels: _minimumContextMegaPixels,
    );
  }

  Rect? _constrainFocusedWorkRect(Rect rect, {Offset? fixedAnchor}) {
    return EditorCompressionGeometry.constrainWorkSelection(
      workWidth: _state.canvasSize.width.round(),
      workHeight: _state.canvasSize.height.round(),
      target: _activeCompressionTarget,
      workSelectionRect: rect,
      minimumContextPixels: _minimumContextMegaPixels,
      fixedWorkAnchor: fixedAnchor,
    );
  }

  Rect? _resolveFocusedContextCropOnWorkCanvas(Rect selection) {
    final geometry = _resolveFocusedGeometryForWorkRect(selection);
    if (geometry == null) return null;
    return EditorCompressionGeometry.projectTargetCropToWorkCanvas(
      targetCrop: geometry.contextCrop,
      workWidth: _state.canvasSize.width.round(),
      workHeight: _state.canvasSize.height.round(),
      target: _activeCompressionTarget,
    );
  }

  Future<Uint8List> _exportMergedImageAtCompressionTarget() async {
    final raw = await ImageExporterNew.exportMergedRgba(
      _state.layerManager,
      _state.canvasSize,
      transparentBackground: _controller.hasTransparentCutout,
    );
    final target = _activeCompressionTarget;
    return EditorCompressionEncoder.encodeRgbaPngAsync(
      raw,
      targetWidth: target.width,
      targetHeight: target.height,
    );
  }

  Future<Uint8List> _exportInpaintLayerMaskAtCompressionTarget(
    List<Rect> additionalMaskRects,
  ) async {
    final excludedSourceIds = {if (_sourceLayerId != null) _sourceLayerId!};
    final target = _activeCompressionTarget;
    final raster = await ImageExporterNew.tryExportHardEdgeMaskRasterFromLayers(
      _state.layerManager,
      _state.canvasSize,
      excludedBaseImageLayerIds: excludedSourceIds,
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
      _state.layerManager,
      _state.canvasSize,
      excludedBaseImageLayerIds: excludedSourceIds,
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
    final target = _activeCompressionTarget;
    return InpaintMaskUtils.createRectMaskBytesAsync(
      width: target.width,
      height: target.height,
      rect: _projectWorkRectToCompressionTarget(workSelection),
    );
  }

  Future<Uint8List?> _prepareInpaintSourceAtCompressionTarget() async {
    final target = _activeCompressionTarget;
    Uint8List? source;
    if (_hasOutpaintChanges) {
      source = await _materializeVirtualOutpaintSourceIfNeeded(
        targetWidth: target.width,
        targetHeight: target.height,
      );
    } else {
      source = _inpaintWorkingSourceImage;
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

  Widget _buildDesktopCompressionControl({required bool expanded}) {
    final plan = _compressionPlan;
    if (plan == null) return const SizedBox.shrink();
    if (!expanded) {
      return IconButton(
        icon: const Icon(Icons.compress, size: 20),
        onPressed: _showCompressionSheet,
        tooltip: context.l10n.editor_compressionTooltip,
      );
    }

    final target = _activeCompressionTarget;
    final index = plan.indexOf(target).clamp(0, plan.targets.length - 1);
    return Tooltip(
      message: context.l10n.editor_compressionTooltip,
      child: SizedBox(
        width: 300,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compress, size: 18),
            const SizedBox(width: 6),
            SizedBox(
              width: 92,
              child: Text(
                '${target.width} x ${target.height}',
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(
              child: Slider(
                value: index.toDouble(),
                min: 0,
                max: plan.targets.length > 1
                    ? (plan.targets.length - 1).toDouble()
                    : 1,
                divisions: plan.targets.length > 1
                    ? plan.targets.length - 1
                    : null,
                onChanged: plan.canCompress
                    ? (value) => _selectCompressionTarget(value.round())
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCompressionAction() {
    return IconButton(
      icon: const Icon(Icons.compress),
      onPressed: _showCompressionSheet,
      tooltip: context.l10n.editor_compressionTooltip,
    );
  }

  Future<void> _showCompressionSheet() async {
    await AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.editor_compressionTitle,
      initialChildSize: 0.62,
      minChildSize: 0.42,
      dialogWidth: 440,
      builder: (panelContext, scrollController) => StatefulBuilder(
        builder: (panelContext, setPanelState) {
          final plan = _compressionPlan;
          if (plan == null) return const SizedBox.shrink();
          final target = _activeCompressionTarget;
          final index = plan.indexOf(target).clamp(0, plan.targets.length - 1);
          final theme = Theme.of(panelContext);
          return ListView(
            controller: scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              Text(
                context.l10n.editor_compressionSizeSummary(
                  plan.workWidth,
                  plan.workHeight,
                  target.width,
                  target.height,
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                target.isOriginal
                    ? context.l10n.editor_compressionUncompressed
                    : context.l10n.editor_compressionApplyOnDone,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Slider(
                value: index.toDouble(),
                min: 0,
                max: plan.targets.length > 1
                    ? (plan.targets.length - 1).toDouble()
                    : 1,
                divisions: plan.targets.length > 1
                    ? plan.targets.length - 1
                    : null,
                label: '${target.width} x ${target.height}',
                onChanged: plan.canCompress
                    ? (value) {
                        _selectCompressionTarget(value.round());
                        setPanelState(() {});
                      }
                    : null,
              ),
              Text(
                context.l10n.editor_compressionNormalSummary(
                  plan.normalTarget.width,
                  plan.normalTarget.height,
                  plan.minimumTarget.width,
                  plan.minimumTarget.height,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (!plan.canCompress) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.editor_compressionUnavailable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_compressionIsFocusLimited) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.editor_compressionFocusLimited,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEffectsDialog() => _effectsController.showDialog(
    context,
    onChanged: () => _updateLayoutState(() {}),
  );

  /// 更改画布尺寸

  FocusedInpaintCostEstimate? _resolveFocusedInpaintCostEstimate() {
    final config = widget.focusedInpaintCostConfig;
    if (!_isInpaintMode || !_focusedInpaintEnabled || config == null) {
      return null;
    }

    final focusAreaRect = _focusedSelectionState.resolveActiveRect(
      previewPath: _state.previewPath,
    );
    if (focusAreaRect == null) {
      return null;
    }

    final geometry = _resolveFocusedGeometryForWorkRect(focusAreaRect);
    if (geometry == null) {
      return null;
    }

    final cost = config.estimate(
      width: geometry.requestWidth,
      height: geometry.requestHeight,
    );

    return FocusedInpaintCostEstimate(geometry: geometry, cost: cost);
  }

  Widget _buildFocusedSelectionCard() {
    final theme = Theme.of(context);
    final hasFocusArea =
        _focusedInpaintEnabled && _focusedSelectionState.hasCommittedRect;
    final costEstimate = _resolveFocusedInpaintCostEstimate();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _toggleFocusedInpaint,
                  icon: Icon(
                    _focusedInpaintEnabled
                        ? Icons.crop_free
                        : Icons.filter_center_focus,
                    size: 16,
                  ),
                  label: Text(
                    _focusedInpaintEnabled
                        ? 'Focused Area Selection'
                        : 'Focused Inpaint',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            !_focusedInpaintEnabled
                ? context.l10n.editor_focusInactiveHint
                : hasFocusArea
                ? context.l10n.editor_focusReadyHint
                : context.l10n.editor_focusNeedsSelectionHint,
            style: theme.textTheme.bodySmall,
          ),
          if (_focusedInpaintEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFocusModeButton(
                  icon: Icons.crop_square,
                  label: context.l10n.editor_focusSelection,
                  toolId: 'rect_selection',
                ),
                const SizedBox(width: 8),
                _buildFocusModeButton(
                  icon: Icons.brush_outlined,
                  label: context.l10n.editor_focusBrush,
                  toolId: 'brush',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _focusedSelectionState.hasCommittedRect
                    ? () {
                        _updateLayoutState(() {
                          _focusedSelectionState.clear();
                          _state.clearSelection(saveHistory: false);
                          _state.clearPreview();
                          _state.setToolById('rect_selection');
                          _refreshCompressionPlan();
                        });
                      }
                    : null,
                icon: const Icon(Icons.clear, size: 16),
                label: Text(context.l10n.editor_clearSelection),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.editor_focusMinimumContextArea(
                _minimumContextMegaPixels.round(),
              ),
              style: theme.textTheme.labelMedium,
            ),
            Slider(
              value: _minimumContextMegaPixels,
              min: 16,
              max: 192,
              divisions: 176,
              onChanged: (value) {
                _updateLayoutState(() {
                  _minimumContextMegaPixels = value;
                  _constrainCommittedFocusedSelection();
                  _refreshCompressionPlan();
                });
              },
            ),
            if (costEstimate != null) ...[
              const SizedBox(height: 8),
              _buildFocusedAnlasWarning(costEstimate),
              const SizedBox(height: 8),
            ],
            Text(
              context.l10n.editor_focusContextHint,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusedAnlasWarning(FocusedInpaintCostEstimate estimate) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.editor_focusRequestSummary(
                estimate.geometry.contextCrop.width,
                estimate.geometry.contextCrop.height,
                estimate.geometry.requestWidth,
                estimate.geometry.requestHeight,
                estimate.cost,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFocusedInpaint() {
    if (_hasOutpaintChanges && !_focusedInpaintEnabled) {
      AppToast.warning(
        context,
        'Outpaint cannot be used together with Focused Inpaint.',
      );
      return;
    }

    final desiredScale = _compressionLinearScale;
    _updateLayoutState(() {
      _focusedInpaintEnabled = !_focusedInpaintEnabled;
      if (_focusedInpaintEnabled) {
        if (!_focusedSelectionState.hasCommittedRect) {
          _state.setToolById('rect_selection');
        }
      } else {
        _state.clearSelection(saveHistory: false);
        _state.clearPreview();
        _focusedSelectionState.clear();
        _state.setToolById('brush');
      }
      _refreshCompressionPlan(desiredScale: desiredScale);
    });
  }

  void _syncFocusedSelectionConstraint() {
    if (!_isInpaintMode || !_focusedInpaintEnabled) {
      _state.setRectSelectionConstraint(null);
      return;
    }
    _state.setRectSelectionConstraint((candidate, fixedAnchor) {
      return _constrainFocusedWorkRect(candidate, fixedAnchor: fixedAnchor) ??
          candidate;
    });
  }

  void _constrainCommittedFocusedSelection() {
    final selection = _focusedSelectionState.committedRect;
    if (selection == null) return;
    final constrained = _constrainFocusedWorkRect(selection);
    _focusedSelectionState.load(constrained);
  }

  void _consumeFocusedSelection() {
    if (!_isInpaintMode || !_focusedInpaintEnabled) {
      return;
    }
    if (_state.currentTool?.id != 'rect_selection') {
      return;
    }
    final consumed = _focusedSelectionState.captureSelection(
      _state.selectionPath,
    );
    if (!consumed) {
      return;
    }

    _state.clearSelection(saveHistory: false);
    _state.clearPreview();
    _state.setToolById('brush');
    _refreshCompressionPlan();
    _state.requestUiUpdate();
    if (mounted) {
      _updateLayoutState(() {});
    }
  }

  Widget _buildFocusModeButton({
    required IconData icon,
    required String label,
    required String toolId,
  }) {
    final theme = Theme.of(context);
    final selected = _state.currentTool?.id == toolId;

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          _state.setToolById(toolId);
        },
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          backgroundColor: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  /// 桌面端布局
  Widget _buildDesktopLayout({required double availableWidth}) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部菜单栏
            _buildDesktopMenuBar(availableWidth: availableWidth),

            // 主体区域
            Expanded(
              child: Row(
                children: [
                  // 左侧工具栏
                  DesktopToolbar(
                    state: _state,
                    onClear: _isInpaintMode ? _resetInpaintMask : null,
                    onFillMask: _isInpaintMode
                        ? _handleFillClosedMaskRegions
                        : null,
                    canFillMask: _isInpaintMode ? _hasMaskContent : null,
                    allowedToolIds: _isInpaintMode
                        ? ImageEditorWorkspaceState._inpaintToolIds
                        : null,
                  ),

                  // 中间画布区域
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildCanvasArea()),
                        // 底部状态栏
                        _buildStatusBar(),
                      ],
                    ),
                  ),

                  // 右侧面板
                  if (_showLayerPanel)
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          // 图层面板
                          Expanded(flex: 2, child: LayerPanel(state: _state)),
                          const ThemedDivider(height: 1),
                          // 工具设置面板
                          Expanded(flex: 2, child: _buildToolSettingsPanel()),
                          const ThemedDivider(height: 1),
                          // 颜色面板
                          if (!_isInpaintMode) ColorPanel(state: _state),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout({required double availableWidth}) {
    final compactActions = availableWidth < 520;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editorTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!compactActions) _buildMobileCompressionAction(),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMobileLayerSheet,
            tooltip: context.l10n.editor_layers,
          ),
          if (!compactActions && _isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _loadMask,
              tooltip: context.l10n.editor_loadMask,
            ),
          if (!compactActions && _isInpaintMode)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              onPressed: _showShiftEdgesDialog,
              tooltip: context.l10n.editor_shiftEdges,
            ),
          if (!compactActions && !_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _showEffectsDialog,
              tooltip: context.l10n.editor_effects,
            ),
          if (compactActions) _buildMobileOverflowMenu(),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _canExportAndClose ? _exportAndClose : null,
            tooltip: widget.completionLabel ?? context.l10n.editor_done,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // 画布区域
              Expanded(child: _buildCanvasArea()),

              // 横屏短窗口保留画布主区域，设置面板仍可独立滚动。
              _buildMobileToolSettings(
                maxHeight: constraints.maxHeight < 420 ? 96 : 150,
              ),

              // 底部工具栏
              MobileToolbar(
                state: _state,
                onClear: _isInpaintMode ? _resetInpaintMask : null,
                onFillMask: _isInpaintMode
                    ? _handleFillClosedMaskRegions
                    : null,
                canFillMask: _isInpaintMode ? _hasMaskContent : null,
                onLayersPressed: _showMobileLayerSheet,
                allowedToolIds: _isInpaintMode
                    ? ImageEditorWorkspaceState._inpaintToolIds
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileOverflowMenu() {
    return PopupMenuButton<_MobileEditorAction>(
      tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
      onSelected: (action) {
        switch (action) {
          case _MobileEditorAction.compression:
            unawaited(_showCompressionSheet());
          case _MobileEditorAction.loadMask:
            unawaited(_loadMask());
          case _MobileEditorAction.shiftEdges:
            unawaited(_showShiftEdgesDialog());
          case _MobileEditorAction.effects:
            unawaited(_showEffectsDialog());
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MobileEditorAction.compression,
          child: ListTile(
            leading: const Icon(Icons.compress),
            title: Text(context.l10n.editor_compressionTooltip),
          ),
        ),
        if (_isInpaintMode)
          PopupMenuItem(
            value: _MobileEditorAction.loadMask,
            child: ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(context.l10n.editor_loadMask),
            ),
          ),
        if (_isInpaintMode)
          PopupMenuItem(
            value: _MobileEditorAction.shiftEdges,
            child: ListTile(
              leading: const Icon(Icons.open_in_full),
              title: Text(context.l10n.editor_shiftEdges),
            ),
          ),
        if (!_isInpaintMode)
          PopupMenuItem(
            value: _MobileEditorAction.effects,
            child: ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: Text(context.l10n.editor_effects),
            ),
          ),
      ],
    );
  }

  /// 桌面端菜单栏
  Widget _buildDesktopMenuBar({required double availableWidth}) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => _confirmExit(),
            tooltip: context.l10n.editor_back,
          ),

          Text(_editorTitle(), style: theme.textTheme.titleSmall),

          const Spacer(),

          _buildDesktopCompressionControl(expanded: availableWidth >= 1700),
          const SizedBox(width: 4),

          if (!_isInpaintMode)
            if (availableWidth >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(context.l10n.editor_effects),
                onPressed: _showEffectsDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: _showEffectsDialog,
                tooltip: context.l10n.editor_effects,
              ),

          // 画布尺寸按钮（使用细粒度监听）
          TextButton.icon(
            icon: const Icon(Icons.aspect_ratio, size: 18),
            label: ValueListenableBuilder<Size>(
              valueListenable: _state.canvasSizeNotifier,
              builder: (context, size, _) =>
                  Text('${size.width.toInt()} x ${size.height.toInt()}'),
            ),
            onPressed: _changeCanvasSize,
          ),

          // 加载蒙版按钮
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file, size: 20),
              onPressed: _loadMask,
              tooltip: context.l10n.editor_loadMask,
            ),

          if (_isInpaintMode)
            if (availableWidth >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.open_in_full, size: 18),
                label: Text(context.l10n.editor_shiftEdges),
                onPressed: _showShiftEdgesDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.open_in_full, size: 20),
                onPressed: _showShiftEdgesDialog,
                tooltip: context.l10n.editor_shiftEdges,
              ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 8,
            endIndent: 8,
          ),

          // 切换面板
          IconButton(
            icon: Icon(
              _showLayerPanel
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: () {
              _updateLayoutState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
            tooltip: context.l10n.editor_togglePanels,
          ),

          // 快捷键帮助
          IconButton(
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: _showShortcutHelp,
            tooltip: context.l10n.editor_shortcutHelpTitle,
          ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 8,
            endIndent: 8,
          ),

          // 导出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(widget.completionLabel ?? context.l10n.editor_done),
              onPressed: _canExportAndClose ? _exportAndClose : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 状态栏
  /// 使用 Listenable.merge 实现细粒度监听
  Widget _buildStatusBar() {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _state.canvasController, // 缩放、旋转、镜像
        _state.canvasSizeNotifier, // 画布尺寸
        _state.layerManager, // 图层数量
        _state.selectionManager, // 选区状态
      ]),
      builder: (context, _) {
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                context.l10n.editor_statusZoom(
                  (_state.canvasController.scale * 100).round(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                context.l10n.editor_statusCanvas(
                  _state.canvasSize.width.toInt(),
                  _state.canvasSize.height.toInt(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                context.l10n.editor_statusLayers(
                  _state.layerManager.layerCount,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (_state.selectionPath != null) ...[
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusHasSelection,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              // 旋转角度显示
              if (_state.canvasController.rotation != 0) ...[
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusRotation(
                    (_state.canvasController.rotation * 180 / 3.14159265359)
                        .round(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
              // 镜像状态显示
              if (_state.canvasController.isMirroredHorizontally) ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flip,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.editor_statusMirrored,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 工具设置面板
  /// 使用 toolChangeNotifier 实现细粒度监听，仅在工具切换时重建
  Widget _buildToolSettingsPanel() {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: _state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) {
          return Center(child: Text(context.l10n.image_editor_select_tool));
        }
        return SingleChildScrollView(
          child: tool.buildSettingsPanel(context, _state),
        );
      },
    );
  }

  /// 移动端工具设置
  /// 使用 toolChangeNotifier 实现细粒度监听
  Widget _buildMobileToolSettings({required double maxHeight}) {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: _state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) return const SizedBox.shrink();

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: tool.buildSettingsPanel(context, _state),
          ),
        );
      },
    );
  }

  /// 显示移动端图层面板
  void _showMobileLayerSheet() {
    unawaited(
      AdaptivePresenter.showPanel<void>(
        context: context,
        title: context.l10n.editor_layers,
        initialChildSize: 0.62,
        builder: (context, scrollController) => PrimaryScrollController(
          controller: scrollController,
          child: LayerPanel(state: _state),
        ),
      ),
    );
  }

  /// 显示快捷键帮助
  void _showShortcutHelp() => _presentShortcutHelp(context);

  static void debugShowShortcutHelpForContext(BuildContext context) {
    _presentShortcutHelp(context);
  }

  static void _presentShortcutHelp(BuildContext context) {
    unawaited(
      AdaptivePresenter.showForm<void>(
        context: context,
        dialogWidth: 440,
        titleBuilder: (panelContext) => Row(
          children: [
            const Icon(Icons.keyboard),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                panelContext.l10n.editor_shortcutHelpTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        builder: (panelContext, scrollController) => ListView(
          key: const ValueKey('image-editor-shortcut-help-scroll'),
          controller: scrollController,
          shrinkWrap: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: [
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutPaintTools,
              [
                ('B', context.l10n.editor_toolBrush),
                ('E', context.l10n.editor_toolEraser),
                ('W', context.l10n.editor_toolMagicWand),
                ('P', context.l10n.editor_toolColorPicker),
                ('Alt', context.l10n.editor_shortcutTemporaryColorPicker),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutSelectionTools,
              [
                ('M', context.l10n.editor_shortcutRectSelection),
                ('U', context.l10n.editor_shortcutEllipseSelection),
                ('L', context.l10n.editor_shortcutLassoSelection),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutCanvasView,
              [
                ('1', context.l10n.editor_shortcut100Zoom),
                ('2', context.l10n.editor_shortcutFitHeight),
                ('3', context.l10n.editor_shortcutFitWidth),
                ('4', context.l10n.editor_shortcutRotateLeft15),
                ('5', context.l10n.editor_shortcutResetRotation),
                ('6', context.l10n.editor_shortcutRotateRight15),
                ('F', context.l10n.editor_shortcutFlipHorizontal),
                ('R', context.l10n.editor_resetView),
                (context.l10n.editor_shortcutWheel, context.l10n.editor_zoom),
                ('Ctrl+0', context.l10n.editor_shortcut100Zoom),
                ('Ctrl++', context.l10n.editor_zoomIn),
                ('Ctrl+-', context.l10n.editor_zoomOut),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutBrushAdjust,
              [
                ('[', context.l10n.editor_shortcutBrushSmaller),
                (']', context.l10n.editor_shortcutBrushLarger),
                ('I', context.l10n.editor_shortcutOpacityLower),
                ('O', context.l10n.editor_shortcutOpacityHigher),
                ('Shift + Drag', context.l10n.editor_shortcutDragBrushSize),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutColors,
              [('X', context.l10n.editor_shortcutSwapColors)],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutCanvasActions,
              [
                ('Space + Drag', context.l10n.editor_shortcutPanCanvas),
                ('Middle Drag', context.l10n.editor_shortcutPanCanvas),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutHistoryActions,
              [
                ('Ctrl+Z', context.l10n.editor_undo),
                ('Ctrl+Shift+Z', context.l10n.editor_redo),
                ('Ctrl+Y', context.l10n.editor_redo),
              ],
            ),
            _buildShortcutSection(
              panelContext,
              context.l10n.editor_shortcutSelectionActions,
              [
                ('Delete', context.l10n.editor_shortcutClearSelectionContent),
                (
                  'Backspace',
                  context.l10n.editor_shortcutClearSelectionContent,
                ),
                ('Esc', context.l10n.editor_shortcutCancelCurrentAction),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildShortcutSection(
    BuildContext context,
    String title,
    List<(String, String)> shortcuts,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...shortcuts.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.$2, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusedContextOverlayPainter extends CustomPainter {
  _FocusedContextOverlayPainter({
    required this.canvasController,
    required this.focusAreaRect,
    required this.contextCrop,
    super.repaint,
  });

  final CanvasController canvasController;
  final Rect focusAreaRect;
  final Rect contextCrop;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = canvasController.transformMatrix.storage;
    final screenSelectionPath = (Path()..addRect(focusAreaRect)).transform(
      matrix,
    );
    final screenContextPath = (Path()..addRect(contextCrop)).transform(matrix);

    FocusedOverlayPainter(
      contextPath: screenContextPath,
      focusPath: screenSelectionPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedContextOverlayPainter oldDelegate) {
    return contextCrop != oldDelegate.contextCrop ||
        focusAreaRect != oldDelegate.focusAreaRect ||
        canvasController != oldDelegate.canvasController;
  }
}

enum _MobileEditorAction { compression, loadMask, shiftEdges, effects }
