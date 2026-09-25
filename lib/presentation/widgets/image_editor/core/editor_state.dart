import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../frame/editor_frame_commands.dart';
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

enum MagicWandSelectionMode { colorArea, smartObject }

typedef MagicWandHandler =
    Future<void> Function(
      Offset canvasPoint, {
      required MagicWandSelectionMode mode,
      required int tolerance,
      required bool invert,
    });

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

  /// 取景框通知器（位置或尺寸变化都会通知）
  final ValueNotifier<Rect> frameNotifier = ValueNotifier(
    const Rect.fromLTWH(0, 0, 1024, 1024),
  );

  /// 取景框平移预览，只影响绘制，提交前不参与导出
  final ValueNotifier<Rect?> framePreviewNotifier = ValueNotifier(null);

  /// 光标位置通知器（仅光标绘制器监听）
  /// 避免光标移动触发整个 UI 重建
  final ValueNotifier<Offset?> cursorNotifier = ValueNotifier(null);

  // ===== 画布状态 =====

  /// 取景框：文档坐标中实际导出、送去生成的区域
  Rect _frame = const Rect.fromLTWH(0, 0, 1024, 1024);
  Rect get frame => _frame;

  /// 取景框尺寸，沿用画布尺寸的读法
  Size get canvasSize => _frame.size;

  /// 绘制用取景框，平移预览期间跟随预览
  Rect get displayFrame => framePreviewNotifier.value ?? _frame;

  /// 编辑模式的像素工具依赖取景框固定在原点，只有重绘模式允许离开原点
  bool allowsDetachedFrame = false;

  EditorFrameCommands? _frameCommands;
  EditorFrameCommands? get frameCommands => _frameCommands;

  Rect Function(Rect candidate, Offset fixedAnchor)? _rectSelectionConstraint;
  MagicWandHandler? _magicWandHandler;

  // ===== 内部状态 =====

  /// 防止通知重入的标志
  bool _isNotifying = false;

  bool _isDisposed = false;
  bool _strokePreviewFrameScheduled = false;
  bool _pendingStrokePreviewChange = false;
  int _batchDepth = 0;
  bool _pendingBatchedRenderChange = false;
  bool _pendingBatchedStateNotification = false;
  bool _pendingBatchedFrameNotification = false;
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

  void setMagicWandHandler(MagicWandHandler? handler) {
    _magicWandHandler = handler;
  }

  void setFrameCommands(EditorFrameCommands? commands) {
    _frameCommands = commands;
  }

  Future<void> applyMagicWand(
    Offset canvasPoint, {
    required MagicWandSelectionMode mode,
    required int tolerance,
    required bool invert,
  }) async {
    await _magicWandHandler?.call(
      canvasPoint,
      mode: mode,
      tolerance: tolerance,
      invert: invert,
    );
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
  void invertSelection() => selectionManager.invertSelection(_frame);
  void setPreviewPath(Path? path) => selectionManager.setPreviewPath(path);
  void clearPreview() => selectionManager.clearPreview();
  bool get isTransforming => selectionManager.isTransforming;

  // ===== 代理方法：笔画 =====

  /// 将点裁剪到取景框范围内
  Offset _clampToFrame(Offset point) {
    return Offset(
      point.dx.clamp(_frame.left, _frame.right),
      point.dy.clamp(_frame.top, _frame.bottom),
    );
  }

  void startStroke(Offset point) {
    // 将点裁剪到取景框范围内，防止框外涂抹
    strokeManager.startStroke(_clampToFrame(point));
    _notifyStrokePreviewChange();
  }

  void updateStroke(Offset point) {
    // 将点裁剪到取景框范围内，防止框外涂抹
    strokeManager.updateStroke(_clampToFrame(point));
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

  /// 保持取景框原点，只改尺寸
  void setCanvasSize(Size size) {
    setFrame(Rect.fromLTWH(_frame.left, _frame.top, size.width, size.height));
  }

  void setFrame(Rect frame) {
    assert(
      allowsDetachedFrame || frame.topLeft == Offset.zero,
      'Only the inpaint editor may move the frame away from the origin.',
    );
    _frame = frame;
    // 拾色快照只覆盖旧框区域
    layerManager.invalidateSnapshot();
    if (_isBatching) {
      _pendingBatchedFrameNotification = true;
    } else {
      _publishFrame();
    }
    _notifyRenderChange();
    _safeNotifyListeners();
  }

  void setFramePreview(Rect? preview) {
    if (framePreviewNotifier.value == preview) return;
    framePreviewNotifier.value = preview;
    _notifyRenderChange();
  }

  void _publishFrame() {
    canvasSizeNotifier.value = _frame.size;
    frameNotifier.value = _frame;
  }

  /// 更新画布快照（供拾色器使用）
  Future<bool> updateCanvasSnapshot() async {
    return await layerManager.updateSnapshotAsync(_frame);
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
    if (canvasSize == newSize) return;

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

    final region = _frame;
    if (region.isEmpty) return false;

    final layerImg = await activeLayer.renderToImage(region);

    final cutImg = await _extractSelection(layerImg, selection, region);
    final remainImg = await _eraseSelection(layerImg, selection, region);
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
        newImageOffset: region.topLeft,
        actionDescription: 'Cut Selection',
      ),
      this,
    );

    final cutLayer = layerManager.addLayer(
      name: '${activeLayer.name} (Selection)',
    );
    await cutLayer.setBaseImage(cutPng.buffer.asUint8List());
    cutLayer.setBaseImageOffset(region.topLeft);
    cutImg.dispose();

    selectionManager.clearSelection();
    _notifyRenderChange();
    notifyListeners();
    return true;
  }

  Future<ui.Image> _extractSelection(
    ui.Image source,
    Path selection,
    Rect region,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(-region.left, -region.top);
    c.clipPath(selection);
    c.drawImage(source, region.topLeft, Paint());
    final pic = rec.endRecording();
    final img = await pic.toImage(
      region.width.round(),
      region.height.round(),
    );
    pic.dispose();
    return img;
  }

  Future<ui.Image> _eraseSelection(
    ui.Image source,
    Path selection,
    Rect region,
  ) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(-region.left, -region.top);
    c.drawImage(source, region.topLeft, Paint());
    c.save();
    c.clipPath(selection);
    c.drawRect(region, Paint()..blendMode = BlendMode.clear);
    c.restore();
    final pic = rec.endRecording();
    final img = await pic.toImage(
      region.width.round(),
      region.height.round(),
    );
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

  /// 光标位置未变但视觉参数变了（如 Shift 拖拽调笔刷半径）时强制光标层重绘
  void notifyCursorVisualChange() {
    if (_isDisposed) return;

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    cursorNotifier.notifyListeners();
  }

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

    final notifyFrame = _pendingBatchedFrameNotification;
    final notifyToolChange = _pendingBatchedToolChangeNotification;
    final pendingToolChange = _pendingBatchedToolChange;
    final notifyRender = _pendingBatchedRenderChange;
    final notifyState = _pendingBatchedStateNotification;

    _pendingBatchedFrameNotification = false;
    _pendingBatchedToolChangeNotification = false;
    _pendingBatchedToolChange = null;
    _pendingBatchedRenderChange = false;
    _pendingBatchedStateNotification = false;

    if (notifyFrame) {
      _publishFrame();
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
      await layer.rasterize();
      await layer.updateCompositeCache();
      _notifyRenderChange();
    }
  }

  /// 延迟更新快照（下一帧异步执行）
  /// 用于笔画完成后预热拾色器快照
  void _scheduleSnapshotUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_isDisposed) return;
      await layerManager.updateSnapshotAsync(_frame);
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
    framePreviewNotifier.value = null;
    notifyListeners();
  }

  void initNewCanvas(Size size, {String? initialLayerName}) {
    reset();
    _frame = Offset.zero & size;
    _publishFrame();
    layerManager.addLayer(name: initialLayerName ?? 'Layer 1');
    // 同步初始工具到通知器
    toolChangeNotifier.value = toolManager.currentTool;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pendingStrokePreviewChange = false;
    _magicWandHandler = null;
    _frameCommands = null;

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
    // 撤销栈里的动作持有底图克隆，关闭编辑器时一并释放
    historyManager.clear();
    historyManager.dispose();

    // 释放通知器
    renderNotifier.dispose();
    strokePreviewNotifier.dispose();
    toolChangeNotifier.dispose();
    canvasSizeNotifier.dispose();
    frameNotifier.dispose();
    framePreviewNotifier.dispose();

    super.dispose();
  }
}
