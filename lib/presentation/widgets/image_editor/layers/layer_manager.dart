import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/history_manager.dart';
import 'layer.dart';

/// 区域快照缓存（用于拾色器实时采样）
/// 仅缓存光标周围的小区域，支持快速移动时的同步查询
class _RegionalSnapshotCache {
  /// 像素数据（RGBA 格式）
  Uint8List? _pixelData;

  /// 缓存区域的左上角 X 坐标
  int _left = 0;

  /// 缓存区域的左上角 Y 坐标
  int _top = 0;

  /// 缓存区域宽度
  int _width = 0;

  /// 缓存区域高度
  int _height = 0;

  /// 缓存版本号（用于检测失效）
  int _version = -1;

  /// 是否正在更新（防止并发）
  bool _isUpdating = false;

  /// 缓存区域大小（65×65 覆盖 33×33 采样区 + 边缘缓冲）
  static const int regionSize = 65;

  /// 检查坐标是否在缓存范围内
  bool contains(int x, int y) {
    if (_pixelData == null) return false;
    return x >= _left && x < _left + _width &&
           y >= _top && y < _top + _height;
  }

  /// 检查是否可以提供完整的放大镜网格
  bool canProvideMagnifierGrid(int centerX, int centerY, int gridSize) {
    if (_pixelData == null) return false;
    final halfGrid = gridSize ~/ 2;
    return centerX - halfGrid >= _left &&
           centerX + halfGrid < _left + _width &&
           centerY - halfGrid >= _top &&
           centerY + halfGrid < _top + _height;
  }

  /// 获取像素颜色（同步，O(1)）
  Color? getPixel(int x, int y) {
    if (_pixelData == null || !contains(x, y)) return null;
    final localX = x - _left;
    final localY = y - _top;
    final offset = (localY * _width + localX) * 4;
    if (offset < 0 || offset + 3 >= _pixelData!.length) return null;
    return Color.fromARGB(
      _pixelData![offset + 3],
      _pixelData![offset],
      _pixelData![offset + 1],
      _pixelData![offset + 2],
    );
  }

