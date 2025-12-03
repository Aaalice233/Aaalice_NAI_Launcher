import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../layers/layer.dart';
import '../layers/layer_manager.dart';
import '../tools/tool_base.dart';
import '../tools/brush_tool.dart';
import '../tools/eraser_tool.dart';
import '../tools/selection/rect_selection_tool.dart';
import '../tools/selection/ellipse_selection_tool.dart';
import '../tools/selection/lasso_selection_tool.dart';
import '../tools/color_picker_tool.dart';
import 'canvas_controller.dart';
import 'history_manager.dart';

/// 编辑器全局状态
/// 管理图层、工具、画布、历史记录等所有编辑器状态
class EditorState extends ChangeNotifier {
  /// 图层管理器
  final LayerManager layerManager = LayerManager();

  /// 画布控制器
  final CanvasController canvasController = CanvasController();

  /// 历史管理器
  final HistoryManager historyManager = HistoryManager();

  /// 可用工具列表
  late final List<EditorTool> _tools;

  /// 当前工具
  EditorTool? _currentTool;
  EditorTool? get currentTool => _currentTool;

  /// 上一个工具（用于拾色器自动切回）
  EditorTool? _previousTool;

  /// 前景色
  Color _foregroundColor = const Color(0xFF000000);
  Color get foregroundColor => _foregroundColor;

  /// 背景色
  Color _backgroundColor = const Color(0xFFFFFFFF);
  Color get backgroundColor => _backgroundColor;

  /// 画布尺寸
  Size _canvasSize = const Size(1024, 1024);
  Size get canvasSize => _canvasSize;

  /// 全局选区（用于Inpainting蒙版）
  Path? _selectionPath;
  Path? get selectionPath => _selectionPath;

  /// 选区历史（用于撤销）
  final List<Path?> _selectionHistory = [];
  final List<Path?> _selectionRedoStack = [];
  static const int _maxSelectionHistory = 30;

  /// 当前绘制的临时笔画点
  List<Offset> _currentStrokePoints = [];
  List<Offset> get currentStrokePoints => _currentStrokePoints;

  /// 当前选区预览（用于绘制时显示）
  Rect? _selectionPreview;
  Rect? get selectionPreview => _selectionPreview;

  /// 套索选区临时路径
  Path? _lassoPreviewPath;
  Path? get lassoPreviewPath => _lassoPreviewPath;

  /// 是否正在绘制
  bool _isDrawing = false;
  bool get isDrawing => _isDrawing;

  /// 防止通知重入的标志
  bool _isNotifying = false;

  /// 初始化
  EditorState() {
    _initTools();
    _currentTool = _tools.first;

    // 监听子管理器变化
    layerManager.addListener(_onLayerChanged);
    canvasController.addListener(_onCanvasChanged);
  }

  void _initTools() {
    _tools = [
      BrushTool(),
      EraserTool(),
      RectSelectionTool(),
      EllipseSelectionTool(),
      LassoSelectionTool(),
      ColorPickerTool(),
    ];
  }

  /// 获取所有工具
  List<EditorTool> get tools => List.unmodifiable(_tools);

  /// 设置当前工具
  void setTool(EditorTool tool) {
    if (_currentTool != tool) {
      _previousTool = _currentTool;
      _currentTool = tool;
      notifyListeners();
    }
  }

  /// 通过ID设置工具
  void setToolById(String toolId) {
    final tool = _tools.firstWhere(
      (t) => t.id == toolId,
      orElse: () => _tools.first,
    );
    setTool(tool);
  }

  /// 切回上一个工具
  void switchToPreviousTool() {
    if (_previousTool != null) {
      final temp = _currentTool;
      _currentTool = _previousTool;
      _previousTool = temp;
      notifyListeners();
    }
  }

  /// 设置前景色
  void setForegroundColor(Color color) {
    _foregroundColor = color;
    notifyListeners();
  }

  /// 设置背景色
  void setBackgroundColor(Color color) {
    _backgroundColor = color;
    notifyListeners();
  }

  /// 交换前景色和背景色
  void swapColors() {
    final temp = _foregroundColor;
    _foregroundColor = _backgroundColor;
    _backgroundColor = temp;
    notifyListeners();
  }

  /// 设置画布尺寸
  void setCanvasSize(Size size) {
    _canvasSize = size;
    notifyListeners();
  }

  /// 保存选区历史
  void _saveSelectionHistory() {
    _selectionHistory.add(_selectionPath != null ? Path.from(_selectionPath!) : null);
    _selectionRedoStack.clear();
    while (_selectionHistory.length > _maxSelectionHistory) {
      _selectionHistory.removeAt(0);
    }
  }

  /// 设置选区
  void setSelection(Path? path, {bool saveHistory = true}) {
    if (saveHistory) {
      _saveSelectionHistory();
    }
    _selectionPath = path;
    notifyListeners();
  }

