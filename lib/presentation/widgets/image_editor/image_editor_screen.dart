import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/inpaint_mask_utils.dart';
import '../../../core/utils/inpaint_outpaint_utils.dart';
import '../../../core/utils/localization_extension.dart';
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

enum ImageEditorMode { edit, inpaint }

/// 图像编辑器返回结果
class ImageEditorResult {
  /// 修改后的图像（涂鸦合并）
  final Uint8List? modifiedImage;

  /// Inpainting蒙版图像
  final Uint8List? maskImage;

  /// 是否有图像修改
  final bool hasImageChanges;

  /// 是否有蒙版修改
  final bool hasMaskChanges;

  /// Focused Inpaint 选区范围
  final Rect? focusAreaRect;

  /// Focused Inpaint 上下文带宽
  final double minimumContextMegaPixels;

  /// 是否启用 Focused Inpaint
  final bool focusedInpaintEnabled;

  /// Outpaint 扩展后的源图像
  final Uint8List? outpaintSourceImage;

  /// Outpaint 扩展后的源图像宽度
  final int? outpaintSourceWidth;

  /// Outpaint 扩展后的源图像高度
  final int? outpaintSourceHeight;

  /// 是否有 Outpaint 源图像修改
  final bool hasOutpaintChanges;

  const ImageEditorResult({
    this.modifiedImage,
    this.maskImage,
    this.hasImageChanges = false,
    this.hasMaskChanges = false,
    this.focusAreaRect,
    this.minimumContextMegaPixels = 88.0,
    this.focusedInpaintEnabled = false,
    this.outpaintSourceImage,
    this.outpaintSourceWidth,
    this.outpaintSourceHeight,
    this.hasOutpaintChanges = false,
  });
}

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
  bool _isInitialized = false;
  bool _didStartInitialization = false;
  bool _showLayerPanel = true;
  bool _isOutpaintCommitPending = false;
  String? _sourceLayerId;
  Uint8List? _outpaintSourceImage;
  int? _outpaintSourceWidth;
  int? _outpaintSourceHeight;
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
      0.0,
      192.0,
    );
    _focusedInpaintEnabled =
        widget.initialFocusedInpaintEnabled || widget.existingFocusRect != null;
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
      codec = await ui.instantiateImageCodec(widget.initialImage!);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _state.initNewCanvas(
        Size(image.width.toDouble(), image.height.toDouble()),
        initialLayerName: defaultDrawingLayerName,
      );
      _focusedSelectionState.canvasSize = _state.canvasSize;

      // 将图像添加为底图图层
      final sourceLayer = await _state.layerManager.addLayerFromImage(
        widget.initialImage!,
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

  Future<void> _loadExistingMask() async {
    if (widget.existingMask == null) return;

    try {
      final overlayBytes = InpaintMaskUtils.maskToEditorOverlay(
        widget.existingMask!,
      );

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
    _focusedSelectionState.load(widget.existingFocusRect);
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

  /// 桌面端布局
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          // 顶部菜单栏
          _buildDesktopMenuBar(),

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
                  allowedToolIds: _isInpaintMode ? _inpaintToolIds : null,
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
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editorTitle()),
        actions: [
          // 图层按钮
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMobileLayerSheet,
            tooltip: context.l10n.editor_layers,
          ),
          // 加载蒙版按钮
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _loadMask,
              tooltip: context.l10n.editor_loadMask,
            ),
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              onPressed: _showShiftEdgesDialog,
              tooltip: 'Shift Edges',
            ),
          if (!_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _showEffectsDialog,
              tooltip: 'Effects',
            ),
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _canExportAndClose ? _exportAndClose : null,
            tooltip: context.l10n.editor_done,
          ),
        ],
      ),
      body: Column(
        children: [
          // 画布区域
          Expanded(child: _buildCanvasArea()),

          // 工具设置（可折叠）
          _buildMobileToolSettings(),

          // 底部工具栏
          MobileToolbar(
            state: _state,
            onClear: _isInpaintMode ? _resetInpaintMask : null,
            onFillMask: _isInpaintMode ? _handleFillClosedMaskRegions : null,
            canFillMask: _isInpaintMode ? _hasMaskContent : null,
            onLayersPressed: _showMobileLayerSheet,
            allowedToolIds: _isInpaintMode ? _inpaintToolIds : null,
          ),
        ],
      ),
    );
  }

  /// 桌面端菜单栏
  Widget _buildDesktopMenuBar() {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
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

          if (!_isInpaintMode)
            TextButton.icon(
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Effects'),
              onPressed: _showEffectsDialog,
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
            TextButton.icon(
              icon: const Icon(Icons.open_in_full, size: 18),
              label: const Text('Shift Edges'),
              onPressed: _showShiftEdgesDialog,
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
              setState(() {
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
              label: Text(context.l10n.editor_done),
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
              top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
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
  Widget _buildMobileToolSettings() {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: _state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: tool.buildSettingsPanel(context, _state),
          ),
        );
      },
    );
  }

  /// 显示移动端图层面板
  void _showMobileLayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return LayerPanel(state: _state);
        },
      ),
    );
  }

  /// 显示快捷键帮助
  void _showShortcutHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard),
            const SizedBox(width: 8),
            Text(context.l10n.editor_shortcutHelpTitle),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 350),
          child: SingleChildScrollView(
            primary: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildShortcutSection(context.l10n.editor_shortcutPaintTools, [
                  ('B', context.l10n.editor_toolBrush),
                  ('E', context.l10n.editor_toolEraser),
                  ('P', context.l10n.editor_toolColorPicker),
                  ('Alt', context.l10n.editor_shortcutTemporaryColorPicker),
                ]),
                _buildShortcutSection(
                  context.l10n.editor_shortcutSelectionTools,
                  [
                    ('M', context.l10n.editor_shortcutRectSelection),
                    ('U', context.l10n.editor_shortcutEllipseSelection),
                    ('L', context.l10n.editor_shortcutLassoSelection),
                  ],
                ),
                _buildShortcutSection(context.l10n.editor_shortcutCanvasView, [
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
                ]),
                _buildShortcutSection(context.l10n.editor_shortcutBrushAdjust, [
                  ('[', context.l10n.editor_shortcutBrushSmaller),
                  (']', context.l10n.editor_shortcutBrushLarger),
                  ('I', context.l10n.editor_shortcutOpacityLower),
                  ('O', context.l10n.editor_shortcutOpacityHigher),
                  ('Shift + Drag', context.l10n.editor_shortcutDragBrushSize),
                ]),
                _buildShortcutSection(context.l10n.editor_shortcutColors, [
                  ('X', context.l10n.editor_shortcutSwapColors),
                ]),
                _buildShortcutSection(
                  context.l10n.editor_shortcutCanvasActions,
                  [
                    ('Space + Drag', context.l10n.editor_shortcutPanCanvas),
                    ('Middle Drag', context.l10n.editor_shortcutPanCanvas),
                  ],
                ),
                _buildShortcutSection(
                  context.l10n.editor_shortcutHistoryActions,
                  [
                    ('Ctrl+Z', context.l10n.editor_undo),
                    ('Ctrl+Shift+Z', context.l10n.editor_redo),
                    ('Ctrl+Y', context.l10n.editor_redo),
                  ],
                ),
                _buildShortcutSection(
                  context.l10n.editor_shortcutSelectionActions,
                  [
                    (
                      'Delete',
                      context.l10n.editor_shortcutClearSelectionContent,
                    ),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }

  Future<void> _showEffectsDialog() async {
    final layer = _state.layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }

    final sourceBytes = await _readLayerPng(layer);
    if (!mounted) return;
    if (sourceBytes == null) {
      AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
      return;
    }

    var effectType = EditorEffectType.brightness;
    var intensity = 0.25;
    var previewBytes = sourceBytes;
    var previewLoading = false;
    var previewError = '';
    var previewVersion = 0;
    var previewInitialized = false;
    var dialogOpen = true;
    Timer? previewDebounce;

    Future<void> refreshPreview(StateSetter setDialogState) async {
      previewDebounce?.cancel();
      final version = ++previewVersion;
      setDialogState(() {
        previewLoading = true;
        previewError = '';
      });

      previewDebounce = Timer(const Duration(milliseconds: 180), () async {
        try {
          final cropRect = _selectionCropRect();
          final job = EditorEffectJob(
            imageBytes: sourceBytes,
            effectType: effectType,
            intensity: intensity,
            maxPreviewDimension: 768,
            cropRect: cropRect,
          );
          final resultMessage = await compute(
            runEditorEffectJobMessage,
            job.toMessage(),
            debugLabel: 'image_editor_effect_preview',
          );
          final result = EditorEffectResult.fromMessage(resultMessage);
          if (!dialogOpen || !mounted || version != previewVersion) {
            return;
          }
          setDialogState(() {
            previewBytes = result.bytes;
            previewLoading = false;
          });
        } catch (e) {
          if (!dialogOpen || !mounted || version != previewVersion) {
            return;
          }
          setDialogState(() {
            previewLoading = false;
            previewError = e.toString();
          });
        }
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!previewInitialized) {
              previewInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogOpen && mounted) {
                  unawaited(refreshPreview(setState));
                }
              });
            }
            final media = MediaQuery.of(context);
            final horizontalInset = media.size.width < 820 ? 12.0 : 32.0;
            final dialogWidth = (media.size.width - horizontalInset * 2)
                .clamp(360.0, 1120.0)
                .toDouble();
            final previewHeight = (media.size.height * 0.48)
                .clamp(320.0, 520.0)
                .toDouble();

            void selectEffect(EditorEffectType value) {
              setState(() {
                effectType = value;
                intensity = _defaultEffectIntensity(value);
              });
              unawaited(refreshPreview(setState));
            }

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogWidth,
                  maxHeight: media.size.height * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.editor_localEffects,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.common_close,
                            onPressed: () => Navigator.pop(context, false),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildEffectSection(
                                title: context.l10n.editor_basicAdjustments,
                                effects: const [
                                  EditorEffectType.brightness,
                                  EditorEffectType.contrast,
                                  EditorEffectType.saturation,
                                  EditorEffectType.temperature,
                                  EditorEffectType.gamma,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                              ),
                              const SizedBox(height: 14),
                              _buildEffectSection(
                                title: context.l10n.editor_styleAndRepair,
                                effects: const [
                                  EditorEffectType.grayscale,
                                  EditorEffectType.invert,
                                  EditorEffectType.sepia,
                                  EditorEffectType.denoise,
                                  EditorEffectType.blur,
                                  EditorEffectType.sharpen,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                              ),
                              const SizedBox(height: 14),
                              _buildEffectSection(
                                title: context.l10n.editor_transformCrop,
                                description: context
                                    .l10n
                                    .editor_transformCropDescription,
                                effects: const [
                                  EditorEffectType.rotateLeft,
                                  EditorEffectType.rotateRight,
                                  EditorEffectType.flipHorizontal,
                                  EditorEffectType.flipVertical,
                                  EditorEffectType.cropToSelection,
                                ],
                                selectedEffect: effectType,
                                onSelected: selectEffect,
                                prominent: true,
                              ),
                              const SizedBox(height: 16),
                              _buildEffectControl(
                                effectType: effectType,
                                intensity: intensity,
                                onChanged: (value) {
                                  setState(() => intensity = value);
                                  unawaited(refreshPreview(setState));
                                },
                                onReset: () {
                                  setState(
                                    () => intensity = _defaultEffectIntensity(
                                      effectType,
                                    ),
                                  );
                                  unawaited(refreshPreview(setState));
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildEffectPreviewComparison(
                                previewHeight: previewHeight,
                                sourceBytes: sourceBytes,
                                previewBytes: previewBytes,
                                previewLoading: previewLoading,
                                previewError: previewError,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.l10n.editor_effectPreviewHint,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.l10n.common_cancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: previewLoading || previewError.isNotEmpty
                                ? null
                                : () => Navigator.pop(context, true),
                            icon: const Icon(Icons.check),
                            label: Text(
                              context.l10n.editor_applyToCurrentLayer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    dialogOpen = false;
    previewDebounce?.cancel();

    if (confirmed == true) {
      await _applyEffect(effectType, intensity);
    }
  }

  Widget _buildEffectSection({
    required String title,
    required List<EditorEffectType> effects,
    required EditorEffectType selectedEffect,
    required ValueChanged<EditorEffectType> onSelected,
    String? description,
    bool prominent = false,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final effect in effects)
                  _buildEffectChip(
                    effect: effect,
                    selected: effect == selectedEffect,
                    onSelected: onSelected,
                    prominent: prominent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectChip({
    required EditorEffectType effect,
    required bool selected,
    required ValueChanged<EditorEffectType> onSelected,
    required bool prominent,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurface;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      selectedColor: colorScheme.secondaryContainer,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.55,
      ),
      side: BorderSide(
        color: selected ? colorScheme.secondary : colorScheme.outlineVariant,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 14 : 10,
        vertical: prominent ? 10 : 7,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_effectIcon(effect), size: prominent ? 20 : 18),
          const SizedBox(width: 6),
          Text(
            _effectLabel(effect),
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
      ),
      onSelected: (_) => onSelected(effect),
    );
  }

  Widget _buildEffectControl({
    required EditorEffectType effectType,
    required double intensity,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (!_effectHasIntensity(effectType)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(_effectIcon(effectType), color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.editor_oneShotEffectHint(
                    _effectLabel(effectType),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_effectIcon(effectType), color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.editor_effectIntensity(
                      _effectLabel(effectType),
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  intensity.toStringAsFixed(2),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onReset,
                  child: Text(context.l10n.common_reset),
                ),
              ],
            ),
            Slider(
              value: intensity,
              min: _effectMin(effectType),
              max: _effectMax(effectType),
              divisions: 40,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectPreviewComparison({
    required double previewHeight,
    required Uint8List sourceBytes,
    required Uint8List previewBytes,
    required bool previewLoading,
    required String previewError,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        if (stacked) {
          return SizedBox(
            height: previewHeight * 1.7,
            child: Column(
              children: [
                Expanded(
                  child: _buildEffectPreviewPane(
                    title: context.l10n.editor_original,
                    bytes: sourceBytes,
                    loading: false,
                    error: '',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _buildEffectPreviewPane(
                    title: context.l10n.editor_effectPreview,
                    bytes: previewBytes,
                    loading: previewLoading,
                    error: previewError,
                  ),
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: previewHeight,
          child: Row(
            children: [
              Expanded(
                child: _buildEffectPreviewPane(
                  title: context.l10n.editor_original,
                  bytes: sourceBytes,
                  loading: false,
                  error: '',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildEffectPreviewPane(
                  title: context.l10n.editor_effectPreview,
                  bytes: previewBytes,
                  loading: previewLoading,
                  error: previewError,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEffectPreviewPane({
    required String title,
    required Uint8List bytes,
    required bool loading,
    required String error,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
              child: error.isNotEmpty
                  ? Center(
                      child: Text(
                        error,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    )
                  : Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
            ),
          ),
          Positioned(
            left: 8,
            top: 6,
            child: Text(title, style: theme.textTheme.labelMedium),
          ),
          if (loading)
            const Positioned(
              right: 8,
              top: 8,
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  IconData _effectIcon(EditorEffectType type) {
    return switch (type) {
      EditorEffectType.brightness => Icons.wb_sunny_outlined,
      EditorEffectType.contrast => Icons.contrast,
      EditorEffectType.saturation => Icons.palette_outlined,
      EditorEffectType.temperature => Icons.thermostat,
      EditorEffectType.gamma => Icons.tune,
      EditorEffectType.grayscale => Icons.tonality,
      EditorEffectType.invert => Icons.invert_colors,
      EditorEffectType.sepia => Icons.filter_vintage,
      EditorEffectType.denoise => Icons.grain,
      EditorEffectType.blur => Icons.blur_on,
      EditorEffectType.sharpen => Icons.auto_fix_high,
      EditorEffectType.cropToSelection => Icons.crop,
      EditorEffectType.rotateLeft => Icons.rotate_left,
      EditorEffectType.rotateRight => Icons.rotate_right,
      EditorEffectType.flipHorizontal => Icons.swap_horiz,
      EditorEffectType.flipVertical => Icons.swap_vert,
    };
  }

  Future<void> _applyEffect(
    EditorEffectType effectType,
    double intensity,
  ) async {
    final layer = _state.layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) {
      AppToast.warning(
        context,
        context.l10n.editor_selectUnlockedLayerWithContent,
      );
      return;
    }

    try {
      final sourceBytes = await _readLayerPng(layer);
      if (!mounted) return;
      if (sourceBytes == null) {
        AppToast.error(context, context.l10n.editor_readCurrentLayerFailed);
        return;
      }

      final cropRect = _selectionCropRect();
      final job = EditorEffectJob(
        imageBytes: sourceBytes,
        effectType: effectType,
        intensity: intensity,
        cropRect: cropRect,
      );
      final resultMessage = await compute(
        runEditorEffectJobMessage,
        job.toMessage(),
        debugLabel: 'image_editor_effect_apply',
      );
      final result = EditorEffectResult.fromMessage(resultMessage);
      final bytes = result.bytes;
      final newImage = await _decodeUiImage(bytes);
      if (!mounted) return;
      _state.historyManager.execute(
        ReplaceLayerImageAction(
          layerId: layer.id,
          newImageBytes: bytes,
          newImage: newImage,
          actionDescription: _effectLabel(effectType),
        ),
        _state,
      );
      _state.layerManager.invalidateSnapshot();
      setState(() {});
      AppToast.success(
        context,
        context.l10n.editor_effectApplied(_effectLabel(effectType)),
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, context.l10n.editor_applyEffectFailed(e));
    }
  }

  Future<Uint8List?> _readLayerPng(dynamic layer) async {
    final rendered = await _renderLayerToImage(layer);
    try {
      final raw = await rendered.toByteData(format: ui.ImageByteFormat.png);
      return raw?.buffer.asUint8List();
    } finally {
      rendered.dispose();
    }
  }

  Future<ui.Image> _renderLayerToImage(dynamic layer) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    layer.render(canvas, _state.canvasSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _state.canvasSize.width.toInt(),
      _state.canvasSize.height.toInt(),
    );
    picture.dispose();
    return image;
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  String _effectLabel(EditorEffectType type) {
    return switch (type) {
      EditorEffectType.brightness => context.l10n.editor_effectBrightness,
      EditorEffectType.contrast => context.l10n.editor_effectContrast,
      EditorEffectType.saturation => context.l10n.editor_effectSaturation,
      EditorEffectType.temperature => context.l10n.editor_effectTemperature,
      EditorEffectType.gamma => context.l10n.editor_effectGamma,
      EditorEffectType.grayscale => context.l10n.editor_effectGrayscale,
      EditorEffectType.invert => context.l10n.editor_effectInvert,
      EditorEffectType.sepia => context.l10n.editor_effectSepia,
      EditorEffectType.denoise => context.l10n.editor_effectDenoise,
      EditorEffectType.blur => context.l10n.editor_effectBlur,
      EditorEffectType.sharpen => context.l10n.editor_effectSharpen,
      EditorEffectType.cropToSelection =>
        context.l10n.editor_effectCropToSelection,
      EditorEffectType.rotateLeft => context.l10n.editor_effectRotateLeft,
      EditorEffectType.rotateRight => context.l10n.editor_effectRotateRight,
      EditorEffectType.flipHorizontal =>
        context.l10n.editor_effectFlipHorizontal,
      EditorEffectType.flipVertical => context.l10n.editor_effectFlipVertical,
    };
  }

  double _defaultEffectIntensity(EditorEffectType type) {
    return editorEffectDefaultIntensity(type);
  }

  double _effectMin(EditorEffectType type) {
    return editorEffectMin(type);
  }

  double _effectMax(EditorEffectType type) {
    return editorEffectMax(type);
  }

  bool _effectHasIntensity(EditorEffectType type) {
    return editorEffectHasIntensity(type);
  }

  EditorEffectCropRect? _selectionCropRect() {
    final selection = _state.selectionPath;
    if (selection == null) {
      return null;
    }
    final bounds = selection.getBounds().intersect(
      Offset.zero & _state.canvasSize,
    );
    if (bounds.isEmpty) {
      return null;
    }
    final x = bounds.left.floor().clamp(0, _state.canvasSize.width - 1).toInt();
    final y = bounds.top.floor().clamp(0, _state.canvasSize.height - 1).toInt();
    final right = bounds.right
        .ceil()
        .clamp(x + 1, _state.canvasSize.width)
        .toInt();
    final bottom = bounds.bottom
        .ceil()
        .clamp(y + 1, _state.canvasSize.height)
        .toInt();
    return EditorEffectCropRect(
      x: x,
      y: y,
      width: right - x,
      height: bottom - y,
    );
  }

  Widget _buildShortcutSection(String title, List<(String, String)> shortcuts) {
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
                  Text(s.$2, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 更改画布尺寸
  Future<void> _changeCanvasSize() async {
    final l10n = context.l10n;
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

    // 用于跟踪加载对话框是否已显示
    bool loadingDialogShown = false;

    try {
      // 显示加载指示器
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

      // 检查是否有图像修改（检查是否有笔画或多个图层）
      final hasImageChanges =
          _state.historyManager.canUndo ||
          _state.layerManager.layers.any((l) => l.strokes.isNotEmpty) ||
          _state.layerManager.layerCount > 1;

      // 检查是否有蒙版修改
      final virtualOutpaintMaskRects =
          _virtualOutpaintFrame?.outpaintMaskRects ?? const <Rect>[];
      final hasMaskChanges =
          _hasMaskContent() || virtualOutpaintMaskRects.isNotEmpty;
      final focusAreaRect = _focusedInpaintEnabled
          ? _focusedSelectionState.committedRect
          : null;
      final focusedInpaintEnabled =
          _focusedInpaintEnabled && focusAreaRect != null;
      final useFocusedSelectionAsMask =
          focusedInpaintEnabled && !hasMaskChanges;
      AppLogger.d(
        'Export editor result: inpaint=$_isInpaintMode, '
            'hasImageChanges=$hasImageChanges, hasMaskChanges=$hasMaskChanges, '
            'selection=${_state.selectionPath != null}, focusRect=$focusAreaRect, '
            'focusedEnabled=$focusedInpaintEnabled, '
            'useFocusedSelectionAsMask=$useFocusedSelectionAsMask, '
            'layers=${_state.layerManager.layerCount}',
        'ImageEditor',
      );

      // 导出合并图像
      Uint8List? modifiedImage;
      if (!_isInpaintMode && hasImageChanges) {
        modifiedImage = await ImageExporterNew.exportMergedImage(
          _state.layerManager,
          _state.canvasSize,
        );
      }

      // 导出蒙版图像
      Uint8List? maskImage;
      if (_isInpaintMode && widget.showMaskExport && hasMaskChanges) {
        maskImage = await ImageExporterNew.exportMaskFromLayers(
          _state.layerManager,
          _state.canvasSize,
          excludedBaseImageLayerIds: {
            if (_sourceLayerId != null) _sourceLayerId!,
          },
          forceHardEdges: true,
          additionalMaskRects: virtualOutpaintMaskRects,
          preferCpuHardEdgeExport: true,
        );
        AppLogger.d(
          'Exported inpaint mask bytes: ${maskImage.length}',
          'ImageEditor',
        );
      } else if (_isInpaintMode &&
          widget.showMaskExport &&
          useFocusedSelectionAsMask) {
        maskImage = await ImageExporterNew.exportMask(
          Path()..addRect(focusAreaRect),
          _state.canvasSize,
          forceHardEdges: true,
        );
        AppLogger.d(
          'Exported focused selection mask bytes: ${maskImage.length}',
          'ImageEditor',
        );
      }

      final materializedOutpaintSource = _isInpaintMode
          ? await _materializeVirtualOutpaintSourceIfNeeded()
          : null;

      // 关闭加载指示器
      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      // 返回结果
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
            outpaintSourceImage: materializedOutpaintSource,
            outpaintSourceWidth: _isInpaintMode ? _outpaintSourceWidth : null,
            outpaintSourceHeight: _isInpaintMode ? _outpaintSourceHeight : null,
            hasOutpaintChanges: _isInpaintMode && _hasOutpaintChanges,
          ),
        );
      }
    } catch (e) {
      // 关闭加载指示器
      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 显示错误
      if (mounted) {
        AppToast.error(context, context.l10n.editor_exportFailed(e));
      }
    }
  }

  Future<Uint8List?> _materializeVirtualOutpaintSourceIfNeeded() async {
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
        : FocusedInpaintUtils.resolveContextCropForSelection(
            sourceWidth: _state.canvasSize.width.round(),
            sourceHeight: _state.canvasSize.height.round(),
            selectionRect: focusAreaRect,
            minContextMegaPixels: _minimumContextMegaPixels,
          );
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

  Widget _buildFocusedSelectionCard() {
    final theme = Theme.of(context);
    final hasFocusArea =
        _focusedInpaintEnabled && _focusedSelectionState.hasCommittedRect;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
                        setState(() {
                          _focusedSelectionState.clear();
                          _state.clearSelection(saveHistory: false);
                          _state.clearPreview();
                          _state.setToolById('rect_selection');
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
              min: 0,
              max: 192,
              divisions: 192,
              onChanged: (value) {
                setState(() {
                  _minimumContextMegaPixels = value;
                });
              },
            ),
            Text(
              context.l10n.editor_focusContextHint,
              style: theme.textTheme.bodySmall,
            ),
          ],
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

    setState(() {
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
    });
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
    _state.requestUiUpdate();
    if (mounted) {
      setState(() {});
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

class _FocusedContextOverlayPainter extends CustomPainter {
  _FocusedContextOverlayPainter({
    required this.canvasController,
    required this.focusAreaRect,
    required this.contextCrop,
    super.repaint,
  });

  final CanvasController canvasController;
  final Rect focusAreaRect;
  final FocusedInpaintCrop contextCrop;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = canvasController.transformMatrix.storage;
    final screenSelectionPath = (Path()..addRect(focusAreaRect)).transform(
      matrix,
    );
    final screenContextPath =
        (Path()..addRect(
              Rect.fromLTWH(
                contextCrop.x.toDouble(),
                contextCrop.y.toDouble(),
                contextCrop.width.toDouble(),
                contextCrop.height.toDouble(),
              ),
            ))
            .transform(matrix);

    FocusedOverlayPainter(
      contextPath: screenContextPath,
      focusPath: screenSelectionPath,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedContextOverlayPainter oldDelegate) {
    return contextCrop.x != oldDelegate.contextCrop.x ||
        contextCrop.y != oldDelegate.contextCrop.y ||
        contextCrop.width != oldDelegate.contextCrop.width ||
        contextCrop.height != oldDelegate.contextCrop.height ||
        focusAreaRect != oldDelegate.focusAreaRect ||
        canvasController != oldDelegate.canvasController;
  }
}
