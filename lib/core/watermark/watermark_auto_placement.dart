import 'dart:ui';

import '../../data/models/watermark/watermark_settings.dart';
import 'watermark_source_analysis.dart';

/// 整套水印的镜像方式；镜像是自身的逆，换算位移时正反都用同一个
enum WatermarkMirror {
  none(flipsX: false, flipsY: false),
  horizontal(flipsX: true, flipsY: false),
  vertical(flipsX: false, flipsY: true),
  both(flipsX: true, flipsY: true);

  const WatermarkMirror({required this.flipsX, required this.flipsY});

  final bool flipsX;
  final bool flipsY;

  WatermarkPlacement placement(WatermarkPlacement value) => value.copyWith(
    anchor: anchor(value.anchor),
    offsetXRatio: flipsX ? -value.offsetXRatio : value.offsetXRatio,
    offsetYRatio: flipsY ? -value.offsetYRatio : value.offsetYRatio,
  );

  WatermarkAnchor anchor(WatermarkAnchor value) {
    final column = switch (value) {
      WatermarkAnchor.topLeft ||
      WatermarkAnchor.centerLeft ||
      WatermarkAnchor.bottomLeft => _Edge.start,
      WatermarkAnchor.topCenter ||
      WatermarkAnchor.center ||
      WatermarkAnchor.bottomCenter => _Edge.middle,
      WatermarkAnchor.topRight ||
      WatermarkAnchor.centerRight ||
      WatermarkAnchor.bottomRight => _Edge.end,
    };
    final row = switch (value) {
      WatermarkAnchor.topLeft ||
      WatermarkAnchor.topCenter ||
      WatermarkAnchor.topRight => _Edge.start,
      WatermarkAnchor.centerLeft ||
      WatermarkAnchor.center ||
      WatermarkAnchor.centerRight => _Edge.middle,
      WatermarkAnchor.bottomLeft ||
      WatermarkAnchor.bottomCenter ||
      WatermarkAnchor.bottomRight => _Edge.end,
    };
    return _anchorAt(
      flipsY ? row.opposite : row,
      flipsX ? column.opposite : column,
    );
  }

  WatermarkTextAlignment alignment(WatermarkTextAlignment value) {
    if (!flipsX) return value;
    return switch (value) {
      WatermarkTextAlignment.left => WatermarkTextAlignment.right,
      WatermarkTextAlignment.center => WatermarkTextAlignment.center,
      WatermarkTextAlignment.right => WatermarkTextAlignment.left,
    };
  }

  Offset delta(Offset value) =>
      Offset(flipsX ? -value.dx : value.dx, flipsY ? -value.dy : value.dy);

  static WatermarkAnchor _anchorAt(_Edge row, _Edge column) =>
      switch ((row, column)) {
        (_Edge.start, _Edge.start) => WatermarkAnchor.topLeft,
        (_Edge.start, _Edge.middle) => WatermarkAnchor.topCenter,
        (_Edge.start, _Edge.end) => WatermarkAnchor.topRight,
        (_Edge.middle, _Edge.start) => WatermarkAnchor.centerLeft,
        (_Edge.middle, _Edge.middle) => WatermarkAnchor.center,
        (_Edge.middle, _Edge.end) => WatermarkAnchor.centerRight,
        (_Edge.end, _Edge.start) => WatermarkAnchor.bottomLeft,
        (_Edge.end, _Edge.middle) => WatermarkAnchor.bottomCenter,
        (_Edge.end, _Edge.end) => WatermarkAnchor.bottomRight,
      };
}

enum _Edge {
  start,
  middle,
  end;

  _Edge get opposite => switch (this) {
    _Edge.start => _Edge.end,
    _Edge.middle => _Edge.middle,
    _Edge.end => _Edge.start,
  };
}

abstract final class WatermarkAutoPlacement {
  /// 其他位置要比首选位置至少干净这么多才换过去，免得相近的画面在两角间来回跳
  static const double switchMargin = 0.15;

  /// [costs] 必须含 [WatermarkMirror.none]，即用户设定的首选位置
  static WatermarkMirror choose(Map<WatermarkMirror, double> costs) {
    final preferred = costs[WatermarkMirror.none]!;
    var best = WatermarkMirror.none;
    var bestCost = preferred;
    for (final mirror in WatermarkMirror.values) {
      final cost = costs[mirror];
      if (cost != null && cost < bestCost) {
        best = mirror;
        bestCost = cost;
      }
    }
    return bestCost < preferred * (1 - switchMargin)
        ? best
        : WatermarkMirror.none;
  }

  /// 水印压在这块区域上对画面的损害，越大越不该放这里；
  /// 取梯度均方根而非平均值，大片留白里的一只眼睛、一段线稿不会被平均掉
  static double placementCost(WatermarkRegionStats region) => region.rmsDetail;
}
