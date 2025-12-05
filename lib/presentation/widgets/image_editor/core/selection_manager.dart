import 'package:flutter/material.dart';

/// 选区管理器
/// 负责选区的创建、修改、历史记录等操作
/// 选区同一时间只能存在一个
class SelectionManager extends ChangeNotifier {
  /// 已确认的选区路径
  Path? _selectionPath;
  Path? get selectionPath => _selectionPath;

  /// 绘制中的预览路径（统一用 Path）
  Path? _previewPath;
  Path? get previewPath => _previewPath;

  /// 选区历史（用于撤销）
  final List<Path?> _selectionHistory = [];
  final List<Path?> _selectionRedoStack = [];
  static const int _maxSelectionHistory = 30;

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

  /// 设置预览路径（绘制中）
  void setPreviewPath(Path? path) {
    _previewPath = path;
    notifyListeners();
  }

  /// 清除预览
  void clearPreview() {
    if (_previewPath != null) {
      _previewPath = null;
      notifyListeners();
    }
  }

  /// 设置选区（确认选区，清除预览）
  void setSelection(Path? path, {bool saveHistory = true}) {
    if (saveHistory) {
      _saveHistory();
    }
    _selectionPath = path;
    _previewPath = null; // 确认时清除预览
    selectionNotifier.value = path;
    notifyListeners();
  }

  /// 清除选区
  void clearSelection({bool saveHistory = true}) {
    if (_selectionPath != null) {
      if (saveHistory) {
        _saveHistory();
      }
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

  /// 重置
  void reset() {
    _selectionPath = null;
    _previewPath = null;
    _selectionHistory.clear();
    _selectionRedoStack.clear();
    selectionNotifier.value = null;
    notifyListeners();
  }

  @override
  void dispose() {
    selectionNotifier.dispose();
    super.dispose();
  }
}
