/// 逐像素比较工具。
///
/// inpaint 的 display 走替换语义、patch 走 over 语义，只有生成结果不透明时
/// 两者才代数等价，此时剩下的差异纯粹来自各阶段独立取整。
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// patch alpha 与 display 各取整一次，不经缩放时残差不超过 1。
const int inpaintQuantizationTolerance = 1;

/// 聚焦路径的 patch 与 display 走不同的 Lanczos 缩放中间量，
/// 在量化残差之上再叠一级重采样偏差。
const int focusedInpaintResampleTolerance = 2;

/// 断言两张图逐像素相差不超过 [tolerance]。
///
/// 报告最大偏差而不是第一个不等的像素：量化残差是个位数，合成语义不同会直接
/// 跑到上百，只看首个失配像素分不出这两种情况。
void expectPixelsWithin(
  img.Image actual,
  img.Image expected, {
  int tolerance = 0,
}) {
  expect((actual.width, actual.height), (expected.width, expected.height));

  var worstDelta = 0;
  var worstX = 0;
  var worstY = 0;
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      final delta = _channelDelta(
        actual.getPixel(x, y),
        expected.getPixel(x, y),
      );
      if (delta > worstDelta) {
        worstDelta = delta;
        worstX = x;
        worstY = y;
      }
    }
  }

  expect(
    worstDelta,
    lessThanOrEqualTo(tolerance),
    reason:
        'Worst pixel deviation at $worstX,$worstY: '
        '${_describe(actual.getPixel(worstX, worstY))} vs '
        '${_describe(expected.getPixel(worstX, worstY))}',
  );
}

int _channelDelta(img.Pixel actual, img.Pixel expected) {
  return math
      .max(
        math.max((actual.r - expected.r).abs(), (actual.g - expected.g).abs()),
        math.max((actual.b - expected.b).abs(), (actual.a - expected.a).abs()),
      )
      .toInt();
}

String _describe(img.Pixel pixel) =>
    'rgba(${pixel.r.toInt()}, ${pixel.g.toInt()}, '
    '${pixel.b.toInt()}, ${pixel.a.toInt()})';
