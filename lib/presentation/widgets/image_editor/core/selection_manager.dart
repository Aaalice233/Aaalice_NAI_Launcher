import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 选区变换状态
class SelectionTransform {
  const SelectionTransform({this.offset = Offset.zero, this.scale = 1.0});

  final Offset offset;
  final double scale;

  bool get isIdentity => offset == Offset.zero && scale == 1.0;

  SelectionTransform copyWith({Offset? offset, double? scale}) {
    return SelectionTransform(
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
    );
  }
}

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

  /// 选区变换状态（移动/缩放选中内容）
  SelectionTransform _transform = const SelectionTransform();
  SelectionTransform get transform => _transform;

  /// 是否处于变换模式
  bool _isTransforming = false;
  bool get isTransforming => _isTransforming;

  /// 变换模式下缓存的裁切内容
  ui.Image? _transformContent;
  ui.Image? get transformContent => _transformContent;

  /// 变换开始时的选区边界
  Rect? _transformBounds;
  Rect? get transformBounds => _transformBounds;

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
    _selectionHistory.add(
      _selectionPath != null ? Path.from(_selectionPath!) : null,
    );
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
      _selectionPath = Path.combine(
        PathOperation.difference,
        fullRect,
        _selectionPath!,
      );
      selectionNotifier.value = _selectionPath;
      notifyListeners();
    }
  }

  /// 撤销选区
  bool undoSelection() {
    if (_selectionHistory.isNotEmpty) {
      _selectionRedoStack.add(
        _selectionPath != null ? Path.from(_selectionPath!) : null,
      );
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
      _selectionHistory.add(
        _selectionPath != null ? Path.from(_selectionPath!) : null,
      );
      _selectionPath = _selectionRedoStack.removeLast();
      selectionNotifier.value = _selectionPath;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ===== 选区变换 =====

  /// 检测点是否在选区内部
  bool hitTestSelection(Offset point) {
    if (_selectionPath == null) return false;
    return _selectionPath!.contains(point);
  }

  /// 进入变换模式
  void enterTransform(ui.Image content) {
    if (_selectionPath == null) return;
    _isTransforming = true;
    _transformContent = content;
    _transformBounds = _selectionPath!.getBounds();
    _transform = const SelectionTransform();
    notifyListeners();
  }

  /// 更新变换偏移
  void updateTransformOffset(Offset delta) {
    if (!_isTransforming) return;
    _transform = _transform.copyWith(offset: _transform.offset + delta);
    notifyListeners();
  }

  /// 更新变换缩放
  void updateTransformScale(double scale) {
    if (!_isTransforming) return;
    _transform = _transform.copyWith(scale: scale.clamp(0.1, 10.0));
    notifyListeners();
  }

  /// 获取变换后的选区边界
  Rect? get transformedBounds {
    if (_transformBounds == null) return null;
    final b = _transformBounds!;
    return Rect.fromLTWH(
      b.left + _transform.offset.dx,
      b.top + _transform.offset.dy,
      b.width * _transform.scale,
      b.height * _transform.scale,
    );
  }

  /// 完成变换（返回 transform 和 bounds 给调用者处理像素合并）
  (SelectionTransform, Rect)? commitTransform() {
    if (!_isTransforming || _transformBounds == null) {
      cancelTransform();
      return null;
    }
    final result = (_transform, _transformBounds!);
    _isTransforming = false;
    _transformContent?.dispose();
    _transformContent = null;
    _transformBounds = null;
    _transform = const SelectionTransform();
    clearSelection();
    notifyListeners();
    return result;
  }

  /// 取消变换
  void cancelTransform() {
    _isTransforming = false;
    _transformContent?.dispose();
    _transformContent = null;
    _transformBounds = null;
    _transform = const SelectionTransform();
    notifyListeners();
  }

  /// 重置
  void reset() {
    cancelTransform();
    _selectionPath = null;
    _previewPath = null;
    _selectionHistory.clear();
    _selectionRedoStack.clear();
    selectionNotifier.value = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _transformContent?.dispose();
    selectionNotifier.dispose();
    super.dispose();
  }
}
