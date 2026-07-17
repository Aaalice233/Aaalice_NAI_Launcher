import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../layers/layer.dart';
import '../layers/layer_manager.dart';
import '../tools/tool_base.dart';
import '../tools/brush_tool.dart';
import '../tools/eraser_tool.dart';
import 'canvas_controller.dart';
import 'color_manager.dart';
import 'history_manager.dart';
import 'selection_manager.dart';
import 'stroke_manager.dart';
import 'tool_manager.dart';

/// 编辑器全局状态（协调器）
/// 协调各 Manager 之间的交互，提供统一的 API 给 UI 层
class EditorState extends ChangeNotifier {
  // ===== 子管理器 =====

  /// 工具管理器
  final ToolManager toolManager = ToolManager();

  /// 颜色管理器
  final ColorManager colorManager = ColorManager();

  /// 选区管理器
  final SelectionManager selectionManager = SelectionManager();

  /// 笔画管理器
  final StrokeManager strokeManager = StrokeManager();

  /// 图层管理器
  final LayerManager layerManager = LayerManager();

  /// 画布控制器
  final CanvasController canvasController = CanvasController();

  /// 历史管理器
  final HistoryManager historyManager = HistoryManager();

  // ===== 通知器 =====

  /// 渲染变化通知器（仅用于触发画布重绘）
  /// LayerPainter 监听此通知器，而非整个 EditorState
  final ChangeNotifier renderNotifier = ChangeNotifier();

  /// 当前笔画预览通知器（仅用于实时笔画预览覆盖层重绘）
  final ChangeNotifier strokePreviewNotifier = ChangeNotifier();

  /// 工具切换通知器（仅工具栏和设置面板监听）
  /// 避免工具切换触发整个 EditorState 的监听者重建
  final ValueNotifier<EditorTool?> toolChangeNotifier = ValueNotifier(null);

  /// 画布尺寸通知器（仅画布尺寸相关 UI 监听）
  final ValueNotifier<Size> canvasSizeNotifier = ValueNotifier(
    const Size(1024, 1024),
  );

  /// 光标位置通知器（仅光标绘制器监听）
  /// 避免光标移动触发整个 UI 重建
  final ValueNotifier<Offset?> cursorNotifier = ValueNotifier(null);

  // ===== 画布状态 =====

  /// 画布尺寸
  Size _canvasSize = const Size(1024, 1024);
  Size get canvasSize => _canvasSize;
  Rect Function(Rect candidate, Offset fixedAnchor)? _rectSelectionConstraint;

  // ===== 内部状态 =====

  /// 防止通知重入的标志
  bool _isNotifying = false;

  bool _isDisposed = false;
  bool _strokePreviewFrameScheduled = false;
  bool _pendingStrokePreviewChange = false;
  int _batchDepth = 0;
  bool _pendingBatchedRenderChange = false;
  bool _pendingBatchedStateNotification = false;
  bool _pendingBatchedCanvasSizeNotification = false;
  bool _pendingBatchedToolChangeNotification = false;
  EditorTool? _pendingBatchedToolChange;

  bool get _isBatching => _batchDepth > 0;

  // ===== Alt 键状态（用于临时拾色器模式）=====

  /// 获取 Alt 键是否按下（从硬件键盘状态读取）
  bool get isAltPressed => HardwareKeyboard.instance.isAltPressed;

  // ===== 代理属性（向后兼容）=====

  // 快照代理
  bool get hasValidCanvasSnapshot => layerManager.hasValidSnapshot;
  int get canvasSnapshotVersion => layerManager.snapshotVersion;

  // 工具代理
  EditorTool? get currentTool => toolManager.currentTool;
  List<EditorTool> get tools => toolManager.tools;
  ValueNotifier<String?> get toolNotifier => toolManager.toolNotifier;

  // 颜色代理
  Color get foregroundColor => colorManager.foregroundColor;
  Color get backgroundColor => colorManager.backgroundColor;

  // 选区代理
  Path? get selectionPath => selectionManager.selectionPath;
  Path? get previewPath => selectionManager.previewPath;

  void setRectSelectionConstraint(
    Rect Function(Rect candidate, Offset fixedAnchor)? constraint,
  ) {
    _rectSelectionConstraint = constraint;
  }

