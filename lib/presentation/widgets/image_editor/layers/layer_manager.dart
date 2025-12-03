import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/history_manager.dart';
import 'layer.dart';

/// 图层管理器
/// 管理所有图层的增删改查、排序等操作
class LayerManager extends ChangeNotifier {
  /// 图层列表（从底到顶排列）
  final List<Layer> _layers = [];
  List<Layer> get layers => List.unmodifiable(_layers);

  /// 当前活动图层ID
  String? _activeLayerId;
  String? get activeLayerId => _activeLayerId;

  /// 是否正在更新缩略图（防止并发）
  bool _isUpdatingThumbnails = false;

  /// 获取当前活动图层
  Layer? get activeLayer {
    if (_activeLayerId == null || _layers.isEmpty) return null;

    // 使用 firstWhere 的 orElse 避免异常
    final layer = _layers.cast<Layer?>().firstWhere(
      (l) => l?.id == _activeLayerId,
      orElse: () => null,
    );

    if (layer != null) return layer;

    // 如果活动图层不存在，修复状态并返回最后一个图层
    if (_layers.isNotEmpty) {
      _activeLayerId = _layers.last.id;
      return _layers.last;
    }
    return null;
  }

  /// 图层数量
  int get layerCount => _layers.length;

  /// 是否为空
  bool get isEmpty => _layers.isEmpty;

  /// 添加图层
  Layer addLayer({String? name, int? index}) {
    final layerName = name ?? '图层 ${_layers.length + 1}';
    final layer = Layer(name: layerName);

    if (index != null && index >= 0 && index <= _layers.length) {
      _layers.insert(index, layer);
    } else {
      _layers.add(layer);
    }

    _activeLayerId = layer.id;
    notifyListeners();
    return layer;
  }

  /// 从数据插入图层
  Layer insertLayerFromData(LayerData data, int index) {
    final layer = Layer.fromData(data);
    if (index >= 0 && index <= _layers.length) {
      _layers.insert(index, layer);
    } else {
      _layers.add(layer);
    }
    notifyListeners();
    return layer;
  }

  /// 从图像数据创建图层
  ///
  /// 如果图像解码失败，返回 null 并清理资源
  Future<Layer?> addLayerFromImage(Uint8List imageBytes, {String? name, int? index}) async {
    final layerName = name ?? '导入的图像 ${_layers.length + 1}';
    final layer = Layer(name: layerName);

    try {
      // 设置基础图像
      await layer.setBaseImage(imageBytes);
    } catch (e) {
      // 解码失败，清理资源
      layer.dispose();
      debugPrint('Failed to add layer from image: $e');
      return null;
    }

    // 添加到指定位置或末尾
    if (index != null && index >= 0 && index <= _layers.length) {
      _layers.insert(index, layer);
    } else {
      _layers.add(layer);
    }

    _activeLayerId = layer.id;
    notifyListeners();
    return layer;
  }

  /// 从 ui.Image 创建图层
  ///
  /// **重要：此方法会接管 [image] 的所有权，调用者不应再使用或释放该图像。**
  Layer addLayerFromUiImage(ui.Image image, {String? name}) {
    final layerName = name ?? '导入的图像 ${_layers.length + 1}';
    final layer = Layer(name: layerName);

    // 设置基础图像（接管所有权）
    layer.setBaseImageFromImage(image);

    _layers.add(layer);
    _activeLayerId = layer.id;
    notifyListeners();
    return layer;
  }

  /// 删除图层
  bool removeLayer(String layerId) {
    final index = _layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return false;

    final layer = _layers.removeAt(index);
    layer.dispose();

    // 如果删除的是活动图层，选择相邻图层
    if (_activeLayerId == layerId) {
      if (_layers.isNotEmpty) {
        _activeLayerId = _layers[index.clamp(0, _layers.length - 1)].id;
      } else {
        _activeLayerId = null;
      }
    }

    notifyListeners();
    return true;
  }

  /// 复制图层
  Layer? duplicateLayer(String layerId) {
    final sourceLayer = getLayerById(layerId);
    if (sourceLayer == null) return null;

    final index = _layers.indexOf(sourceLayer);
    final cloned = sourceLayer.clone();
    _layers.insert(index + 1, cloned);
    _activeLayerId = cloned.id;

    notifyListeners();
    return cloned;
  }

  /// 合并图层（将上层合并到下层）
  bool mergeLayers(String topLayerId, String bottomLayerId) {
    final topLayer = getLayerById(topLayerId);
    final bottomLayer = getLayerById(bottomLayerId);
    if (topLayer == null || bottomLayer == null) return false;

    // 将上层笔画复制到下层（使用副本避免引用问题）
    for (final stroke in topLayer.strokes) {
      bottomLayer.addStroke(stroke.copyWith());
    }

    // 删除上层
    removeLayer(topLayerId);
    _activeLayerId = bottomLayerId;

    notifyListeners();
    return true;
  }

  /// 向下合并当前图层
  bool mergeDown() {
    if (_activeLayerId == null) return false;

    final activeIndex = _layers.indexWhere((l) => l.id == _activeLayerId);
    if (activeIndex <= 0) return false; // 已经是最底层

    final bottomLayer = _layers[activeIndex - 1];
    return mergeLayers(_activeLayerId!, bottomLayer.id);
  }

