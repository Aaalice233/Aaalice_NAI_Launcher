import 'package:flutter/material.dart';
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

  /// 工具切换通知器（仅工具栏和设置面板监听）
  /// 避免工具切换触发整个 EditorState 的监听者重建
  final ValueNotifier<EditorTool?> toolChangeNotifier = ValueNotifier(null);

  /// 画布尺寸通知器（仅画布尺寸相关 UI 监听）
  final ValueNotifier<Size> canvasSizeNotifier =
      ValueNotifier(const Size(1024, 1024));

  /// 光标位置通知器（仅光标绘制器监听）
  /// 避免光标移动触发整个 UI 重建
  final ValueNotifier<Offset?> cursorNotifier = ValueNotifier(null);

  // ===== 画布状态 =====

  /// 画布尺寸
  Size _canvasSize = const Size(1024, 1024);
  Size get canvasSize => _canvasSize;

  // ===== 内部状态 =====

  /// 防止通知重入的标志
  bool _isNotifying = false;

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
    toolChangeNotifier.value = tool;

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
      toolChangeNotifier.value = tool;
      _scheduleToolActivation(tool);
    }
  }

  /// 延迟执行工具激活逻辑（下一帧异步执行）
  /// 用于资源预热、缓存更新等，不阻塞工具切换
  void _scheduleToolActivation(EditorTool tool) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 确保工具仍然是当前工具（防止快速连续切换）
      if (toolManager.currentTool == tool) {
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
    _notifyRenderChange();
  }

  void updateStroke(Offset point) {
    // 将点裁剪到画布范围内，防止画布外涂抹
    strokeManager.updateStroke(_clampToCanvas(point));
    _notifyRenderChange();
  }

  void endStroke() {
    strokeManager.endStroke();
    _notifyRenderChange();
    _updateActiveLayerCacheIfNeeded();
    // 笔画完成后异步预热快照，供拾色器使用
    _scheduleSnapshotUpdate();
  }

  void cancelStroke() {
    strokeManager.cancelStroke();
    selectionManager.clearPreview();
    _notifyRenderChange();
  }

  // ===== 画布方法 =====

  void setCanvasSize(Size size) {
    _canvasSize = size;
    canvasSizeNotifier.value = size;
    notifyListeners();
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
    if (layer == null || layer.locked || layer.strokes.isEmpty) return;

    historyManager.execute(
      ClearLayerAction(layerId: layer.id),
      this,
    );
  }

  /// 调整画布大小（支持撤销）
  void resizeCanvas(Size newSize, CanvasResizeMode mode) {
    // 如果新尺寸与当前尺寸相同，则不执行操作
    if (_canvasSize == newSize) return;

    historyManager.execute(
      ResizeCanvasAction(
        newSize: newSize,
        mode: mode,
      ),
      this,
    );
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

  void _notifyRenderChange() {
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    renderNotifier.notifyListeners();
  }

  void _safeNotifyListeners() {
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

  void initNewCanvas(Size size) {
    reset();
    _canvasSize = size;
    canvasSizeNotifier.value = size;
    layerManager.addLayer(name: '图层 1');
    // 同步初始工具到通知器
    toolChangeNotifier.value = toolManager.currentTool;
    notifyListeners();
  }

  @override
  void dispose() {
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
    toolChangeNotifier.dispose();
    canvasSizeNotifier.dispose();

    super.dispose();
  }
}
