import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 构图参考线档位
enum CompositionGuideMode {
  none,
  thirds,
  phi,
  grid;

  static CompositionGuideMode fromStorageValue(String? value) {
    return CompositionGuideMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => CompositionGuideMode.none,
    );
  }

  String get storageValue => name;
}

/// 归一化的参考线位置（0-1）：竖线取 x、横线取 y
typedef CompositionGuideLines = ({
  List<double> verticals,
  List<double> horizontals,
});

/// 构图参考线的几何定义
abstract final class CompositionGuide {
  static const int minDivisions = 2;
  static const int maxDivisions = 12;
  static const int defaultDivisions = 3;

  static final double _phi = (1 + math.sqrt(5)) / 2;

  static int clampDivisions(int value) =>
      value.clamp(minDivisions, maxDivisions);

  /// 各档位的参考线位置
  static CompositionGuideLines linesOf(
    CompositionGuideMode mode, {
    int columns = defaultDivisions,
    int rows = defaultDivisions,
  }) {
    switch (mode) {
      case CompositionGuideMode.none:
        return (verticals: const [], horizontals: const []);
      case CompositionGuideMode.thirds:
        return (
          verticals: const [1 / 3, 2 / 3],
          horizontals: const [1 / 3, 2 / 3],
        );
      case CompositionGuideMode.phi:
        final lines = [1 - 1 / _phi, 1 / _phi];
        return (verticals: lines, horizontals: List.of(lines));
      case CompositionGuideMode.grid:
        return (
          verticals: _evenSplits(clampDivisions(columns)),
          horizontals: _evenSplits(clampDivisions(rows)),
        );
    }
  }

  /// N 等分产生的 N-1 条内线
  static List<double> _evenSplits(int divisions) => [
    for (var i = 1; i < divisions; i++) i / divisions,
  ];
}

/// 构图参考线层：铺满父容器按归一化位置画线
class CompositionGuideOverlay extends StatelessWidget {
  final CompositionGuideMode mode;
  final int columns;
  final int rows;

  const CompositionGuideOverlay({
    super.key,
    required this.mode,
    this.columns = CompositionGuide.defaultDivisions,
    this.rows = CompositionGuide.defaultDivisions,
  });

  @override
  Widget build(BuildContext context) {
    if (mode == CompositionGuideMode.none) return const SizedBox.shrink();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: CompositionGuidePainter(
          mode: mode,
          columns: columns,
          rows: rows,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    );
  }
}

/// 深色描边打底 + 浅色细线，保证在任意亮度的底图上都看得清
class CompositionGuidePainter extends CustomPainter {
  final CompositionGuideMode mode;
  final int columns;
  final int rows;
  final double devicePixelRatio;

  const CompositionGuidePainter({
    required this.mode,
    required this.columns,
    required this.rows,
    required this.devicePixelRatio,
  });

  static final Paint halo = Paint()
    ..color = const Color(0x59000000)
    ..strokeWidth = 2;

  static final Paint stroke = Paint()
    ..color = const Color(0xBFFFFFFF)
    ..strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = CompositionGuide.linesOf(mode, columns: columns, rows: rows);
    final verticals = [for (final x in lines.verticals) _crisp(x * size.width)];
    final horizontals = [
      for (final y in lines.horizontals) _crisp(y * size.height),
    ];

    // 描边必须整层画完再画细线：逐条交替时后一条的描边会咬掉前一条的交叉点
    _paintPass(canvas, size, verticals, horizontals, halo);
    _paintPass(canvas, size, verticals, horizontals, stroke);
  }

  void _paintPass(
    Canvas canvas,
    Size size,
    List<double> verticals,
    List<double> horizontals,
    Paint paint,
  ) {
    for (final x in verticals) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (final y in horizontals) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// 线心对齐到设备像素中心，1px 线才不会跨两个像素发虚
  double _crisp(double offset) =>
      ((offset * devicePixelRatio).floorToDouble() + 0.5) / devicePixelRatio;

  @override
  bool shouldRepaint(covariant CompositionGuidePainter oldDelegate) {
    return mode != oldDelegate.mode ||
        columns != oldDelegate.columns ||
        rows != oldDelegate.rows ||
        devicePixelRatio != oldDelegate.devicePixelRatio;
  }
}