  Rect constrainRectSelection(Rect candidate, Offset fixedAnchor) {
    return _rectSelectionConstraint?.call(candidate, fixedAnchor) ?? candidate;
  }

  // 笔画代理
  List<Offset> get currentStrokePoints => strokeManager.currentStrokePoints;
  bool get isDrawing => strokeManager.isDrawing;

  // ===== 构造函数 =====

  EditorState() {
    _setupListeners();
    // 同步初始工具到通知器（确保构造后立即一致）
    toolChangeNotifier.value = toolManager.currentTool;
  }

  void _setupListeners() {
    // 图层变化 → 触发渲染 + UI
    layerManager.addListener(_onLayerChanged);

    // 画布变换 → 触发渲染 + UI
    canvasController.addListener(_onCanvasChanged);

    // 颜色变化 → 仅 UI（不触发画布重绘）
    colorManager.addListener(_onColorChanged);

    // 选区变化 → 触发渲染
    selectionManager.addListener(_onSelectionChanged);

    // 笔画变化 → 触发渲染
    strokeManager.addListener(_onStrokeChanged);
  }

  // ===== 代理方法：工具 =====

  /// 切换工具 - 高性能即时切换
  /// 使用细粒度通知器，仅通知工具相关 UI，不触发整个 EditorState 重建
  void setTool(EditorTool tool) {
    if (toolManager.currentTool == tool) return;

    // 1. 同步快速停用当前工具（不触发异步操作）
    currentTool?.onDeactivateFast(this);

    // 2. 切换工具指针
    toolManager.setTool(tool);

    // 3. 仅通知工具相关 UI（工具栏、设置面板）
    _setToolChangeNotifier(tool);

    // 4. 延迟激活新工具（下一帧执行，不阻塞切换）
    _scheduleToolActivation(tool);
  }

  /// 通过 ID 切换工具
  void setToolById(String toolId) {
    final tool = toolManager.getToolById(toolId);
    if (tool != null) {
      setTool(tool);
    }
  }

  /// 切回上一个工具
  void switchToPreviousTool() {
    currentTool?.onDeactivateFast(this);
    toolManager.switchToPreviousTool();
    final tool = currentTool;
    if (tool != null) {
      _setToolChangeNotifier(tool);
      _scheduleToolActivation(tool);
    }
  }