  /// 获取放大镜网格像素（同步）
  List<List<Color>>? getMagnifierPixels(int centerX, int centerY, int gridSize) {
    if (!canProvideMagnifierGrid(centerX, centerY, gridSize)) return null;

    final halfGrid = gridSize ~/ 2;
    return List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) {
        final x = centerX + col - halfGrid;
        final y = centerY + row - halfGrid;
        return getPixel(x, y) ?? Colors.transparent;
      });
    });
  }

  /// 更新缓存区域
  void update({
    required Uint8List pixelData,
    required int left,
    required int top,
    required int width,
    required int height,
    required int version,
  }) {
    _pixelData = pixelData;
    _left = left;
    _top = top;
    _width = width;
    _height = height;
    _version = version;
  }

  /// 检查缓存是否过期
  bool isStale(int currentVersion) => _version != currentVersion;

  /// 清理缓存
  void clear() {
    _pixelData = null;
    _left = 0;
    _top = 0;
    _width = 0;
    _height = 0;
    _version = -1;
  }
}

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

  // ===== 快照防抖 =====

  /// 快照更新防抖定时器
  Timer? _snapshotDebounceTimer;

  // ===== 画布快照缓存（用于拾色器同步采样）=====

  /// 缓存的合成图像
  ui.Image? _canvasSnapshot;

  /// 缓存的像素数据（RGBA 格式）
  ByteData? _canvasSnapshotBytes;

  /// 快照尺寸
  int _snapshotWidth = 0;
  int _snapshotHeight = 0;

  /// 快照版本号（每次失效时递增）
  int _snapshotVersion = 0;

  /// 获取快照版本号
  int get snapshotVersion => _snapshotVersion;

  /// 快照是否有效
  bool get hasValidSnapshot => _canvasSnapshotBytes != null;

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
  Layer insertLayerFromData(LayerData data, int index, {bool setActive = false}) {
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
        _setActiveLayerIdInternal(_layers[index.clamp(0, _layers.length - 1)].id);
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

  // ===== 快照缓存方法 =====

  /// 标记快照失效（在图层变化时调用）
  /// 使用防抖机制避免频繁失效
  void invalidateSnapshot() {
    _snapshotVersion++;

    // 取消之前的防抖定时器
    _snapshotDebounceTimer?.cancel();

    // 防抖：100ms 内的多次失效合并
    _snapshotDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      // 可选：触发异步快照更新
      // 这里只是标记失效，实际更新由拾色器按需触发
    });
  }

  /// 异步更新画布快照
  /// 返回是否成功更新
  Future<bool> updateSnapshotAsync(Size canvasSize) async {
    final targetVersion = _snapshotVersion;

    // 渲染所有图层到临时画布
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制白色背景
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = Colors.white,
    );

    // 渲染所有可见图层
    renderAll(canvas, canvasSize);

    final picture = recorder.endRecording();

    try {
      final image = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );

      // 检查版本号，如果已过期则放弃
      if (_snapshotVersion != targetVersion) {
        image.dispose();
        picture.dispose();
        return false;
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

      // 再次检查版本号
      if (_snapshotVersion != targetVersion) {
        image.dispose();
        picture.dispose();
        return false;
      }

      // 更新缓存
      _canvasSnapshot?.dispose();
      _canvasSnapshot = image;
      _canvasSnapshotBytes = byteData;
      _snapshotWidth = canvasSize.width.toInt();
      _snapshotHeight = canvasSize.height.toInt();

      picture.dispose();
      return true;
    } catch (e) {
      picture.dispose();
      return false;
    }
  }

  /// 同步读取指定位置的像素颜色
  /// 如果缓存不可用，返回 null
  Color? getPixelColor(int x, int y) {
    if (_canvasSnapshotBytes == null ||
        x < 0 ||
        y < 0 ||
        x >= _snapshotWidth ||
        y >= _snapshotHeight) {
      return null;
    }

    final offset = (y * _snapshotWidth + x) * 4;
    if (offset + 3 >= _canvasSnapshotBytes!.lengthInBytes) {
      return null;
    }

    final r = _canvasSnapshotBytes!.getUint8(offset);
    final g = _canvasSnapshotBytes!.getUint8(offset + 1);
    final b = _canvasSnapshotBytes!.getUint8(offset + 2);
    final a = _canvasSnapshotBytes!.getUint8(offset + 3);

    return Color.fromARGB(a, r, g, b);
  }

  /// 同步获取放大镜网格像素
  /// 如果缓存不可用，返回 null
  List<List<Color>>? getMagnifierPixels(int centerX, int centerY, int gridSize) {
    if (_canvasSnapshotBytes == null) return null;

    final halfGrid = gridSize ~/ 2;

    return List.generate(gridSize, (row) {
      return List.generate(gridSize, (col) {
        final x = centerX + col - halfGrid;
        final y = centerY + row - halfGrid;
        return getPixelColor(x, y) ?? Colors.transparent;
      });
    });
  }

  /// 清理快照缓存
  void _disposeSnapshot() {
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;
    _canvasSnapshotBytes = null;
  }

  // ===== 区域快照缓存（用于拾色器实时采样）=====

  /// 区域快照缓存实例
  final _RegionalSnapshotCache _regionalCache = _RegionalSnapshotCache();

  /// 更新区域快照（仅渲染光标周围的小区域）
  /// 返回是否成功更新
  Future<bool> updateRegionalSnapshot(int centerX, int centerY, Size canvasSize) async {
    // 防止并发更新
    if (_regionalCache._isUpdating) return false;
    _regionalCache._isUpdating = true;

    final targetVersion = _snapshotVersion;
    const regionSize = _RegionalSnapshotCache.regionSize;
    const halfRegion = regionSize ~/ 2;

    // 计算区域边界（裁剪到画布范围）
    final left = (centerX - halfRegion).clamp(0, canvasSize.width.toInt() - 1);
    final top = (centerY - halfRegion).clamp(0, canvasSize.height.toInt() - 1);
    final right = (centerX + halfRegion + 1).clamp(0, canvasSize.width.toInt());
    final bottom = (centerY + halfRegion + 1).clamp(0, canvasSize.height.toInt());
    final width = right - left;
    final height = bottom - top;

    if (width <= 0 || height <= 0) {
      _regionalCache._isUpdating = false;
      return false;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 平移画布，使区域左上角位于原点
      canvas.translate(-left.toDouble(), -top.toDouble());

      // 裁剪到采样区域
      canvas.clipRect(Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),);

      // 绘制白色背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.white,
      );

      // 渲染所有可见图层
      renderAll(canvas, canvasSize);

      final picture = recorder.endRecording();

      // 检查版本号
      if (_snapshotVersion != targetVersion) {
        picture.dispose();
        _regionalCache._isUpdating = false;
        return false;
      }

      final image = await picture.toImage(width, height);

      // 再次检查版本号
      if (_snapshotVersion != targetVersion) {
        image.dispose();
        picture.dispose();
        _regionalCache._isUpdating = false;
        return false;
      }

      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();

      if (byteData == null || _snapshotVersion != targetVersion) {
        _regionalCache._isUpdating = false;
        return false;
      }

      // 更新区域缓存
      _regionalCache.update(
        pixelData: byteData.buffer.asUint8List(),
        left: left,
        top: top,
        width: width,
        height: height,
        version: targetVersion,
      );

      _regionalCache._isUpdating = false;
      return true;
    } catch (e) {
      _regionalCache._isUpdating = false;
      return false;
    }
  }

  /// 获取区域缓存中的像素颜色（同步，O(1)）
  Color? getRegionalPixel(int x, int y) {
    if (_regionalCache.isStale(_snapshotVersion)) return null;
    return _regionalCache.getPixel(x, y);
  }

  /// 获取区域缓存中的放大镜像素网格（同步）
  /// 如果区域缓存不包含所需像素，返回 null
  List<List<Color>>? getRegionalMagnifierPixels(int centerX, int centerY, int gridSize) {
    if (_regionalCache.isStale(_snapshotVersion)) return null;
    return _regionalCache.getMagnifierPixels(centerX, centerY, gridSize);
  }

  /// 清理区域缓存
  void _disposeRegionalCache() {
    _regionalCache.clear();
  }

  @override
  void dispose() {
    // 取消防抖定时器
    _snapshotDebounceTimer?.cancel();

    _disposeSnapshot();
    _disposeRegionalCache();
    activeLayerNotifier.dispose();
    uiUpdateNotifier.dispose();
    for (final layer in _layers) {
      layer.dispose();
    }
    super.dispose();
  }
}
