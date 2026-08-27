import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

void main() {
  group('ThemedInput 平面输入色面', () {
    testWidgets('仅移除内发光，并以主题色外轮廓表达聚焦状态', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ThemedInput(hintText: 'Prompt')),
        ),
      );

      var surface = tester.widget<InputSurfaceContainer>(
        find.byType(InputSurfaceContainer),
      );
      expect(surface.borderWidth, 0);
      expect(surface.isFocused, isFalse);
      expect(
        find.descendant(
          of: find.byType(InputSurfaceContainer),
          matching: find.byKey(const ValueKey('input_surface_inner_shadow')),
        ),
        findsNothing,
      );
      var surfaceDecoration = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(InputSurfaceContainer),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .single;
      final unfocusedBorder = surfaceDecoration.border! as Border;
      expect(unfocusedBorder.top.width, 0.55);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textAlignVertical,
        TextAlignVertical.center,
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      surface = tester.widget<InputSurfaceContainer>(
        find.byType(InputSurfaceContainer),
      );
      expect(surface.isFocused, isTrue);
      surfaceDecoration = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(InputSurfaceContainer),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .single;
      final focusedBorder = surfaceDecoration.border! as Border;
      expect(focusedBorder.top.width, 1);
      expect(focusedBorder.top.color, isNot(unfocusedBorder.top.color));
    });

    testWidgets('内部输入装饰不继承全局填充层遮挡圆角边界', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.red,
            ),
          ),
          home: const Scaffold(body: ThemedInput(hintText: 'Prompt')),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.filled, isFalse);

      final inputContext = tester.element(find.byType(ThemedInput));
      final colors = Theme.of(inputContext).colorScheme;
      final surface = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(InputSurfaceContainer),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .singleWhere(
            (widget) =>
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color != null,
          );
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, isNot(colors.surfaceContainerLowest));
      expect(decoration.color, inputSurfaceFillColor(colors));

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(InputSurfaceContainer),
          matching: find.byKey(const ValueKey('input_surface_inner_shadow')),
        ),
        findsNothing,
      );
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
