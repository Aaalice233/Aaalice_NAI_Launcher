import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/services/anlas_calculator.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/editor_compression_utils.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/inpaint_mask_utils.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_resolution_adapter.dart';
import '../../utils/dropped_file_reader.dart';
import '../../widgets/common/app_toast.dart';
import 'core/canvas_controller.dart';
import 'core/editor_state.dart';
import 'effects/editor_effects.dart';
import 'core/focused_selection_state.dart';
import 'core/history_manager.dart';
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
import 'canvas/layer_painter.dart';
import 'export/image_exporter_new.dart';
import '../../widgets/common/themed_divider.dart';

part 'image_editor_screen_compression.dart';
part 'image_editor_screen_effects.dart';
part 'image_editor_screen_focused.dart';
part 'image_editor_screen_layout.dart';
part 'image_editor_screen_types.dart';

/// 图像编辑器主界面
class ImageEditorScreen extends StatefulWidget {
  /// 初始图像（可选，用于编辑已有图像）
  final Uint8List? initialImage;

  /// 初始画布尺寸（当没有初始图像时使用）
  final Size? initialSize;

  /// 已有的蒙版图像
  final Uint8List? existingMask;

  /// 已有的 Focused Inpaint 选区范围
  final Rect? existingFocusRect;

  /// Focused Inpaint 上下文带宽
  final double initialMinimumContextMegaPixels;

  /// 是否启用 Focused Inpaint
  final bool initialFocusedInpaintEnabled;

  /// Focused Inpaint 当前生成设置的点数估算配置
  final ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig;

  /// 是否显示蒙版导出选项
  final bool showMaskExport;

  /// 编辑器模式
  final ImageEditorMode mode;

  /// 标题
  final String title;

  @visibleForTesting
  final bool initialOutpaintCommitPending;

  @visibleForTesting
  final bool initialShowLayerPanel;

  @visibleForTesting
  final bool debugFailOutpaintSourceReplacement;

  @visibleForTesting
  final bool debugFailOutpaintAfterFocusedDisable;

  @visibleForTesting
  final bool debugDisableDropRegion;

  const ImageEditorScreen({
    super.key,
    this.initialImage,
    this.initialSize,
    this.existingMask,
    this.existingFocusRect,
    this.initialMinimumContextMegaPixels = 88.0,
    this.initialFocusedInpaintEnabled = false,
    this.focusedInpaintCostConfig,
    this.showMaskExport = true,
    this.mode = ImageEditorMode.edit,
    this.title = '',
    this.initialOutpaintCommitPending = false,
    this.initialShowLayerPanel = true,
    this.debugFailOutpaintSourceReplacement = false,
    this.debugFailOutpaintAfterFocusedDisable = false,
    this.debugDisableDropRegion = false,
  });

