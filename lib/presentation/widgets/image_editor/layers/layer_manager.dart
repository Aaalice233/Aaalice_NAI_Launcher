import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/app_logger.dart';
import '../core/history_manager.dart';
import 'layer.dart';
import 'snapshot_cache.dart';

/// 图层管理器
/// 管理所有图层的增删改查、排序等操作
class LayerManager extends ChangeNotifier {
  /// 图层列表（从底到顶排列）
  final List<Layer> _layers = [];
  List<Layer> get layers => List.unmodifiable(_layers);

  /// 当前活动图层ID
  String? _activeLayerId;
  String? get activeLayerId => _activeLayerId;

  /// 活动图层变化通知器（仅UI更新，不触发画布重绘）
  final ValueNotifier<String?> activeLayerNotifier = ValueNotifier(null);

  /// UI状态变化通知器（锁定、重命名等不需要重绘画布的操作）
  final ValueNotifier<int> uiUpdateNotifier = ValueNotifier(0);

  /// 是否正在更新缩略图（防止并发）
  bool _isUpdatingThumbnails = false;

  // ===== 批量操作支持 =====

  /// 是否处于批量操作模式
  bool _isBatchMode = false;

  /// 批量操作期间是否有结构变化（图层增删、排序）
  bool _pendingStructureChange = false;

  /// 批量操作期间是否有内容变化（笔画添加）
  bool _pendingContentChange = false;

  // ===== 快照缓存管理器 =====

  /// 快照缓存管理器（延迟初始化）
  late final CanvasSnapshotManager _snapshotManager = CanvasSnapshotManager(
    renderCallback: renderAll,
  );

  /// 获取快照版本号
  int get snapshotVersion => _snapshotManager.snapshotVersion;

  /// 快照是否有效
  bool get hasValidSnapshot => _snapshotManager.hasValidSnapshot;

  /// 内部设置活动图层ID（同时更新 activeLayerNotifier 和 isActiveNotifier）
  void _setActiveLayerIdInternal(String? layerId) {
    // 旧活动图层：通知变为非活动
    final oldLayer = getLayerById(_activeLayerId ?? '');
    oldLayer?.isActiveNotifier.value = false;

    _activeLayerId = layerId;
    activeLayerNotifier.value = layerId;

    // 新活动图层：通知变为活动
    if (layerId != null) {
      final newLayer = getLayerById(layerId);
      newLayer?.isActiveNotifier.value = true;
    }
  }

  /// 仅通知UI更新（不触发画布重绘）
  void _notifyUiOnly() {
    uiUpdateNotifier.value++;
  }

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
      _setActiveLayerIdInternal(_layers.last.id);
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

