import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/inset_shadow_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

void main() {
  group('ThemedInput 语义色面', () {
    testWidgets('默认无完整边框，聚焦时才显示状态边界', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ThemedInput(hintText: 'Prompt')),
        ),
      );

      var surface = tester.widget<InsetShadowContainer>(
        find.byType(InsetShadowContainer),
      );
      expect(surface.borderWidth, 0);
      expect(surface.isFocused, isFalse);

      await tester.tap(find.byType(TextField));
      await tester.pump();

      surface = tester.widget<InsetShadowContainer>(
        find.byType(InsetShadowContainer),
      );
      expect(surface.isFocused, isTrue);
    });
  });

  group('ThemedInput 清空按钮', () {
    testWidgets('文本在空/非空间切换时输入框不重建、焦点不丢失', (tester) async {
      final controller = TextEditingController(text: 'girl');
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThemedInput(
              controller: controller,
              focusNode: focusNode,
              showClearButton: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      final stateBefore = tester.state(find.byType(EditableText));

      // 删光文本：清空按钮隐藏，但输入框的 Element 必须存活，
      // 否则键盘输入连接被打断、光标消失（回归：Stack 层按内容增删）
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      final stateAfterClear = tester.state(find.byType(EditableText));
      expect(
        identical(stateBefore, stateAfterClear),
        isTrue,
        reason: '删空后 EditableText 不应重建',
      );
      expect(focusNode.hasFocus, isTrue);

      // 再输入首字母：清空按钮出现，同样不能触发重建
      await tester.enterText(find.byType(TextField), 'g');
      await tester.pump();

      final stateAfterType = tester.state(find.byType(EditableText));
      expect(
        identical(stateBefore, stateAfterType),
        isTrue,
        reason: '重新输入后 EditableText 不应重建',
      );
      expect(focusNode.hasFocus, isTrue);
      expect(controller.text, 'g');
    });
  });
}
