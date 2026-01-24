import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../../core/utils/app_logger.dart';
import 'editor_state.dart';
import '../layers/layer.dart';

/// 编辑器操作基类
abstract class EditorAction {
  /// 执行操作
  void execute(EditorState state);

  /// 撤销操作
  void undo(EditorState state);

  /// 操作描述
  String get description;

  /// 操作时间戳
  final DateTime timestamp = DateTime.now();
}

/// 历史管理器
/// 使用命令模式管理撤销/重做
class HistoryManager extends ChangeNotifier {
  /// 撤销栈
  final List<EditorAction> _undoStack = [];

  /// 重做栈
  final List<EditorAction> _redoStack = [];

  /// 最大历史记录数
  static const int maxHistorySize = 100;

  /// 是否可以撤销
  bool get canUndo => _undoStack.isNotEmpty;

  /// 是否可以重做
  bool get canRedo => _redoStack.isNotEmpty;

  /// 撤销栈大小
  int get undoStackSize => _undoStack.length;

  /// 重做栈大小
  int get redoStackSize => _redoStack.length;

  /// 执行操作
  void execute(EditorAction action, EditorState state) {
    action.execute(state);
    _undoStack.add(action);
    _redoStack.clear();

    // 限制历史记录大小
    while (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
    notifyListeners();
  }

  /// 撤销
  bool undo(EditorState state) {
    if (_undoStack.isEmpty) return false;

    final action = _undoStack.removeLast();
    action.undo(state);
    _redoStack.add(action);
    notifyListeners();
    return true;
  }

  /// 重做
  bool redo(EditorState state) {
    if (_redoStack.isEmpty) return false;

    final action = _redoStack.removeLast();
    action.execute(state);
    _undoStack.add(action);
    notifyListeners();
    return true;
  }

  /// 清空历史
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  /// 获取撤销操作描述
  String? get undoDescription => _undoStack.isNotEmpty ? _undoStack.last.description : null;

  /// 获取重做操作描述
  String? get redoDescription => _redoStack.isNotEmpty ? _redoStack.last.description : null;
}

/// 添加笔画操作
class AddStrokeAction extends EditorAction {
  final String layerId;
  final StrokeData stroke;

  AddStrokeAction({
    required this.layerId,
    required this.stroke,
  });

  @override
  void execute(EditorState state) {
    state.layerManager.addStrokeToLayer(layerId, stroke);
  }

  @override
  void undo(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer == null) {
      AppLogger.w('Layer $layerId not found for undo', 'ImageEditor');
      return;
    }
    state.layerManager.removeLastStrokeFromLayer(layerId);
  }

  @override
  String get description => '绘制笔画';
}

/// 清除图层操作
class ClearLayerAction extends EditorAction {
  final String layerId;
  List<StrokeData>? _previousStrokes;

  ClearLayerAction({required this.layerId});

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer != null) {
      _previousStrokes = List.from(layer.strokes);
      state.layerManager.clearLayer(layerId);
    }
  }

  @override
  void undo(EditorState state) {
    if (_previousStrokes == null) return;
    for (final stroke in _previousStrokes!) {
      state.layerManager.addStrokeToLayer(layerId, stroke);
    }
  }

  @override
  String get description => '清除图层';
}

/// 添加图层操作
class AddLayerAction extends EditorAction {
  final String? name;
  String? _layerId;

  AddLayerAction({this.name});

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.addLayer(name: name);
    _layerId = layer.id;
  }

  @override
  void undo(EditorState state) {
    if (_layerId == null) return;
    state.layerManager.removeLayer(_layerId!);
  }

  @override
  String get description => '添加图层';
}

/// 删除图层操作
class DeleteLayerAction extends EditorAction {
  final String layerId;
  LayerData? _layerData;
  int? _index;

  DeleteLayerAction({required this.layerId});

  @override
  void execute(EditorState state) {
    final layer = state.layerManager.getLayerById(layerId);
    if (layer != null) {
      _layerData = layer.toData();
      _index = state.layerManager.layers.indexOf(layer);
      state.layerManager.removeLayer(layerId);
    }
  }

