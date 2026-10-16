import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 扣除安全区与软键盘后仍可见的屏幕范围
Rect visibleViewRect(WidgetTester tester) {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final ratio = view.devicePixelRatio;
  return Rect.fromLTRB(
    view.padding.left / ratio,
    view.padding.top / ratio,
    size.width - view.padding.right / ratio,
    size.height - math.max(view.viewInsets.bottom, view.padding.bottom) / ratio,
  );
}

// .first 之类的链式 finder 在没有候选时直接抛错而不是返回空
bool _isBuilt(Finder target) {
  try {
    return target.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

/// 文字为 [label] 的 Material 按钮，离屏的也算
Finder buttonLabeled(String label) => find.ancestor(
  of: find.text(label, skipOffstage: false),
  matching: find.byWidgetPredicate(
    (widget) => widget is ButtonStyleButton,
    skipOffstage: false,
  ),
);

/// 按需构建的列表项先按视口半高逐步跳转，直到目标进入构建范围；
/// [scrollView] 可以是 Scrollable 本身或包含它的滚动视图
Future<void> scrollUntilBuilt(
  WidgetTester tester,
  Finder target,
  Finder scrollView,
) async {
  if (_isBuilt(target)) return;
  final position = tester
      .state<ScrollableState>(
        find
            .descendant(
              of: scrollView,
              matching: find.byType(Scrollable, skipOffstage: false),
              matchRoot: true,
              skipOffstage: false,
            )
            .first,
      )
      .position;
  position.jumpTo(position.minScrollExtent);
  await tester.pump();
  while (!_isBuilt(target) && position.pixels < position.maxScrollExtent) {
    position.jumpTo(
      math.min(
        position.pixels + position.viewportDimension / 2,
        position.maxScrollExtent,
      ),
    );
    await tester.pump();
  }
  expect(target, findsWidgets);
}

/// 与获得焦点时一样经 showOnScreen 滚到目标；固定头部内的目标不会像
/// ensureVisible 那样被滚到列表末尾
Future<void> revealOnScreen(WidgetTester tester, Finder target) async {
  tester.renderObject(target).showOnScreen();
  await tester.pumpAndSettle();
}

/// 屏幕可见范围再按目标所在的各层滚动视口裁剪，并扣除固定在视口顶端、
/// 排在目标之前的头部
Rect _visibleBounds(WidgetTester tester, RenderObject targetBox) {
  var visible = visibleViewRect(tester);
  RenderObject child = targetBox;
  for (
    RenderObject? node = targetBox.parent;
    node != null;
    child = node, node = node.parent
  ) {
    if (node is! RenderAbstractViewport) continue;
    final box = node as RenderBox;
    final viewport = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final obstruction =
        node is RenderViewportBase && node.axisDirection == AxisDirection.down
        ? _leadingObstruction(node, child as RenderSliver)
        : 0.0;
    visible = visible.intersect(
      Rect.fromLTRB(
        viewport.left,
        viewport.top + obstruction,
        viewport.right,
        viewport.bottom,
      ),
    );
  }
  return visible;
}

/// 点在目标实际露出部分的中心，比所在视口还宽或还高的目标也能点中
Future<void> tapVisiblePart(WidgetTester tester, Finder target) async {
  final shown = tester
      .getRect(target)
      .intersect(_visibleBounds(tester, tester.renderObject(target)));
  await tester.tapAt(shown.center);
  await tester.pumpAndSettle();
}

/// 断言目标完整进入可见范围（比可见范围还大时至少露出 [minExtent]）、
/// 尺寸不小于 [minExtent]，且可见部分的中心能点中目标
void expectReachable(
  WidgetTester tester,
  Finder target, {
  required String reason,
  double minExtent = 48,
}) {
  final targetBox = tester.renderObject(target);
  final rect = tester.getRect(target);
  final visible = _visibleBounds(tester, targetBox);
  final shown = rect.intersect(visible);
  bool fits(double extent, double shownExtent, double visibleExtent) =>
      extent <= visibleExtent + 0.5
      ? (shownExtent - extent).abs() < 0.5
      : shownExtent >= minExtent;
  expect(
    !shown.isEmpty &&
        fits(rect.width, shown.width, visible.width) &&
        fits(rect.height, shown.height, visible.height),
    isTrue,
    reason: '$reason: $rect 未完整进入可见区域 $visible',
  );
  expect(rect.width, greaterThanOrEqualTo(minExtent), reason: reason);
  expect(rect.height, greaterThanOrEqualTo(minExtent), reason: reason);
  expect(
    tester
        .hitTestOnBinding(shown.center)
        .path
        .any((entry) => entry.target == targetBox),
    isTrue,
    reason: '$reason: 可见部分中心被遮挡或不可点中',
  );
}

double _leadingObstruction(RenderViewportBase viewport, RenderSliver path) {
  var extent = 0.0;
  for (
    RenderSliver? sliver = viewport.firstChild;
    sliver != null && sliver != path;
    sliver = viewport.childAfter(sliver)
  ) {
    extent += sliver.geometry?.maxScrollObstructionExtent ?? 0;
  }
  return extent;
}
