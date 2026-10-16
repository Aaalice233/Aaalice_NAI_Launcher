import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../../../helpers/input_surface_expectations.dart';

void main() {
  group('ThemedInput 平面输入色面', () {
    testWidgets('以不占布局的主题色外轮廓表达聚焦状态', (tester) async {
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
      expect(unfocusedBorder.top.width, 1);
      expect(unfocusedBorder.top.color, Colors.transparent);
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

  group('ThemedInput 装饰与下方文字', () {
    testWidgets('标签与图标显示在色面内，帮助与错误排在色面下方并点亮错误轮廓', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const Column(
            children: [
              ThemedInput(
                key: ValueKey('helper'),
                decoration: InputDecoration(
                  labelText: 'Weight',
                  prefixIcon: Icon(Icons.scale),
                  helperText: 'Shown below',
                ),
              ),
              ThemedInput(
                key: ValueKey('error'),
                decoration: InputDecoration(errorText: 'Name taken'),
              ),
            ],
          ),
        ),
      );

      expect(insideInputSurface(find.text('Weight')), findsOneWidget);
      expect(insideInputSurface(find.byIcon(Icons.scale)), findsOneWidget);
      for (final (key, text, hasError) in [
        ('helper', 'Shown below', false),
        ('error', 'Name taken', true),
      ]) {
        final field = find.byKey(ValueKey(key));
        expect(insideInputSurface(find.text(text)), findsNothing);
        expect(
          tester.getTopLeft(find.text(text)).dy,
          greaterThanOrEqualTo(
            tester
                .getBottomLeft(
                  find.descendant(
                    of: field,
                    matching: find.byType(InputSurfaceContainer),
                  ),
                )
                .dy,
          ),
        );
        expect(inputSurfaceOf(tester, field).hasError, hasError, reason: key);
      }
      expect(innerDecorationOf(tester).helperText, isNull);
    });

    testWidgets('错误随输入出现和消失时输入框不重建，焦点与输入法连接保持', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        inputTestApp(
          StatefulBuilder(
            builder: (context, setState) => ThemedInput(
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                errorText: controller.text == 'bad' ? 'Invalid' : null,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final editable = tester.state(find.byType(EditableText));

      for (final (text, error) in [
        ('bad', findsOneWidget),
        ('good', findsNothing),
      ]) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        expect(find.text('Invalid'), error, reason: text);
        expect(tester.state(find.byType(EditableText)), same(editable));
        expect(tester.testTextInput.hasAnyClients, isTrue);
      }
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('没有下方文字时色面填满调用方给定的高度', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const SizedBox(
            height: 56,
            child: ThemedInput(decoration: InputDecoration(isDense: true)),
          ),
        ),
      );

      expect(tester.getSize(find.byType(InputSurfaceContainer)).height, 56);
    });

    testWidgets('expands 时错误排在下方，色面填满其余高度', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const SizedBox(
            height: 200,
            child: ThemedInput(
              expands: true,
              maxLines: null,
              decoration: InputDecoration(errorText: 'Too long'),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final surface = tester.getRect(find.byType(InputSurfaceContainer));
      final error = tester.getRect(find.text('Too long'));
      expect(error.top, greaterThanOrEqualTo(surface.bottom));
      expect(error.bottom, lessThanOrEqualTo(surface.top + 200));
      expect(surface.height, greaterThan(150));
    });
  });

  group('ThemedInput 清空按钮', () {
    for (final (policy, extent) in [
      (InteractionPolicy.touchFirst, 48.0),
      (InteractionPolicy.neutral, 32.0),
    ]) {
      testWidgets('单行输入框的清空按钮 $extent 见方、完整可点，文字不排到按钮下面', (tester) async {
        final controller = TextEditingController(text: 'a long query text');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) =>
                InteractionPolicyScope(initialPolicy: policy, child: child!),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 280,
                  child: ThemedInput(
                    controller: controller,
                    showClearButton: true,
                  ),
                ),
              ),
            ),
          ),
        );

        final button = find.ancestor(
          of: find.byIcon(Icons.close),
          matching: find.byType(IconButton),
        );
        final buttonRect = tester.getRect(button);
        expect(buttonRect.size, Size(extent, extent));
        expect(
          tester
              .getRect(find.byType(TextField))
              .inflate(0.01)
              .contains(buttonRect.topLeft),
          isTrue,
        );
        expect(
          tester
              .getRect(find.byType(TextField))
              .inflate(0.01)
              .contains(buttonRect.bottomRight),
          isTrue,
        );
        expect(button.hitTestable(), findsOneWidget);
        expect(
          tester.getRect(find.byType(EditableText)).right,
          lessThanOrEqualTo(buttonRect.left),
        );
      });
    }

    testWidgets('之后才开启清空按钮也按内容显隐，卸载后不再监听外部控制器', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      Future<void> pumpInput({required bool showClearButton}) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ThemedInput(
                controller: controller,
                showClearButton: showClearButton,
              ),
            ),
          ),
        );
      }

      await pumpInput(showClearButton: false);
      await pumpInput(showClearButton: true);
      await tester.enterText(find.byType(TextField), 'girl');
      await tester.pump();
      expect(find.byIcon(Icons.close), findsOneWidget);

      await pumpInput(showClearButton: false);
      expect(find.byIcon(Icons.close), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      controller.text = '';
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('改由内部持有控制器时保留已输入内容', (tester) async {
      final controller = TextEditingController(text: 'girl');
      addTearDown(controller.dispose);
      Future<void> pumpInput(TextEditingController? value) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ThemedInput(controller: value)),
          ),
        );
      }

      await pumpInput(controller);
      await pumpInput(null);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'girl',
      );
    });

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