  @override
  void undo(EditorState state) {
    if (_layerData == null || _index == null) return;
    state.layerManager.insertLayerFromData(_layerData!, _index!);
  }

  @override
  String get description => '删除图层';
}

/// 合并图层操作
class MergeLayerAction extends EditorAction {
  final String topLayerId;
  final String bottomLayerId;
  LayerData? _topLayerData;
  LayerData? _bottomLayerData;
  int? _topIndex;
  int? _bottomIndex;
  bool _executed = false;

  MergeLayerAction({
    required this.topLayerId,
    required this.bottomLayerId,
  });

  @override
  void execute(EditorState state) {
    final topLayer = state.layerManager.getLayerById(topLayerId);
    final bottomLayer = state.layerManager.getLayerById(bottomLayerId);
    if (topLayer != null && bottomLayer != null) {
      _topLayerData = topLayer.toData();
      _bottomLayerData = bottomLayer.toData();
      _topIndex = state.layerManager.layers.indexOf(topLayer);
      _bottomIndex = state.layerManager.layers.indexOf(bottomLayer);
      state.layerManager.mergeLayers(topLayerId, bottomLayerId);
      _executed = true;
    }
  }

  @override
  void undo(EditorState state) {
    if (!_executed || _topLayerData == null || _bottomLayerData == null ||
        _topIndex == null || _bottomIndex == null) {
      return;
    }

    // 删除合并后的图层（合并后bottomLayer包含了所有内容）
    state.layerManager.removeLayer(bottomLayerId);

    // 按原顺序恢复图层
    // bottomIndex 总是小于 topIndex（bottom在下面）
    state.layerManager.insertLayerFromData(_bottomLayerData!, _bottomIndex!);
    state.layerManager.insertLayerFromData(_topLayerData!, _topIndex!);
  }

  @override
  String get description => '合并图层';
}

/// 图层重排序操作
class ReorderLayerAction extends EditorAction {
  final int oldIndex;
  final int newIndex;

  ReorderLayerAction({
    required this.oldIndex,
    required this.newIndex,
  });

  @override
  void execute(EditorState state) {
    state.layerManager.reorderLayer(oldIndex, newIndex);
  }

  @override
  void undo(EditorState state) {
    // 反向移动
    if (oldIndex < newIndex) {
      state.layerManager.reorderLayer(newIndex - 1, oldIndex);
    } else {
      state.layerManager.reorderLayer(newIndex, oldIndex);
    }
  }

  @override
  String get description => '重排图层';
}

/// 画布调整大小操作
class ResizeCanvasAction extends EditorAction {
  final Size newSize;
  Size? _previousSize;

  ResizeCanvasAction({required this.newSize});

  @override
  void execute(EditorState state) {
    _previousSize = state.canvasSize;
    state.setCanvasSize(newSize);
  }

  @override
  void undo(EditorState state) {
    if (_previousSize == null) return;
    state.setCanvasSize(_previousSize!);
  }

  @override
  String get description => '调整画布大小';
}

/// 笔画数据（用于历史记录）
class StrokeData {
  final List<Offset> points;
  final double size;
  final Color color;
  final double opacity;
  final double hardness;
  final bool isEraser;

  StrokeData({
    required this.points,
    required this.size,
    required this.color,
    required this.opacity,
    required this.hardness,
    this.isEraser = false,
  });

  StrokeData copyWith({
    List<Offset>? points,
    double? size,
    Color? color,
    double? opacity,
    double? hardness,
    bool? isEraser,
  }) {
    return StrokeData(
      points: points ?? this.points,
      size: size ?? this.size,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      hardness: hardness ?? this.hardness,
      isEraser: isEraser ?? this.isEraser,
    );
  }
}

/// 图层数据（用于序列化和历史记录）
class LayerData {
  final String id;
  final String name;
  final bool visible;
  final bool locked;
  final double opacity;
  final LayerBlendMode blendMode;
  final List<StrokeData> strokes;

  LayerData({
    required this.id,
    required this.name,
    required this.visible,
    required this.locked,
    required this.opacity,
    this.blendMode = LayerBlendMode.normal,
    required this.strokes,
  });
}
