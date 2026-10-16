import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_text_selection_toolbar.dart';

import '../../../helpers/input_surface_expectations.dart';
import '../../../helpers/text_layout_expectations.dart';

void main() {
  group('ThemedFormInput 装饰内容', () {
    testWidgets('标签与提示参数并入 decoration，decoration 自带的优先', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const Column(
            children: [
              ThemedFormInput(
                key: ValueKey('override'),
                labelText: 'Param label',
                hintText: 'Param hint',
                decoration: InputDecoration(
                  label: Text('Decoration label'),
                  hintText: 'Decoration hint',
                ),
              ),
              ThemedFormInput(
                key: ValueKey('fallback'),
                labelText: 'Param only label',
                decoration: InputDecoration(prefixIcon: Icon(Icons.star)),
              ),
            ],
          ),
        ),
      );

      final overridden = innerDecorationOf(
        tester,
        find.byKey(const ValueKey('override')),
      );
      expect(overridden.labelText, isNull);
      expect(overridden.hintText, 'Decoration hint');
      expect(find.text('Decoration label'), findsOneWidget);
      expect(find.text('Param label'), findsNothing);

      expect(find.text('Param only label'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('沿用共享输入框的主题右键菜单与 Ctrl+Y 重做', (tester) async {
    await tester.pumpWidget(inputTestApp(const ThemedFormInput()));
    expect(
      tester.widget<TextField>(find.byType(TextField)).contextMenuBuilder,
      themedContextMenuBuilder,
    );

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(seconds: 1));
    await _pressWithControl(tester, LogicalKeyboardKey.keyZ);
    expect(_text(tester), 'a');
    await _pressWithControl(tester, LogicalKeyboardKey.keyY);
    expect(_text(tester), 'ab');
  });

  group('ThemedFormInput 校验与内容', () {
    testWidgets('校验错误优先于 decoration 的错误文字，校验通过后仍显示调用方错误', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const ThemedFormInput(
            autovalidateMode: AutovalidateMode.always,
            validator: _required,
            decoration: InputDecoration(
              helperText: 'Helper',
              errorText: 'Server says no',
            ),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Server says no'), findsNothing);
      expect(find.text('Helper'), findsNothing);
      expect(inputSurfaceOf(tester).hasError, isTrue);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();

      expect(find.text('Required'), findsNothing);
      expect(find.text('Server says no'), findsOneWidget);
      expect(find.text('Helper'), findsNothing);
      expect(inputSurfaceOf(tester).hasError, isTrue);
    });

    testWidgets('校验错误替换帮助文字，校验通过后恢复帮助文字与普通轮廓', (tester) async {
      await tester.pumpWidget(
        inputTestApp(
          const ThemedFormInput(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _required,
            decoration: InputDecoration(helperText: 'Helper'),
          ),
        ),
      );
      expect(find.text('Helper'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Helper'), findsNothing);
      expect(inputSurfaceOf(tester).hasError, isTrue);

      await tester.enterText(find.byType(TextField), 'y');
      await tester.pump();
      expect(find.text('Required'), findsNothing);
      expect(find.text('Helper'), findsOneWidget);
      expect(inputSurfaceOf(tester).hasError, isFalse);
    });

    testWidgets('initialValue 显示为输入内容，外部更新在未聚焦时同步，编辑中的更新留到失焦后', (tester) async {
      var value = 'Uniform';
      late StateSetter rebuild;
      await tester.pumpWidget(
        inputTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return ThemedFormInput(
                initialValue: value,
                autovalidateMode: AutovalidateMode.always,
                validator: _required,
              );
            },
          ),
        ),
      );
      expect(_text(tester), 'Uniform');

      rebuild(() => value = '');
      await tester.pump();
      expect(_text(tester), '');
      expect(find.text('Required'), findsOneWidget);

      rebuild(() => value = 'Casual');
      await tester.pump();
      expect(_text(tester), 'Casual');
      expect(find.text('Required'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Casu');
      await tester.pump();
      rebuild(() => value = 'Other');
      await tester.pump();
      expect(_text(tester), 'Casu');

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_text(tester), 'Other');
    });

    testWidgets('initialValue 不变时失焦保留用户输入', (tester) async {
      await tester.pumpWidget(
        inputTestApp(const ThemedFormInput(initialValue: 'Uniform')),
      );

      await tester.enterText(find.byType(TextField), 'Casual');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_text(tester), 'Casual');
    });

    testWidgets('传入 controller 时以其内容为准，校验读取程序写入的最新内容', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        inputTestApp(
          ThemedFormInput(
            controller: controller,
            autovalidateMode: AutovalidateMode.always,
            validator: _required,
          ),
        ),
      );
      expect(_text(tester), 'abc');
      expect(find.text('Required'), findsNothing);

      controller.text = '';
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });
  });

  testWidgets('标签、图标、帮助与计数在 320/600 宽度和 3 倍文字下不溢出且完整可见', (tester) async {
    addTearDown(tester.view.reset);
    const helper = 'A helper line long enough to wrap on narrow screens';
    for (final width in [320.0, 600.0]) {
      for (final scale in [1.0, 3.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        final reason = 'width=$width scale=$scale';
        await tester.pumpWidget(
          inputTestApp(
            const ThemedFormInput(
              initialValue: 'Casual',
              decoration: InputDecoration(
                labelText: 'Branch name',
                prefixIcon: Icon(Icons.label_outline_rounded),
                suffixIcon: Icon(Icons.close),
                helperText: helper,
                counterText: '6/64',
              ),
            ),
            textScale: scale,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: reason);
        expectFullyVisible(tester, find.text(helper), reason: reason);
        expectFullyVisible(tester, find.text('6/64'), reason: reason);
        expect(find.text('Branch name'), findsOneWidget, reason: reason);
        expect(find.byIcon(Icons.close).hitTestable(), findsOneWidget);
      }
    }
  });
}

Future<void> _pressWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

String? _required(String? value) => (value ?? '').isEmpty ? 'Required' : null;

String _text(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;
