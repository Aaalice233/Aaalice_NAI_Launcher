import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/floating_panel_geometry.dart';

void main() {
  const bounds = Size(1200, 800);

  void expectInside(Rect rect, Size bounds) {
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(bounds.width + 1e-9));
    expect(rect.bottom, lessThanOrEqualTo(bounds.height + 1e-9));
  }

  test('默认位置贴右下角并留出边距', () {
    final rect = FloatingPanelGeometry.defaultRect(bounds);
    expect(rect.size, FloatingPanelGeometry.defaultSize);
    expect(rect.right, bounds.width - FloatingPanelGeometry.defaultMargin);
    expect(rect.bottom, bounds.height - FloatingPanelGeometry.defaultMargin);
  });

  test('工作区缩小时位置夹回、尺寸不超过工作区但不低于最小尺寸', () {
    const saved = Rect.fromLTWH(900, 500, 420, 600);
    const smaller = Size(900, 700);
    final clamped = FloatingPanelGeometry.clamp(saved, smaller);
    expectInside(clamped, smaller);
    expect(clamped.size, const Size(420, 600));

    const tiny = Size(300, 200);
    final squeezed = FloatingPanelGeometry.clamp(saved, tiny);
    expect(squeezed, const Rect.fromLTWH(0, 0, 300, 200));

    expect(
      FloatingPanelGeometry.clamp(saved, Size.zero),
      const Rect.fromLTWH(0, 0, 0, 0),
    );
  });

  test('移动被限制在工作区内', () {
    const rect = Rect.fromLTWH(100, 100, 420, 600);
    final moved = FloatingPanelGeometry.move(
      rect,
      const Offset(-500, 900),
      bounds,
    );
    expect(moved.topLeft, const Offset(0, 200));
    expect(moved.size, rect.size);
  });

  test('各边与各角调整大小遵守最小尺寸与工作区边界', () {
    const rect = Rect.fromLTWH(200, 100, 420, 600);
    const minimum = FloatingPanelGeometry.minimumSize;

    final shrunkRight = FloatingPanelGeometry.resize(
      rect,
      FloatingPanelEdge.right,
      const Offset(-1000, 0),
      bounds,
    );
    expect(shrunkRight.width, minimum.width);
    expect(shrunkRight.left, rect.left);

    final grownLeft = FloatingPanelGeometry.resize(
      rect,
      FloatingPanelEdge.left,
      const Offset(-1000, 0),
      bounds,
    );
    expect(grownLeft.left, 0);
    expect(grownLeft.right, rect.right);

    final grownBottomRight = FloatingPanelGeometry.resize(
      rect,
      FloatingPanelEdge.bottomRight,
      const Offset(5000, 5000),
      bounds,
    );
    expect(grownBottomRight.topLeft, rect.topLeft);
    expect(grownBottomRight.bottomRight, Offset(bounds.width, bounds.height));

    final shrunkTopLeft = FloatingPanelGeometry.resize(
      rect,
      FloatingPanelEdge.topLeft,
      const Offset(5000, 5000),
      bounds,
    );
    expect(shrunkTopLeft.size, minimum);
    expect(shrunkTopLeft.bottomRight, rect.bottomRight);

    for (final edge in FloatingPanelEdge.values) {
      final resized = FloatingPanelGeometry.resize(
        rect,
        edge,
        const Offset(-40, 30),
        bounds,
      );
      expectInside(resized, bounds);
      expect(resized.width, greaterThanOrEqualTo(minimum.width));
      expect(resized.height, greaterThanOrEqualTo(minimum.height));
    }
  });

  test('非有限或空尺寸的几何不可用', () {
    expect(
      FloatingPanelGeometry.isUsable(const Rect.fromLTWH(0, 0, 10, 10)),
      isTrue,
    );
    expect(
      FloatingPanelGeometry.isUsable(const Rect.fromLTWH(0, 0, 0, 10)),
      isFalse,
    );
    expect(
      FloatingPanelGeometry.isUsable(
        const Rect.fromLTWH(double.nan, 0, 10, 10),
      ),
      isFalse,
    );
  });
}
