import 'package:flutter/material.dart';

/// 选区管理器
/// 负责选区的创建、修改、历史记录等操作
class SelectionManager extends ChangeNotifier {
  /// 全局选区路径
  Path? _selectionPath;
  Path? get selectionPath => _selectionPath;

  /// 选区历史（用于撤销）
  final List<Path?> _selectionHistory = [];
  final List<Path?> _selectionRedoStack = [];
  static const int _maxSelectionHistory = 30;

  /// 当前选区预览（用于绘制时显示）
  Rect? _selectionPreview;
  Rect? get selectionPreview => _selectionPreview;

  /// 套索选区临时路径
  Path? _lassoPreviewPath;
  Path? get lassoPreviewPath => _lassoPreviewPath;

  /// 选区变化通知器（用于仅需要监听选区变化的场景）
  final ValueNotifier<Path?> selectionNotifier = ValueNotifier(null);

  /// 是否有选区
  bool get hasSelection => _selectionPath != null;

  /// 是否可以撤销选区
  bool get canUndoSelection => _selectionHistory.isNotEmpty;

  /// 是否可以重做选区
  bool get canRedoSelection => _selectionRedoStack.isNotEmpty;

  /// 保存选区历史
  void _saveHistory() {
    _selectionHistory
        .add(_selectionPath != null ? Path.from(_selectionPath!) : null);
    _selectionRedoStack.clear();
    while (_selectionHistory.length > _maxSelectionHistory) {
      _selectionHistory.removeAt(0);
    }
  }

  /// 设置选区
  void setSelection(Path? path, {bool saveHistory = true}) {
    if (saveHistory) {
      _saveHistory();
    }
    _selectionPath = path;
    selectionNotifier.value = path;
    notifyListeners();
  }

  /// 添加到选区
  void addToSelection(Path path) {
    _saveHistory();
    if (_selectionPath == null) {
      _selectionPath = path;
    } else {
      _selectionPath =
          Path.combine(PathOperation.union, _selectionPath!, path);
    }
    selectionNotifier.value = _selectionPath;
    notifyListeners();
  }

  /// 从选区减去
  void subtractFromSelection(Path path) {
    if (_selectionPath != null) {
      _saveHistory();
      _selectionPath =
          Path.combine(PathOperation.difference, _selectionPath!, path);
      selectionNotifier.value = _selectionPath;
      notifyListeners();
    }
  }

  /// 与选区交叉
  void intersectSelection(Path path) {
    if (_selectionPath != null) {
      _saveHistory();
      _selectionPath =
          Path.combine(PathOperation.intersect, _selectionPath!, path);
      selectionNotifier.value = _selectionPath;
      notifyListeners();
    }
  }

  /// 清除选区
  void clearSelection() {
    if (_selectionPath != null) {
      _saveHistory();
      _selectionPath = null;
      selectionNotifier.value = null;
      notifyListeners();
    }
  }

  /// 反转选区
  void invertSelection(Size canvasSize) {
    if (_selectionPath != null) {
      _saveHistory();
      final fullRect = Path()
        ..addRect(Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height));
      _selectionPath =
          Path.combine(PathOperation.difference, fullRect, _selectionPath!);
      selectionNotifier.value = _selectionPath;
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

  /// 撤销选区
  bool undoSelection() {
    if (_selectionHistory.isNotEmpty) {
      _selectionRedoStack
          .add(_selectionPath != null ? Path.from(_selectionPath!) : null);
      _selectionPath = _selectionHistory.removeLast();
      selectionNotifier.value = _selectionPath;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 重做选区
  bool redoSelection() {
    if (_selectionRedoStack.isNotEmpty) {
      _selectionHistory
          .add(_selectionPath != null ? Path.from(_selectionPath!) : null);
      _selectionPath = _selectionRedoStack.removeLast();
      selectionNotifier.value = _selectionPath;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// 清除预览
  void clearPreview() {
    _selectionPreview = null;
    _lassoPreviewPath = null;
    notifyListeners();
  }

  /// 重置
  void reset() {
    _selectionPath = null;
    _selectionHistory.clear();
    _selectionRedoStack.clear();
    _selectionPreview = null;
    _lassoPreviewPath = null;
    selectionNotifier.value = null;
    notifyListeners();
  }

  @override
  void dispose() {
    selectionNotifier.dispose();
    super.dispose();
  }
}