    _setActiveLayerIdInternal(layer.id);
    invalidateSnapshot();
    notifyListeners();
    return layer;
  }

  /// 从数据插入图层
  /// [setActive] 为 true 时将新图层设为活动图层
  Layer insertLayerFromData(
    LayerData data,
    int index, {
    bool setActive = false,
  }) {
    final layer = Layer.fromData(data);
    if (index >= 0 && index <= _layers.length) {
      _layers.insert(index, layer);
    } else {
      _layers.add(layer);
    }

    if (setActive) {
      _setActiveLayerIdInternal(layer.id);
    }

    invalidateSnapshot();
    notifyListeners();
    return layer;
  }

  /// 从图像数据创建图层
  ///
  /// 如果图像解码失败，返回 null 并清理资源
  Future<Layer?> addLayerFromImage(
    Uint8List imageBytes, {
    String? name,
    int? index,
  }) async {
    final layerName = name ?? '导入的图像 ${_layers.length + 1}';
    final layer = Layer(name: layerName);

    try {
      // 设置基础图像
      await layer.setBaseImage(imageBytes);
    } catch (e) {
      // 解码失败，清理资源
      layer.dispose();
      AppLogger.w('Failed to add layer from image: $e', 'ImageEditor');
      return null;
    }

    // 添加到指定位置或末尾
    if (index != null && index >= 0 && index <= _layers.length) {
      _layers.insert(index, layer);
    } else {
      _layers.add(layer);
    }

    _setActiveLayerIdInternal(layer.id);
    invalidateSnapshot();
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
    _setActiveLayerIdInternal(layer.id);
    invalidateSnapshot();
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
        _setActiveLayerIdInternal(
          _layers[index.clamp(0, _layers.length - 1)].id,
        );
      } else {
        _setActiveLayerIdInternal(null);
      }
    }

    invalidateSnapshot();
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
    _setActiveLayerIdInternal(cloned.id);

    invalidateSnapshot();
    notifyListeners();
    return cloned;
  }

  /// 合并图层（将上层合并到下层）
  /// 使用批量操作优化，只触发一次通知
  bool mergeLayers(String topLayerId, String bottomLayerId) {
    final topLayer = getLayerById(topLayerId);
    final bottomLayer = getLayerById(bottomLayerId);
    if (topLayer == null || bottomLayer == null) return false;

    // 使用批量操作
    beginBatch();
    try {
      // 批量添加笔画（使用副本避免引用问题）
      final strokeCopies = topLayer.strokes.map((s) => s.copyWith()).toList();
      addStrokesBatch(bottomLayerId, strokeCopies);

      // 内部删除上层（不触发通知）
      _removeLayerInternal(topLayerId);
      _setActiveLayerIdInternal(bottomLayerId);
      _pendingStructureChange = true;
    } finally {
      endBatch();
    }

    return true;
  }

  /// 内部删除图层（不触发通知）
  /// 用于批量操作
  void _removeLayerInternal(String layerId) {
    final index = _layers.indexWhere((l) => l.id == layerId);
    if (index == -1) return;

    final layer = _layers.removeAt(index);
    layer.dispose();
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
  /// 使用批量操作优化，只触发一次通知
  Layer? mergeVisible() {
    final visibleLayers = _layers.where((l) => l.visible).toList();
    if (visibleLayers.length < 2) return null;

    // 创建合并后的图层
    final merged = Layer(name: '合并的图层');

    // 使用批量操作
    beginBatch();
    try {
      // 按顺序合并所有可见图层的笔画
      for (final layer in visibleLayers) {
        for (final stroke in layer.strokes) {
          merged.addStrokeInternal(stroke.copyWith());
        }
      }

      // 删除原有可见图层
      for (final layer in visibleLayers) {
        _layers.remove(layer);
        layer.dispose();
      }

      // 添加合并后的图层
      _layers.add(merged);
      _setActiveLayerIdInternal(merged.id);
      _pendingStructureChange = true;
      _pendingContentChange = true;
    } finally {
      endBatch();
    }

    return merged;
  }

  /// 展平所有图层
  /// 使用批量操作优化，只触发一次通知
  Layer? flattenAll() {
    if (_layers.isEmpty) return null;

    final flattened = Layer(name: '背景');

    // 使用批量操作
    beginBatch();
    try {
      for (final layer in _layers) {
        if (layer.visible) {
          for (final stroke in layer.strokes) {
            flattened.addStrokeInternal(stroke.copyWith());
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
      _setActiveLayerIdInternal(flattened.id);
      _pendingStructureChange = true;
      _pendingContentChange = true;
    } finally {
      endBatch();
    }

    return flattened;
  }

  /// 重排图层
  void reorderLayer(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _layers.length) return;
    if (newIndex < 0 || newIndex >= _layers.length) return;
    if (oldIndex == newIndex) return;

    final layer = _layers.removeAt(oldIndex);
    _layers.insert(newIndex, layer);
    invalidateSnapshot();
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
  /// 使用精确通知：仅通知旧/新活动图层的 isActiveNotifier
  /// 避免全局 activeLayerNotifier 导致所有图层 tile 重建
  void setActiveLayer(String layerId) {
    if (_activeLayerId == layerId) return; // 避免重复设置

    // 旧活动图层：通知变为非活动（O(1) rebuild）
    final oldLayer = getLayerById(_activeLayerId ?? '');
    oldLayer?.isActiveNotifier.value = false;

    // 新活动图层：通知变为活动（O(1) rebuild）
    final newLayer = getLayerById(layerId);
    if (newLayer != null) {
      newLayer.isActiveNotifier.value = true;
      _activeLayerId = layerId;
      // 保持兼容：更新全局通知器（其他需要监听活动图层的组件）
      activeLayerNotifier.value = layerId;
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
      invalidateSnapshot();
      notifyListeners();
    }
  }

  /// 切换图层锁定（不触发画布重绘）
  void toggleLock(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.locked = !layer.locked;
      _notifyUiOnly();
    }
  }

  /// 设置图层不透明度
  void setLayerOpacity(String layerId, double opacity) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.opacity = opacity.clamp(0.0, 1.0);
      layer.markNeedsUpdate();
      invalidateSnapshot();
      notifyListeners();
    }
  }

  /// 设置图层混合模式
  void setLayerBlendMode(String layerId, LayerBlendMode mode) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.blendMode = mode;
      invalidateSnapshot();
      notifyListeners();
    }
  }

  /// 重命名图层（不触发画布重绘）
  void renameLayer(String layerId, String newName) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      layer.name = newName;
      _notifyUiOnly();
    }
  }

  /// 向图层添加笔画
  void addStrokeToLayer(String layerId, StrokeData stroke) {
    final layer = getLayerById(layerId);
    if (layer != null && !layer.locked) {
      layer.addStroke(stroke);
      invalidateSnapshot();
      notifyListeners();
    }
  }

  /// 向当前图层添加笔画
  void addStrokeToActiveLayer(StrokeData stroke) {
    final layer = activeLayer;
    if (layer != null && !layer.locked) {
      layer.addStroke(stroke);
      invalidateSnapshot();
      notifyListeners();
    }
  }

  /// 移除图层最后一个笔画
  StrokeData? removeLastStrokeFromLayer(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null) {
      final stroke = layer.removeLastStroke();
      // 仅在实际删除笔画时通知（避免无效重绘）
      if (stroke != null) {
        invalidateSnapshot();
        notifyListeners();
      }
      return stroke;
    }
    return null;
  }

  /// 清除图层
  void clearLayer(String layerId) {
    final layer = getLayerById(layerId);
    if (layer != null && !layer.locked) {
      layer.clearStrokes();
      invalidateSnapshot();
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
    _setActiveLayerIdInternal(null);
    invalidateSnapshot();
    notifyListeners();
  }

  /// 变换所有图层内容以适应新画布尺寸
  ///
  /// [oldSize] 原画布尺寸
  /// [newSize] 新画布尺寸
  /// [mode] 变换模式
  void transformAllLayers(Size oldSize, Size newSize, CanvasResizeMode mode) {
    if (oldSize == newSize) return;

    // 使用批量操作优化，只触发一次通知
    beginBatch();
    try {
      for (final layer in _layers) {
        layer.transformContent(oldSize, newSize, mode);
      }
      _pendingContentChange = true;
    } finally {
      endBatch();
    }

    invalidateSnapshot();
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
  /// 面板下方的图层渲染在上层（覆盖面板上方的图层）
  /// 使用 renderWithCache 优先利用缓存提升性能
  void renderAll(Canvas canvas, Size canvasSize) {
    // 反向遍历：面板上方的图层先画（底层），面板下方的图层后画（顶层）
    for (final layer in _layers.reversed) {
      if (layer.visible) {
        layer.renderWithCache(canvas, canvasSize);
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

  // ===== 批量操作方法 =====

  /// 开始批量操作（合并图层、展平等）
  /// 在批量操作期间，不会触发中间通知
  void beginBatch() {
    _isBatchMode = true;
    _pendingStructureChange = false;
    _pendingContentChange = false;
  }

  /// 结束批量操作，发送单次通知
  void endBatch() {
    _isBatchMode = false;
    if (_pendingStructureChange || _pendingContentChange) {
      if (_pendingContentChange) {
        invalidateSnapshot();
      }
      notifyListeners();
    }
    _pendingStructureChange = false;
    _pendingContentChange = false;
  }

  /// 批量添加笔画（不触发中间通知）
  /// 用于图层合并等批量操作
  void addStrokesBatch(String layerId, List<StrokeData> strokes) {
    final layer = getLayerById(layerId);
    if (layer == null || layer.locked || strokes.isEmpty) return;

    // 直接添加到图层，不触发单独的通知
    for (final stroke in strokes) {
      layer.addStrokeInternal(stroke);
    }

    if (_isBatchMode) {
      _pendingContentChange = true;
    } else {
      invalidateSnapshot();
      notifyListeners();
    }
  }

  // ===== 快照缓存方法（代理到 CanvasSnapshotManager）=====

  /// 标记快照失效（在图层变化时调用）
  void invalidateSnapshot() => _snapshotManager.invalidate();

  /// 异步更新画布快照
  Future<bool> updateSnapshotAsync(Size canvasSize) =>
      _snapshotManager.updateSnapshotAsync(canvasSize);

  /// 同步读取指定位置的像素颜色
  Color? getPixelColor(int x, int y) => _snapshotManager.getPixelColor(x, y);

  /// 同步获取放大镜网格像素
  List<List<Color>>? getMagnifierPixels(
    int centerX,
    int centerY,
    int gridSize,
  ) =>
      _snapshotManager.getMagnifierPixels(centerX, centerY, gridSize);

  /// 更新区域快照（仅渲染光标周围的小区域）
  Future<bool> updateRegionalSnapshot(
    int centerX,
    int centerY,
    Size canvasSize,
  ) =>
      _snapshotManager.updateRegionalSnapshot(centerX, centerY, canvasSize);

  /// 获取区域缓存中的像素颜色（同步，O(1)）
  Color? getRegionalPixel(int x, int y) =>
      _snapshotManager.getRegionalPixel(x, y);

  /// 获取区域缓存中的放大镜像素网格（同步）
  List<List<Color>>? getRegionalMagnifierPixels(
    int centerX,
    int centerY,
    int gridSize,
  ) =>
      _snapshotManager.getRegionalMagnifierPixels(centerX, centerY, gridSize);

  @override
  void dispose() {
    _snapshotManager.dispose();
    activeLayerNotifier.dispose();
    uiUpdateNotifier.dispose();
    for (final layer in _layers) {
      layer.dispose();
    }
    super.dispose();
  }
}