  /// 显示编辑器
  static Future<ImageEditorResult?> show(
    BuildContext context, {
    Uint8List? initialImage,
    Size? initialSize,
    Uint8List? existingMask,
    Rect? existingFocusRect,
    double initialMinimumContextMegaPixels = 88.0,
    bool initialFocusedInpaintEnabled = false,
    ImageEditorFocusedInpaintCostConfig? focusedInpaintCostConfig,
    bool showMaskExport = true,
    ImageEditorMode mode = ImageEditorMode.edit,
    String? title,
  }) {
    return Navigator.push<ImageEditorResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(
          initialImage: initialImage,
          initialSize: initialSize,
          existingMask: existingMask,
          existingFocusRect: existingFocusRect,
          initialMinimumContextMegaPixels: initialMinimumContextMegaPixels,
          initialFocusedInpaintEnabled: initialFocusedInpaintEnabled,
          focusedInpaintCostConfig: focusedInpaintCostConfig,
          showMaskExport: showMaskExport,
          mode: mode,
          title: title ?? context.l10n.editor_defaultTitle,
        ),
      ),
    );
  }

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  static const bool _useVirtualOutpaint = true;
  static const int _maxImportedImageBytes = 50 * 1024 * 1024;
  static const Set<String> _inpaintToolIds = {
    'brush',
    'eraser',
    'fill',
    'rect_selection',
    'ellipse_selection',
    'lasso_selection',
  };

  late EditorState _state;
  late FocusedSelectionState _focusedSelectionState;
  late double _minimumContextMegaPixels;
  late bool _focusedInpaintEnabled;
  bool _isMaskFillMode = false;
  EditorCompressionPlan? _compressionPlan;
  EditorCompressionTarget? _compressionTarget;
  bool _isInitialized = false;
  bool _didStartInitialization = false;
  bool _showLayerPanel = true;
  bool _isOutpaintCommitPending = false;
  String? _sourceLayerId;
  Uint8List? _outpaintSourceImage;
  int? _outpaintSourceWidth;
  int? _outpaintSourceHeight;
  Uint8List? _inpaintWorkingSourceImage;
  int? _inpaintWorkingSourceWidth;
  int? _inpaintWorkingSourceHeight;
  int? _initialSourceWidth;
  int? _initialSourceHeight;
  bool _sourceWasNormalized = false;
  OutpaintVirtualFrame? _virtualOutpaintFrame;
  // ignore: prefer_final_fields
  bool _hasOutpaintChanges = false;
  bool _isImportingDroppedImage = false;

  bool get _isInpaintMode => widget.mode == ImageEditorMode.inpaint;
  bool get _canExportAndClose => !_isOutpaintCommitPending;
  OutpaintVirtualFrame get _effectiveOutpaintFrame {
    return _virtualOutpaintFrame ??
        OutpaintVirtualFrame.fromSource(
          sourceWidth: _state.canvasSize.width.round(),
          sourceHeight: _state.canvasSize.height.round(),
        );
  }

  @visibleForTesting
  Size get debugCanvasSize => _state.canvasSize;

  @visibleForTesting
  Size get debugCompressionTargetSize => Size(
    _activeCompressionTarget.width.toDouble(),
    _activeCompressionTarget.height.toDouble(),
  );

  @visibleForTesting
  int get debugCompressionTargetCount => _compressionPlan?.targets.length ?? 0;

  @visibleForTesting
  bool get debugCompressionApplied => _compressionApplied;

  @visibleForTesting
  void debugSetCompressionTargetIndex(int index) {
    _selectCompressionTarget(index);
  }

  @visibleForTesting
  bool get debugFocusedInpaintEnabled => _focusedInpaintEnabled;

  @visibleForTesting
  bool get debugHasOutpaintChanges => _hasOutpaintChanges;

  @visibleForTesting
  bool get debugOutpaintCommitPending => _isOutpaintCommitPending;

  @visibleForTesting
  List<Rect> get debugVirtualOutpaintMaskRects {
    return _virtualOutpaintFrame?.outpaintMaskRects ?? const [];
  }

  @visibleForTesting
  int? get debugOutpaintSourceWidth => _outpaintSourceWidth;

  @visibleForTesting
  int? get debugOutpaintSourceHeight => _outpaintSourceHeight;

  @visibleForTesting
  String? get debugCurrentToolId => _state.currentTool?.id;

  @visibleForTesting
  String? get debugActiveLayerId => _state.layerManager.activeLayerId;

  @visibleForTesting
  String? get debugActiveLayerName => _state.layerManager.activeLayer?.name;

  @visibleForTesting
  int get debugActiveLayerStrokeCount {
    return _state.layerManager.activeLayer?.strokes.length ?? 0;
  }

  @visibleForTesting
  bool get debugIsDrawing => _state.isDrawing;

  @visibleForTesting
  bool get debugActiveLayerHasBaseImage =>
      _state.layerManager.activeLayer?.hasBaseImage ?? false;

  @visibleForTesting
  int get debugCurrentStrokePointCount => _state.currentStrokePoints.length;

  @visibleForTesting
  bool get debugHasMaskContent => _hasMaskContent();

  @visibleForTesting
  Offset debugCanvasToScreen(Offset point) {
    return _state.canvasController.canvasToScreen(
      point,
      canvasSize: _state.canvasSize,
    );
  }

  @visibleForTesting
  Rect? get debugFocusedRect => _focusedSelectionState.committedRect;

  @visibleForTesting
  Rect? get debugSelectionBounds => _state.selectionPath?.getBounds();

  @visibleForTesting
  Rect? get debugPreviewBounds => _state.previewPath?.getBounds();

  @visibleForTesting
  List<String> get debugLayerNames =>
      _state.layerManager.layers.map((layer) => layer.name).toList();

  @visibleForTesting
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

  @visibleForTesting
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

  @visibleForTesting
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

  @visibleForTesting
  Future<void> debugExportAndClose() => _exportAndClose();

  @visibleForTesting
  Future<void> debugImportDroppedImageLayer(
    String fileName,
    Uint8List imageBytes,
  ) {
    return _importDroppedImageLayer(fileName, imageBytes);
  }

  @visibleForTesting
  void debugSetToolById(String toolId) {
    _state.setToolById(toolId);
  }

  @visibleForTesting
  void debugSetSelectionRect(Rect rect) {
    _state.setSelection(Path()..addRect(rect), saveHistory: false);
  }

  @visibleForTesting
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
    _state = EditorState();
    _state.selectionManager.selectionNotifier.addListener(
      _consumeFocusedSelection,
    );
    _focusedSelectionState = FocusedSelectionState(
      canvasSize: const Size(1024, 1024),
      initialRect: widget.existingFocusRect,
    );
    _minimumContextMegaPixels = widget.initialMinimumContextMegaPixels.clamp(
      16.0,
      192.0,
    );
    _focusedInpaintEnabled =
        widget.initialFocusedInpaintEnabled || widget.existingFocusRect != null;
    _syncFocusedSelectionConstraint();
    _isOutpaintCommitPending = widget.initialOutpaintCommitPending;
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
    if (widget.initialImage != null) {
      // 从已有图像初始化
      await _loadInitialImage();
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
      _loadExistingFocusSelection();
    }

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

  Future<void> _loadInitialImage() async {
    final defaultDrawingLayerName = context.l10n.editor_defaultDrawingLayerName;
    final baseLayerName = context.l10n.editor_baseLayerName;
    ui.Codec? codec;
    try {
      final editorImage = await NaiResolutionAdapter.prepareImageForEditorAsync(
        widget.initialImage!,
        alignForInpaint: _isInpaintMode,
      );
      var workingBytes = editorImage?.bytes ?? widget.initialImage!;
      if (editorImage?.resizeMode == NaiEditorResizeMode.medium) {
        workingBytes = await _resizeEditorImageWithMedium(
          workingBytes,
          width: editorImage!.width,
          height: editorImage.height,
        );
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
      final image = frame.image;
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

      image.dispose();
    } catch (e) {
      AppLogger.w('Failed to load initial image: $e', 'ImageEditor');
      _state.initNewCanvas(
        widget.initialSize ?? const Size(1024, 1024),
        initialLayerName: defaultDrawingLayerName,
      );
      _localizeDefaultLayerName();
      _focusedSelectionState.canvasSize = _state.canvasSize;
    } finally {
      codec?.dispose();
    }
  }

  Future<Uint8List> _resizeEditorImageWithMedium(
    Uint8List sourceBytes, {
    required int width,
    required int height,
  }) async {
    ui.Codec? sourceCodec;
    ui.Image? sourceImage;
    ui.Image? targetImage;
    ui.Picture? picture;
    try {
      sourceCodec = await ui.instantiateImageCodec(sourceBytes);
      final frame = await sourceCodec.getNextFrame();
      sourceImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        sourceImage,
        ui.Rect.fromLTWH(
          0,
          0,
          sourceImage.width.toDouble(),
          sourceImage.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      targetImage = await picture.toImage(width, height);
      final byteData = await targetImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw StateError('Failed to encode the editor working image');
      }
      return byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );
    } finally {
      targetImage?.dispose();
      picture?.dispose();
      sourceImage?.dispose();
      sourceCodec?.dispose();
    }
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
    _state.selectionManager.selectionNotifier.removeListener(
      _consumeFocusedSelection,
    );
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(_editorTitle())),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return _buildDroppedImageLayerRegion(
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
        },
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

  /// 确认退出
  Future<void> _confirmExit() async {
    // 检查是否有修改：检查历史记录或图层内容
    final hasChanges =
        _state.historyManager.canUndo ||
        _state.layerManager.layers.any(
          (l) => l.strokes.isNotEmpty || l.baseImage != null,
        );

    if (hasChanges) {
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

      if (shouldExit != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
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
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
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
        Navigator.of(context).pop(
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
    final result = await InpaintOutpaintUtils.materializeVirtualFrameAsync(
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

  // ignore: unused_element
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
      final result = await InpaintOutpaintUtils.resizeFrameAsync(
        sourceImage: sourceBytes,
        existingMask: existingMask,
        delta: delta,
        horizontalSnapTarget: horizontalSnapTarget,
        verticalSnapTarget: verticalSnapTarget,
        includeEditorOverlay: true,
      );

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

            Future<void> rollbackTransaction() async {
              if (maskLayer != null) {
                _state.layerManager.removeLayer(maskLayer.id);
              }
              if (sourceReplaced) {
                await _state.layerManager.replaceLayerImage(
                  sourceLayerId,
                  previousSourceBytes,
                );
                _state.layerManager
                    .getLayerById(sourceLayerId)
                    ?.setBaseImageOffset(previousSourceOffset);
              }
              restoreScreenState();
            }

            try {
              if (overlayBytes != null) {
                maskLayer = await _addMaskLayerAboveSource(
                  overlayBytes,
                  name: maskLayerName,
                );
                if (maskLayer == null) {
                  throw Exception('Unable to add outpaint mask layer.');
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
                _removeAllMaskLayers(preservedLayerIds: {maskLayer.id});
              } else {
                _removeAllMaskLayers();
                _addEmptyMaskLayerAboveSource(name: maskLayerName);
              }
              _state.requestUiUpdate();
            } catch (_) {
              await rollbackTransaction();
              rethrow;
            }
          });
        });
      } finally {
        _state.canvasController.endBatch();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
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
    if (_isInpaintMode || widget.debugDisableDropRegion) {
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
          (item) => item.localData != null,
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
      for (final item in event.session.items) {
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
              showTransparentCanvasBackground: _isInpaintMode,
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
}
