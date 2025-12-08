import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 区域快照缓存（用于拾色器实时采样）
/// 仅缓存光标周围的小区域，支持快速移动时的同步查询
class RegionalSnapshotCache {
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
  bool isUpdating = false;

  /// 缓存区域大小（65×65 覆盖 33×33 采样区 + 边缘缓冲）
  static const int regionSize = 65;

  /// 检查坐标是否在缓存范围内
  bool contains(int x, int y) {
    if (_pixelData == null) return false;
    return x >= _left && x < _left + _width && y >= _top && y < _top + _height;
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
  List<List<Color>>? getMagnifierPixels(
    int centerX,
    int centerY,
    int gridSize,
  ) {
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

/// 画布快照管理器
/// 负责管理画布快照缓存，用于拾色器等需要同步采样的功能
class CanvasSnapshotManager {
  /// 渲染回调（由 LayerManager 提供）
  final void Function(Canvas canvas, Size canvasSize) renderCallback;

  /// 缓存的合成图像
  ui.Image? _canvasSnapshot;

  /// 缓存的像素数据（RGBA 格式）
  ByteData? _canvasSnapshotBytes;

  /// 快照尺寸
  int _snapshotWidth = 0;
  int _snapshotHeight = 0;

  /// 快照版本号（每次失效时递增）
  int _snapshotVersion = 0;

  /// 快照更新防抖定时器
  Timer? _snapshotDebounceTimer;

  /// 区域快照缓存实例
  final RegionalSnapshotCache _regionalCache = RegionalSnapshotCache();

  CanvasSnapshotManager({required this.renderCallback});

  /// 获取快照版本号
  int get snapshotVersion => _snapshotVersion;

  /// 快照是否有效
  bool get hasValidSnapshot => _canvasSnapshotBytes != null;

  /// 标记快照失效（在图层变化时调用）
  /// 使用防抖机制避免频繁失效
  void invalidate() {
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
    renderCallback(canvas, canvasSize);

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

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);

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
  List<List<Color>>? getMagnifierPixels(
    int centerX,
    int centerY,
    int gridSize,
  ) {
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

  /// 更新区域快照（仅渲染光标周围的小区域）
  /// 返回是否成功更新
  Future<bool> updateRegionalSnapshot(
    int centerX,
    int centerY,
    Size canvasSize,
  ) async {
    // 防止并发更新
    if (_regionalCache.isUpdating) return false;
    _regionalCache.isUpdating = true;

    final targetVersion = _snapshotVersion;
    const regionSize = RegionalSnapshotCache.regionSize;
    const halfRegion = regionSize ~/ 2;

    // 计算区域边界（裁剪到画布范围）
    final left = (centerX - halfRegion).clamp(0, canvasSize.width.toInt() - 1);
    final top = (centerY - halfRegion).clamp(0, canvasSize.height.toInt() - 1);
    final right = (centerX + halfRegion + 1).clamp(0, canvasSize.width.toInt());
    final bottom =
        (centerY + halfRegion + 1).clamp(0, canvasSize.height.toInt());
    final width = right - left;
    final height = bottom - top;

    if (width <= 0 || height <= 0) {
      _regionalCache.isUpdating = false;
      return false;
    }

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 平移画布，使区域左上角位于原点
      canvas.translate(-left.toDouble(), -top.toDouble());

      // 裁剪到采样区域
      canvas.clipRect(
        Rect.fromLTWH(
          left.toDouble(),
          top.toDouble(),
          width.toDouble(),
          height.toDouble(),
        ),
      );

      // 绘制白色背景
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        Paint()..color = Colors.white,
      );

      // 渲染所有可见图层
      renderCallback(canvas, canvasSize);

      final picture = recorder.endRecording();

      // 检查版本号
      if (_snapshotVersion != targetVersion) {
        picture.dispose();
        _regionalCache.isUpdating = false;
        return false;
      }

      final image = await picture.toImage(width, height);

      // 再次检查版本号
      if (_snapshotVersion != targetVersion) {
        image.dispose();
        picture.dispose();
        _regionalCache.isUpdating = false;
        return false;
      }

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();

      if (byteData == null || _snapshotVersion != targetVersion) {
        _regionalCache.isUpdating = false;
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

      _regionalCache.isUpdating = false;
      return true;
    } catch (e) {
      _regionalCache.isUpdating = false;
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
  List<List<Color>>? getRegionalMagnifierPixels(
    int centerX,
    int centerY,
    int gridSize,
  ) {
    if (_regionalCache.isStale(_snapshotVersion)) return null;
    return _regionalCache.getMagnifierPixels(centerX, centerY, gridSize);
  }

  /// 释放资源
  void dispose() {
    _snapshotDebounceTimer?.cancel();
    _canvasSnapshot?.dispose();
    _canvasSnapshot = null;
    _canvasSnapshotBytes = null;
    _regionalCache.clear();
  }
}