  /// 延迟执行工具激活逻辑（下一帧异步执行）
  /// 用于资源预热、缓存更新等，不阻塞工具切换
  void _scheduleToolActivation(EditorTool tool) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保工具仍然是当前工具（防止快速连续切换）
      if (!_isDisposed && toolManager.currentTool == tool) {
        tool.onActivateDeferred(this);
      }
    });
  }

  /// 进入临时拾色器模式（Alt 按下）
  /// 轻量级切换：仅更新工具指针，不触发生命周期钩子
  /// 避免 onActivate 中的异步操作（如快照更新）打断事件流
  void enterTemporaryColorPicker() {
    toolManager.enterTemporaryColorPicker();
    // toolNotifier 已在 toolManager 中更新，UI 自动响应
  }

  /// 退出临时拾色器模式（Alt 松开）
  /// 轻量级切换：仅更新工具指针，不触发生命周期钩子
  void exitTemporaryColorPicker() {
    toolManager.exitTemporaryColorPicker();
    // toolNotifier 已在 toolManager 中更新，UI 自动响应
  }

  // ===== 代理方法：颜色 =====

  void setForegroundColor(Color color) =>
      colorManager.setForegroundColor(color);
  void setBackgroundColor(Color color) =>
      colorManager.setBackgroundColor(color);
  void swapColors() => colorManager.swapColors();

  // ===== 代理方法：选区 =====

  void setSelection(Path? path, {bool saveHistory = true}) =>
      selectionManager.setSelection(path, saveHistory: saveHistory);
  void clearSelection({bool saveHistory = true}) =>
      selectionManager.clearSelection(saveHistory: saveHistory);
  void invertSelection() => selectionManager.invertSelection(_canvasSize);
  void setPreviewPath(Path? path) => selectionManager.setPreviewPath(path);
  void clearPreview() => selectionManager.clearPreview();
  bool get isTransforming => selectionManager.isTransforming;

  // ===== 代理方法：笔画 =====

  /// 将点裁剪到画布范围内
  Offset _clampToCanvas(Offset point) {
    return Offset(
      point.dx.clamp(0, _canvasSize.width),
      point.dy.clamp(0, _canvasSize.height),
    );
  }

  void startStroke(Offset point) {
    // 将点裁剪到画布范围内，防止画布外涂抹
    strokeManager.startStroke(_clampToCanvas(point));
    _notifyStrokePreviewChange();
  }

  void updateStroke(Offset point) {
    // 将点裁剪到画布范围内，防止画布外涂抹
    strokeManager.updateStroke(_clampToCanvas(point));
    _notifyStrokePreviewChangeCoalesced();
  }

  void endStroke() {
    _flushPendingStrokePreviewChange();
    strokeManager.endStroke();
    _notifyStrokePreviewChange();
    _updateActiveLayerCacheIfNeeded();
    // 笔画完成后异步预热快照，供拾色器使用
    _scheduleSnapshotUpdate();
  }

  void cancelStroke() {
    _pendingStrokePreviewChange = false;
    strokeManager.cancelStroke();
    selectionManager.clearPreview();
    _notifyStrokePreviewChange();
  }

  // ===== 画布方法 =====

  void setCanvasSize(Size size) {
    _canvasSize = size;
    if (_isBatching) {
      _pendingBatchedCanvasSizeNotification = true;
    } else {
      canvasSizeNotifier.value = size;
    }
    _notifyRenderChange();
    _safeNotifyListeners();
  }

  /// 更新画布快照（供拾色器使用）
  Future<bool> updateCanvasSnapshot() async {
    return await layerManager.updateSnapshotAsync(_canvasSize);
  }

  // ===== 笔刷方法 =====

  double get brushSize {
    final tool = toolManager.currentTool;
    if (tool is BrushTool) {
      return tool.settings.size;
    } else if (tool is EraserTool) {
      return tool.size;
    }
    final brushTool = toolManager.tools.whereType<BrushTool>().firstOrNull;
    return brushTool?.settings.size ?? 20.0;
  }

  void setBrushSize(double size) {
    final tool = toolManager.currentTool;
    if (tool is BrushTool) {
      tool.setSize(size);
    } else if (tool is EraserTool) {
      tool.setSize(size);
    }
    notifyListeners();
  }

  double get brushOpacity {
    final tool = toolManager.currentTool;
    if (tool is BrushTool) {
      return tool.settings.opacity;
    }
    return 1.0;
  }

  void setBrushOpacity(double opacity) {
    final tool = toolManager.currentTool;
    if (tool is BrushTool) {
      tool.setOpacity(opacity);
      notifyListeners();
    }
  }

  void increaseBrushOpacity({double step = 0.1}) {
    setBrushOpacity((brushOpacity + step).clamp(0.0, 1.0));
  }

  void decreaseBrushOpacity({double step = 0.1}) {
    setBrushOpacity((brushOpacity - step).clamp(0.0, 1.0));
  }

  void setBrushHardness(double hardness) {
    final tool = toolManager.currentTool;
    if (tool is BrushTool) {
      tool.setHardness(hardness);
      notifyListeners();
    } else if (tool is EraserTool) {
      tool.setHardness(hardness);
      notifyListeners();
    }
  }

  // ===== 撤销/重做 =====

  bool undo() {
    // 优先撤销选区
    if (toolManager.currentTool?.isSelectionTool == true &&
        selectionManager.canUndoSelection) {
      selectionManager.undoSelection();
      return true;
    }

    // 撤销绘画操作
    final result = historyManager.undo(this);
    if (result) {
      notifyListeners();
    }
    return result;
  }

  bool redo() {
    // 优先重做选区
    if (toolManager.currentTool?.isSelectionTool == true &&
        selectionManager.canRedoSelection) {
      selectionManager.redoSelection();
      return true;
    }

    // 重做绘画操作
    final result = historyManager.redo(this);
    if (result) {
      notifyListeners();
    }
    return result;
  }

  bool get canUndo {
    if (toolManager.currentTool?.isSelectionTool == true) {
      return selectionManager.canUndoSelection || historyManager.canUndo;
    }
    return historyManager.canUndo;
  }

  bool get canRedo {
    if (toolManager.currentTool?.isSelectionTool == true) {
      return selectionManager.canRedoSelection || historyManager.canRedo;
    }
    return historyManager.canRedo;
  }

  /// 清空当前图层（支持撤销）
  void clearActiveLayerWithHistory() {
    final layer = layerManager.activeLayer;
    if (layer == null || layer.locked || !layer.hasContent) return;

    historyManager.execute(ClearLayerAction(layerId: layer.id), this);
  }

  /// 调整画布大小（支持撤销）
  void resizeCanvas(Size newSize, CanvasResizeMode mode) {
    // 如果新尺寸与当前尺寸相同，则不执行操作
    if (_canvasSize == newSize) return;

    historyManager.execute(
      ResizeCanvasAction(newSize: newSize, mode: mode),
      this,
    );
  }

  // ===== 选区操作 =====

  /// 将选区内容剪切到新图层
  Future<bool> cutSelectionToNewLayer() async {
    final selection = selectionManager.selectionPath;
    final activeLayer = layerManager.activeLayer;
    if (selection == null || activeLayer == null || activeLayer.locked) {
      return false;
    }

    final w = _canvasSize.width.toInt();
    final h = _canvasSize.height.toInt();
    if (w <= 0 || h <= 0) return false;

    final layerImg = await _renderLayerToImage(activeLayer, _canvasSize, w, h);

    final cutImg = await _extractSelection(layerImg, selection, w, h);
    final remainImg = await _eraseSelection(layerImg, selection, w, h);
    layerImg.dispose();

    final cutPng = await cutImg.toByteData(format: ui.ImageByteFormat.png);
    final remainPng = await remainImg.toByteData(
      format: ui.ImageByteFormat.png,
    );
    if (cutPng == null || remainPng == null) {
      cutImg.dispose();
      remainImg.dispose();
      return false;
    }

    historyManager.execute(
      ReplaceLayerImageAction(
        layerId: activeLayer.id,
        newImageBytes: remainPng.buffer.asUint8List(),
        newImage: remainImg,
        actionDescription: 'Cut Selection',
      ),
      this,
    );

    final cutLayer = layerManager.addLayer(
      name: '${activeLayer.name} (Selection)',
    );
    await cutLayer.setBaseImage(cutPng.buffer.asUint8List());
    cutImg.dispose();

    selectionManager.clearSelection();
    _notifyRenderChange();
    notifyListeners();
    return true;
  }

  Future<ui.Image> _renderLayerToImage(
    dynamic layer,
    Size canvasSize,
    int w,
    int h,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    (layer as dynamic).render(c, canvasSize);
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  Future<ui.Image> _extractSelection(
    ui.Image source,
    Path selection,
    int w,
    int h,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.clipPath(selection);
    c.drawImage(source, Offset.zero, Paint());
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  Future<ui.Image> _eraseSelection(
    ui.Image source,
    Path selection,
    int w,
    int h,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(source, Offset.zero, Paint());
    c.save();
    c.clipPath(selection);
    c.drawRect(
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..blendMode = BlendMode.clear,
    );
    c.restore();
    final pic = rec.endRecording();
    final img = await pic.toImage(w, h);
    pic.dispose();
    return img;
  }

  // ===== 内部方法 =====

  void _onLayerChanged() {
    _notifyRenderChange();
    _safeNotifyListeners();
  }

  void _onCanvasChanged() {
    _notifyRenderChange();
    _safeNotifyListeners();
  }

  void _onColorChanged() {
    _safeNotifyListeners();
  }

  void _onSelectionChanged() {
    _notifyRenderChange();
  }

  void _onStrokeChanged() {
    // strokeManager 的变化已在代理方法中处理
  }

  /// 通知画布需要重绘（供工具调用）
  void notifyRenderChange() {
    if (_isDisposed) return;
    if (_isBatching) {
      _pendingBatchedRenderChange = true;
      return;
    }

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    renderNotifier.notifyListeners();
  }

  void _notifyRenderChange() => notifyRenderChange();

  void _notifyStrokePreviewChange() {
    if (_isDisposed) return;
    _pendingStrokePreviewChange = false;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    strokePreviewNotifier.notifyListeners();
  }

  void _notifyStrokePreviewChangeCoalesced() {
    if (_isDisposed) return;

    _pendingStrokePreviewChange = true;
    if (_strokePreviewFrameScheduled) return;

    _strokePreviewFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _strokePreviewFrameScheduled = false;
      if (_isDisposed || !_pendingStrokePreviewChange) return;

      _pendingStrokePreviewChange = false;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      strokePreviewNotifier.notifyListeners();
    });
  }

  void _flushPendingStrokePreviewChange() {
    if (!_pendingStrokePreviewChange) return;
    _notifyStrokePreviewChange();
  }

  void _safeNotifyListeners() {
    if (_isBatching) {
      _pendingBatchedStateNotification = true;
      return;
    }

    if (_isNotifying) return;
    _isNotifying = true;
    try {
      notifyListeners();
    } finally {
      _isNotifying = false;
    }
  }

  /// 请求 UI 更新（供外部调用，如工具设置面板）
  void requestUiUpdate() {
    _safeNotifyListeners();
  }

  void _setToolChangeNotifier(EditorTool tool) {
    if (_isBatching) {
      _pendingBatchedToolChange = tool;
      _pendingBatchedToolChangeNotification = true;
      return;
    }

    toolChangeNotifier.value = tool;
  }

  T runBatch<T>(T Function() body) {
    _batchDepth++;
    toolManager.beginBatch();
    try {
      return body();
    } finally {
      toolManager.endBatch();
      _endBatch();
    }
  }

  Future<T> runBatchAsync<T>(Future<T> Function() body) async {
    _batchDepth++;
    toolManager.beginBatch();
    try {
      return await body();
    } finally {
      toolManager.endBatch();
      _endBatch();
    }
  }

  void _endBatch() {
    if (_batchDepth == 0) {
      return;
    }

    _batchDepth--;
    if (_batchDepth > 0 || _isDisposed) {
      return;
    }

    final notifyCanvasSize = _pendingBatchedCanvasSizeNotification;
    final notifyToolChange = _pendingBatchedToolChangeNotification;
    final pendingToolChange = _pendingBatchedToolChange;
    final notifyRender = _pendingBatchedRenderChange;
    final notifyState = _pendingBatchedStateNotification;

    _pendingBatchedCanvasSizeNotification = false;
    _pendingBatchedToolChangeNotification = false;
    _pendingBatchedToolChange = null;
    _pendingBatchedRenderChange = false;
    _pendingBatchedStateNotification = false;

    if (notifyCanvasSize) {
      canvasSizeNotifier.value = _canvasSize;
    }
    if (notifyToolChange && pendingToolChange != null) {
      toolChangeNotifier.value = pendingToolChange;
    }
    if (notifyRender) {
      notifyRenderChange();
    }
    if (notifyState) {
      _safeNotifyListeners();
    }
  }

  Future<void> _updateActiveLayerCacheIfNeeded() async {
    final layer = layerManager.activeLayer;
    if (layer != null && layer.shouldRasterizeNow()) {
      await layer.rasterize(_canvasSize);
      await layer.updateCompositeCache(_canvasSize);
      _notifyRenderChange();
    }
  }

  /// 延迟更新快照（下一帧异步执行）
  /// 用于笔画完成后预热拾色器快照
  void _scheduleSnapshotUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isDisposed) return;
      await layerManager.updateSnapshotAsync(_canvasSize);
    });
  }

  // ===== 重置与初始化 =====

  void reset() {
    layerManager.clear();
    historyManager.clear();
    colorManager.reset();
    selectionManager.reset();
    strokeManager.reset();
    canvasController.reset();
    notifyListeners();
  }

  void initNewCanvas(Size size, {String? initialLayerName}) {
    reset();
    _canvasSize = size;
    canvasSizeNotifier.value = size;
    layerManager.addLayer(name: initialLayerName ?? 'Layer 1');
    // 同步初始工具到通知器
    toolChangeNotifier.value = toolManager.currentTool;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pendingStrokePreviewChange = false;

    // 移除监听器
    layerManager.removeListener(_onLayerChanged);
    canvasController.removeListener(_onCanvasChanged);
    colorManager.removeListener(_onColorChanged);
    selectionManager.removeListener(_onSelectionChanged);
    strokeManager.removeListener(_onStrokeChanged);

    // 释放管理器
    toolManager.dispose();
    colorManager.dispose();
    selectionManager.dispose();
    strokeManager.dispose();
    layerManager.dispose();
    canvasController.dispose();
    historyManager.dispose();

    // 释放通知器
    renderNotifier.dispose();
    strokePreviewNotifier.dispose();
    toolChangeNotifier.dispose();
    canvasSizeNotifier.dispose();

    super.dispose();
  }
}
