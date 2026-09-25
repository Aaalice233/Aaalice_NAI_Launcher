import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fillCalls = {#drawRect, #drawRRect, #drawPath, #drawPaint};
const _imageCalls = {#drawImage, #drawImageRect, #drawImageNine};
const _inkCalls = {#drawRect, #drawRRect, #drawPath, #drawCircle};

// 墨水透明度经 8 位量化，按 ARGB32 比较
bool _sameColor(Color a, Color b) => a.toARGB32() == b.toARGB32();

bool isInkCall(Symbol method, List<dynamic> arguments, Color ink) =>
    _inkCalls.contains(method) &&
    _sameColor((arguments.last as Paint).color, ink);

void expectInkOnTop(
  WidgetTester tester,
  Finder target, {
  required Color ink,
  Color? below,
  bool belowGradient = false,
  String? reason,
}) {
  expect(
    tester.renderObject(target),
    inkOnTop(ink: ink, below: below, belowGradient: belowGradient),
    reason: reason,
  );
}

// 绘制顺序即叠放层级：[below] 或渐变底色先画，墨水随后，之后不能有盖住墨水的不透明填充或图片。
// 断言带状态，每次 expect 都要新建
PaintPattern inkOnTop({
  required Color ink,
  Color? below,
  bool belowGradient = false,
}) {
  assert(below == null || !belowGradient);
  final canvas = _CanvasTracker();
  Rect? inkBounds;
  final pattern = paints;
  if (below != null || belowGradient) {
    pattern.something((method, arguments) {
      canvas.observe(method, arguments);
      if (!_fillCalls.contains(method)) return false;
      final paint = arguments.last as Paint;
      return belowGradient
          ? paint.shader != null
          : _sameColor(paint.color, below!);
    });
  }
  return pattern
    ..something((method, arguments) {
      canvas.observe(method, arguments);
      if (!isInkCall(method, arguments, ink)) return false;
      inkBounds = canvas.globalBounds(method, arguments);
      return true;
    })
    ..everything((method, arguments) {
      canvas.observe(method, arguments);
      return !canvas.coversOpaquely(method, arguments, inkBounds!);
    });
}

// 绘制调用里的坐标是局部的，要叠上 translate/transform 才能判断谁盖住了谁
class _CanvasTracker {
  final _stack = <Matrix4>[Matrix4.identity()];

  void observe(Symbol method, List<dynamic> arguments) {
    switch (method) {
      case #save || #saveLayer:
        _stack.add(_stack.last.clone());
      case #restore:
        _stack.removeLast();
      case #restoreToCount:
        _stack.length = arguments[0] as int;
      case #translate:
        _stack.last.translateByDouble(
          arguments[0] as double,
          arguments[1] as double,
          0,
          1,
        );
      case #scale:
        final sx = arguments[0] as double;
        final sy = arguments.length > 1 ? arguments[1] as double? : null;
        _stack.last.scaleByDouble(sx, sy ?? sx, 1, 1);
      case #rotate:
        _stack.last.rotateZ(arguments[0] as double);
      case #transform:
        _stack.last.multiply(
          Matrix4.fromFloat64List(arguments[0] as Float64List),
        );
    }
  }

  Rect? globalBounds(Symbol method, List<dynamic> arguments) {
    final local = switch (method) {
      #drawRect => arguments[0] as Rect,
      #drawRRect => (arguments[0] as RRect).outerRect,
      #drawPath => (arguments[0] as Path).getBounds(),
      #drawCircle => Rect.fromCircle(
        center: arguments[0] as Offset,
        radius: arguments[1] as double,
      ),
      #drawPaint => Rect.largest,
      #drawImage => (arguments[1] as Offset) & _imageSize(arguments[0]),
      #drawImageRect || #drawImageNine => arguments[2] as Rect,
      _ => null,
    };
    return local == null ? null : MatrixUtils.transformRect(_stack.last, local);
  }

  bool coversOpaquely(Symbol method, List<dynamic> arguments, Rect ink) {
    final isFill = _fillCalls.contains(method);
    if (!isFill && !_imageCalls.contains(method)) return false;
    final paint = arguments.last as Paint;
    final opaque = isFill
        ? paint.style != PaintingStyle.stroke &&
              paint.shader == null &&
              paint.color.a >= 1
        : paint.color.a >= 1;
    if (!opaque) return false;
    final overlap = globalBounds(method, arguments)!.intersect(ink);
    return overlap.width > 0 &&
        overlap.height > 0 &&
        overlap.width * overlap.height >= ink.width * ink.height * 0.9;
  }

  Size _imageSize(Object image) {
    final ui.Image decoded = image as ui.Image;
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }
}

// 墨水高亮淡入 200ms；固定帧推进，页面有常驻动画时也不会等不到稳定
Future<void> _settleInk(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

// 返回的鼠标可继续 moveTo 到下一个目标，测试结束时自动移除
Future<TestGesture> hoverOver(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await _settleInk(tester);
  return mouse;
}

Future<void> moveMouseTo(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  await mouse.moveTo(tester.getCenter(target));
  await _settleInk(tester);
}

// 点击手势在按压超时后才落下，此时高亮已出现；返回的手势由调用方抬起
Future<TestGesture> pressAndHold(WidgetTester tester, Finder target) async {
  final press = await tester.startGesture(tester.getCenter(target));
  await tester.pump(kPressTimeout);
  await tester.pump(const Duration(milliseconds: 200));
  return press;
}

Future<void> tabUntilFocused(
  WidgetTester tester,
  Finder inkWell, {
  int maxPresses = 60,
}) async {
  final detector = find
      .descendant(of: inkWell, matching: find.byType(GestureDetector))
      .first;
  for (var i = 0; i < maxPresses; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (Focus.of(tester.element(detector)).hasPrimaryFocus) {
      await _settleInk(tester);
      return;
    }
  }
  fail('按 $maxPresses 次 Tab 仍未聚焦到 $inkWell');
}