  /// 添加到选区
  void addToSelection(Path path) {
    _saveSelectionHistory();
    if (_selectionPath == null) {
      _selectionPath = path;
    } else {
      _selectionPath = Path.combine(PathOperation.union, _selectionPath!, path);
    }
    notifyListeners();
  }

  /// 从选区减去
  void subtractFromSelection(Path path) {
    if (_selectionPath != null) {
      _saveSelectionHistory();
      _selectionPath = Path.combine(PathOperation.difference, _selectionPath!, path);
      notifyListeners();
    }
  }

  /// 与选区交叉
  void intersectSelection(Path path) {
    if (_selectionPath != null) {
      _saveSelectionHistory();
      _selectionPath = Path.combine(PathOperation.intersect, _selectionPath!, path);
      notifyListeners();
    }
  }

  /// 清除选区
  void clearSelection() {
    if (_selectionPath != null) {
      _saveSelectionHistory();
      _selectionPath = null;
      notifyListeners();
    }
  }

  /// 反转选区
  void invertSelection() {
    if (_selectionPath != null) {
      _saveSelectionHistory();
      final fullRect = Path()..addRect(Rect.fromLTWH(0, 0, _canvasSize.width, _canvasSize.height));
      _selectionPath = Path.combine(PathOperation.difference, fullRect, _selectionPath!);
      notifyListeners();
    }
  }

  /// 设置选区预览
  void setSelectionPreview(Rect? rect) {
    _selectionPreview = rect;
    notifyListeners();
  }

  /// 设置套索预览路径
  void setLassoPreviewPath(Path? path) {
    _lassoPreviewPath = path;
    notifyListeners();
  }

  /// 开始绘制
  void startStroke(Offset point) {
    _isDrawing = true;
    _currentStrokePoints = [point];
    notifyListeners();
  }

  /// 更新绘制
  void updateStroke(Offset point) {
    if (_isDrawing) {
      _currentStrokePoints.add(point);
      notifyListeners();
    }
  }

  /// 结束绘制
  void endStroke() {
    _isDrawing = false;
    _currentStrokePoints = [];
    notifyListeners();
  }

  /// 取消绘制
  void cancelStroke() {
    _isDrawing = false;
    _currentStrokePoints = [];
    _selectionPreview = null;
    _lassoPreviewPath = null;
    notifyListeners();
  }

  /// 撤销
  bool undo() {
    // 优先撤销选区
    if (_currentTool?.isSelectionTool == true && _selectionHistory.isNotEmpty) {
      _selectionRedoStack.add(_selectionPath != null ? Path.from(_selectionPath!) : null);
      _selectionPath = _selectionHistory.removeLast();
      notifyListeners();
      return true;
    }

    // 撤销绘画操作
    final result = historyManager.undo(this);
    if (result) {
      notifyListeners();
    }
    return result;
  }

  /// 重做
  bool redo() {
    // 优先重做选区
    if (_currentTool?.isSelectionTool == true && _selectionRedoStack.isNotEmpty) {
      _selectionHistory.add(_selectionPath != null ? Path.from(_selectionPath!) : null);
      _selectionPath = _selectionRedoStack.removeLast();
      notifyListeners();
      return true;
    }

    // 重做绘画操作
    final result = historyManager.redo(this);
    if (result) {
      notifyListeners();
    }
    return result;
  }

  /// 是否可以撤销
  bool get canUndo {
    if (_currentTool?.isSelectionTool == true) {
      return _selectionHistory.isNotEmpty || historyManager.canUndo;
    }
    return historyManager.canUndo;
  }

  /// 是否可以重做
  bool get canRedo {
    if (_currentTool?.isSelectionTool == true) {
      return _selectionRedoStack.isNotEmpty || historyManager.canRedo;
    }
    return historyManager.canRedo;
  }

  void _onLayerChanged() {
    _safeNotifyListeners();
  }

  void _onCanvasChanged() {
    _safeNotifyListeners();
  }

  /// 安全地通知监听器（防止重入）
  void _safeNotifyListeners() {
    if (_isNotifying) return;
    _isNotifying = true;
    try {
      notifyListeners();
    } finally {
      _isNotifying = false;
    }
  }

  /// 重置编辑器状态
  void reset() {
    layerManager.clear();
    historyManager.clear();
    _selectionPath = null;
    _selectionHistory.clear();
    _selectionRedoStack.clear();
    _currentStrokePoints = [];
    _isDrawing = false;
    _selectionPreview = null;
    _lassoPreviewPath = null;
    canvasController.reset();
    notifyListeners();
  }

  /// 初始化新画布
  void initNewCanvas(Size size) {
    reset();
    _canvasSize = size;
    layerManager.addLayer(name: '图层 1');
    notifyListeners();
  }

  @override
  void dispose() {
    layerManager.removeListener(_onLayerChanged);
    canvasController.removeListener(_onCanvasChanged);
    layerManager.dispose();
    canvasController.dispose();
    super.dispose();
  }
}
