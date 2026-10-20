import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// 聚焦输入框并选中 [text] 中的 [part]，再在输入框上用鼠标滚轮向上滚一格。
Future<void> wheelSelectedPart(
  WidgetTester tester,
  String text,
  String part,
) async {
  final field = find.byType(EditableText).first;
  await tester.tap(field);
  await tester.pump();
  final start = text.indexOf(part);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + part.length,
      ),
    ),
  );
  await tester.pump();
  final pointer = TestPointer(1, PointerDeviceKind.mouse)
    ..hover(tester.getCenter(field));
  await tester.sendEventToBinding(pointer.scroll(const Offset(0, -40)));
  await tester.pump();
}
