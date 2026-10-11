import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// 透明区域的棋盘格底纹。
///
/// 用一张两格见方的纹理平铺整块区域，绘制开销与面积和格子数无关。
@immutable
class CheckerboardPattern {
  const CheckerboardPattern({
    required this.cellSize,
    required this.evenColor,
    required this.oddColor,
  });

  final double cellSize;

  /// 行号与列号之和为偶数的格子，包括左上角第一格
  final Color evenColor;

  final Color oddColor;

  // 纹理精度上限：再往上放大只会让格子边缘略软，换不来可见的清晰度
  static const int _maxTileExtent = 512;
  static const int _maxCachedTiles = 8;

  static final LinkedHashMap<_TileKey, ui.Image> _tiles = LinkedHashMap();
  static int _tileBuildCount = 0;

  /// 用棋盘格填满 [rect]，第一格的左上角对齐 [origin]。
  ///
  /// [pixelScale] 是当前坐标系到设备像素的缩放，决定纹理精度。
  void paint(
    Canvas canvas,
    Rect rect, {
    Offset origin = Offset.zero,
    double pixelScale = 1,
  }) {
    if (rect.isEmpty || cellSize <= 0) return;

    final tile = _tileFor(_tileExtentFor(pixelScale));
    // 纹理边长取整后仍按两格的逻辑尺寸映射，格子周期不随精度漂移
    final scale = 2 * cellSize / tile.width;
    final matrix = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[12] = origin.dx
      ..[13] = origin.dy
      ..[15] = 1;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.ImageShader(
          tile,
          TileMode.repeated,
          TileMode.repeated,
          matrix,
          filterQuality: FilterQuality.medium,
        ),
    );
  }

  /// 两格纹理的边长（像素）：精度按 2 的幂分档，缩放连续变化时只在跨档时新建纹理
  int _tileExtentFor(double pixelScale) {
    var texelsPerUnit = 1.0;
    while (texelsPerUnit < pixelScale &&
        2 * cellSize * texelsPerUnit * 2 <= _maxTileExtent) {
      texelsPerUnit *= 2;
    }
    return (2 * cellSize * texelsPerUnit).round().clamp(2, _maxTileExtent);
  }

  ui.Image _tileFor(int extent) {
    final key = _TileKey(this, extent);
    final cached = _tiles.remove(key);
    if (cached != null) {
      _tiles[key] = cached;
      return cached;
    }

    final tile = _buildTile(extent);
    _tileBuildCount++;
    _tiles[key] = tile;
    while (_tiles.length > _maxCachedTiles) {
      // 已录入画面的着色器各自持有纹理引用，这里释放不影响仍在显示的帧
      _tiles.remove(_tiles.keys.first)!.dispose();
    }
    return tile;
  }

  ui.Image _buildTile(int extent) {
    final half = extent / 2;
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        Rect.fromLTWH(0, 0, extent.toDouble(), extent.toDouble()),
        Paint()..color = oddColor,
      )
      ..drawRect(Rect.fromLTWH(0, 0, half, half), Paint()..color = evenColor)
      ..drawRect(
        Rect.fromLTWH(half, half, half, half),
        Paint()..color = evenColor,
      );
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(extent, extent);
    } finally {
      picture.dispose();
    }
  }

  @visibleForTesting
  static int get debugTileBuildCount => _tileBuildCount;

  @visibleForTesting
  static int get debugCachedTileCount => _tiles.length;

  @visibleForTesting
  static void debugReset() {
    for (final tile in _tiles.values) {
      tile.dispose();
    }
    _tiles.clear();
    _tileBuildCount = 0;
  }

  @override
  bool operator ==(Object other) =>
      other is CheckerboardPattern &&
      other.cellSize == cellSize &&
      other.evenColor == evenColor &&
      other.oddColor == oddColor;

  @override
  int get hashCode => Object.hash(cellSize, evenColor, oddColor);
}

@immutable
class _TileKey {
  const _TileKey(this.pattern, this.extent);

  final CheckerboardPattern pattern;
  final int extent;

  @override
  bool operator ==(Object other) =>
      other is _TileKey && other.pattern == pattern && other.extent == extent;

  @override
  int get hashCode => Object.hash(pattern, extent);
}
