import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 断言文本以单行完整排出：没有换行、拦腰断词或截断
void expectSingleLineUntruncated(
  WidgetTester tester,
  Finder text, {
  String? reason,
}) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(
    paragraph.size.width,
    greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5),
    reason: reason,
  );
}

/// 断言文本完整可见：允许换行，但没有截断、省略、被父级裁高或越出屏幕左右边缘
void expectFullyVisible(WidgetTester tester, Finder text, {String? reason}) {
  final paragraph = tester.renderObject<RenderParagraph>(text);
  expect(paragraph.didExceedMaxLines, isFalse, reason: reason);
  expect(
    paragraph.size.height,
    greaterThanOrEqualTo(
      paragraph.getMinIntrinsicHeight(paragraph.size.width) - 0.5,
    ),
    reason: reason,
  );
  final rect = tester.getRect(text);
  final screenWidth = tester.binding.renderViews.first.size.width;
  expect(rect.left, greaterThanOrEqualTo(-0.5), reason: reason);
  expect(rect.right, lessThanOrEqualTo(screenWidth + 0.5), reason: reason);
}
