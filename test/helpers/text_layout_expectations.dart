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