  /// 合并可见图层
  Layer? mergeVisible() {
    final visibleLayers = _layers.where((l) => l.visible).toList();
    if (visibleLayers.length < 2) return null;

    // 创建合并后的图层
    final merged = Layer(name: '合并的图层');

    // 按顺序合并所有可见图层的笔画（使用副本避免引用问题）
    for (final layer in visibleLayers) {
      for (final stroke in layer.strokes) {
        merged.addStroke(stroke.copyWith());
      }
    }

    // 删除原有可见图层
    for (final layer in visibleLayers) {
      _layers.remove(layer);
      layer.dispose();
    }

    // 添加合并后的图层
    _layers.add(merged);
    _activeLayerId = merged.id;

    notifyListeners();
    return merged;
  }

  /// 展平所有图层
  Layer? flattenAll() {
    if (_layers.isEmpty) return null;

    final flattened = Layer(name: '背景');

    for (final layer in _layers) {
      if (layer.visible) {
        for (final stroke in layer.strokes) {
          flattened.addStroke(stroke.copyWith());
        }
      }
    }

    // 清除所有图层
    for (final layer in _layers) {
      layer.dispose();
    }
    _layers.clear();

    // 添加展平后的图层
    _layers.add(flattened);
    _activeLayerId = flattened.id;

    notifyListeners();
    return flattened;
  }

  /// 重排图层
  void reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _layers.length) return;
    if (newIndex < 0 || newIndex >= _layers.length) return;
    if (oldIndex == newIndex) return;

    final layer = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, layer);
    notifyListeners();
  }

  /// 上移图层
  bool moveLayerUp(String layerId) {
    final index = _layers.indexWhere((l) => l.id == layerId);
    if (index == -1 || index >= _layers.length - 1) return false;

    reorderLayer(index, index + 1);
    return true;
  }

  /// 下移图层
  bool moveLayerDown(String layerId) {
    final index = _layers.indexWhere((l) => l.id == layerId);
    if (index <= 0) return false;

    reorderLayer(index, index - 1);
    return true;
  }

  /// 设置活动图层
  void setActiveLayer(String layerId) {
    if (_layers.any((l) => l.id == layerId)) {
      _activeLayerId = layerId;
      notifyListeners();
    }
  }

  /// 通过ID获取图层
  Layer? getLayerById(String id) {
    try {
      return _layers.firstWhere((l) => l.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 切换图层可见性
  void toggleVisibility(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.visible = !layer.visible;
      notifyListeners();
    }
  }

  /// 切换图层锁定
  void toggleLock(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.locked = !layer.locked;
      notifyListeners();
    }
  }

  /// 设置图层不透明度
  void setLayerOpacity(String layerId, double opacity) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.opacity = opacity.clamp(0.0, 1.0);
      layer.markNeedsUpdate();
      notifyListeners();
    }
  }

  /// 设置图层混合模式
  void setLayerBlendMode(String layerId, LayerBlendMode mode) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.blendMode = mode;
      notifyListeners();
    }
  }

  /// 重命名图层
  void renameLayer(String layerId, String newName) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.name = newName;
      notifyListeners();
    }
  }

  /// 向图层添加笔画
  void addStrokeToLayer(String layerId, StrokeData stroke) {
    final layer = getLayerById(layerId);
    if (layer != null && !layer.locked) {
      layer.addStroke(stroke);
      notifyListeners();
    }
  }

  /// 向当前图层添加笔画
  void addStrokeToActiveLayer(StrokeData stroke) {
    final layer = activeLayer;
    if (layer != null && !layer.locked) {
      layer.addStroke(stroke);
      notifyListeners();
    }
  }

  /// 移除图层最后一个笔画
  StrokeData? removeLastStrokeFromLayer(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      final stroke = layer.removeLastStroke();
      notifyListeners();
      return stroke;
    }
    return null;
  }

  /// 清除图层
  void clearLayer(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null && !layer.locked) {
      layer.clearStrokes();
      notifyListeners();
    }
  }

  /// 清除当前图层
  void clearActiveLayer() {
    if (_activeLayerId != null) {
      clearLayer(_activeLayerId!);
    }
  }

  /// 清除所有图层
  void clear() {
    for (final layer in _layers) {
      layer.dispose();
    }
    _layers.clear();
    _activeLayerId = null;
    notifyListeners();
  }

  /// 更新所有缩略图
  Future<void> updateAllThumbnails(Size canvasSize) async {
    if (_isUpdatingThumbnails) return;
    _isUpdatingThumbnails = true;

    try {
      // 创建快照避免并发修改
      final layersSnapshot = List<Layer>.from(_layers);
      for (final layer in layersSnapshot) {
        await layer.updateThumbnail(canvasSize);
      }
      notifyListeners();
    } finally {
      _isUpdatingThumbnails = false;
    }
  }

  /// 渲染所有可见图层到画布
  void renderAll(Canvas canvas, Size canvasSize) {
    for (final layer in _layers) {
      if (layer.visible) {
        layer.render(canvas, canvasSize);
      }
    }
  }

  /// 导出合并后的图像
  Future<ui.Image> exportMergedImage(Size canvasSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // 渲染所有图层
    renderAll(canvas, canvasSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
    picture.dispose();

    return image;
  }

  @override
  void dispose() {
    for (final layer in _layers) {
      layer.dispose();
    }
    super.dispose();
  }
}
