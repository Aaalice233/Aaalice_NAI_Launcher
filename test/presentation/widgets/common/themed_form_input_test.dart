import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_form_input.dart';

import '../../../helpers/text_layout_expectations.dart';

void main() {
  group('ThemedFormInput 装饰内容', () {
    testWidgets('decoration 的标签、提示、图标与前后缀文字显示在输入色面内', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ThemedFormInput(
                initialValue: '42',
                decoration: InputDecoration(
                  labelText: 'Weight',
                  prefixIcon: Icon(Icons.scale),
                  suffixIcon: Icon(Icons.close),
                  prefixText: '~',
                  suffixText: '%',
                ),
              ),
              ThemedFormInput(decoration: InputDecoration(hintText: 'Type')),
              ThemedFormInput(
                decoration: InputDecoration(label: Text('Label widget')),
              ),
              ThemedFormInput(
                decoration: InputDecoration(hint: Text('Hint widget')),
              ),
            ],
          ),
        ),
      );

      for (final target in [
        find.text('Weight'),
        find.byIcon(Icons.scale),
        find.byIcon(Icons.close),
        find.text('~'),
        find.text('%'),
        find.text('Type'),
        find.text('Label widget'),
        find.text('Hint widget'),
      ]) {
        expect(_insideSurface(target), findsOneWidget, reason: '$target');
      }
      expect(_decorationOf(tester).labelText, 'Weight');
      expect(tester.takeException(), isNull);
    });

    testWidgets('decoration 的帮助、计数与错误文字显示在输入色面下方，错误点亮错误轮廓', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ThemedFormInput(
                key: ValueKey('helper'),
                decoration: InputDecoration(
                  helperText: 'Shown below',
                  counterText: '3/10',
                ),
              ),
              ThemedFormInput(
                key: ValueKey('error'),
                decoration: InputDecoration(
                  helperText: 'Hidden by error',
                  errorText: 'Name taken',
                ),
              ),
            ],
          ),
        ),
      );

      for (final text in ['Shown below', '3/10', 'Name taken']) {
        expect(find.text(text), findsOneWidget, reason: text);
        expect(_insideSurface(find.text(text)), findsNothing, reason: text);
      }
      expect(find.text('Hidden by error'), findsNothing);

      final helperSurface = _surfaceIn(const ValueKey('helper'));
      expect(
        tester.widget<InputSurfaceContainer>(helperSurface).hasError,
        isFalse,
      );
      expect(
        tester.getTopLeft(find.text('Shown below')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(helperSurface).dy),
      );
      expect(
        tester.getCenter(find.text('3/10')).dx,
        greaterThan(tester.getCenter(find.text('Shown below')).dx),
      );

      final errorSurface = _surfaceIn(const ValueKey('error'));
      expect(
        tester.widget<InputSurfaceContainer>(errorSurface).hasError,
        isTrue,
      );
      final inner = _decorationOf(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('error')),
          matching: find.byType(TextField),
        ),
      );
      expect(inner.errorText, isNull);
      expect(inner.helperText, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('decoration 的非空属性覆盖同名参数，未提供时沿用参数', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              ThemedFormInput(
                key: ValueKey('override'),
                labelText: 'Param label',
                hintText: 'Param hint',
                helperText: 'Param helper',
                prefixIcon: Icon(Icons.abc),
                contentPadding: EdgeInsets.all(4),
                decoration: InputDecoration(
                  label: Text('Decoration label'),
                  hintText: 'Decoration hint',
                  helperText: 'Decoration helper',
                  prefixIcon: Icon(Icons.person),
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
              ThemedFormInput(
                key: ValueKey('fallback'),
                labelText: 'Param only label',
                helperText: 'Param only helper',
                decoration: InputDecoration(prefixIcon: Icon(Icons.star)),
              ),
            ],
          ),
        ),
      );

      final overridden = _decorationOf(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('override')),
          matching: find.byType(TextField),
        ),
      );
      expect(overridden.labelText, isNull);
      expect(overridden.hintText, 'Decoration hint');
      expect(overridden.contentPadding, const EdgeInsets.all(20));
      expect(find.text('Decoration label'), findsOneWidget);
      expect(find.text('Param label'), findsNothing);
      expect(find.text('Decoration helper'), findsOneWidget);
      expect(find.text('Param helper'), findsNothing);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.abc), findsNothing);

      expect(find.text('Param only label'), findsOneWidget);
      expect(find.text('Param only helper'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('边框与填充由输入色面绘制，decoration 的边框和填充不生效', (tester) async {
      await tester.pumpWidget(
        _app(
          const ThemedFormInput(
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.red,
            ),
          ),
        ),
      );

      final inner = _decorationOf(tester);
      expect(inner.labelText, 'Name');
      expect(inner.border, InputBorder.none);
      expect(inner.enabledBorder, InputBorder.none);
      expect(inner.focusedBorder, InputBorder.none);
      expect(inner.filled, isFalse);
      expect(inner.fillColor, isNull);
    });
  });

  group('ThemedFormInput 校验与内容', () {
    testWidgets('校验错误优先于 decoration 的错误文字，校验通过后仍显示调用方错误', (tester) async {
      await tester.pumpWidget(
        _app(
          const ThemedFormInput(
            autovalidateMode: AutovalidateMode.always,
            validator: _required,
            helperText: 'Helper',
            decoration: InputDecoration(errorText: 'Server says no'),
          ),
        ),
      );

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Server says no'), findsNothing);
      expect(find.text('Helper'), findsNothing);
      expect(_surfaceHasError(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump();

      expect(find.text('Required'), findsNothing);
      expect(find.text('Server says no'), findsOneWidget);
      expect(find.text('Helper'), findsNothing);
      expect(_surfaceHasError(tester), isTrue);
    });

    testWidgets('校验错误替换帮助文字，校验通过后恢复帮助文字与普通轮廓', (tester) async {
      await tester.pumpWidget(
        _app(
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
      expect(_surfaceHasError(tester), isTrue);

      await tester.enterText(find.byType(TextField), 'y');
      await tester.pump();
      expect(find.text('Required'), findsNothing);
      expect(find.text('Helper'), findsOneWidget);
      expect(_surfaceHasError(tester), isFalse);
    });

    testWidgets('initialValue 显示为输入内容，外部更新在未聚焦时同步，编辑中的更新留到失焦后', (tester) async {
      var value = 'Uniform';
      late StateSetter rebuild;
      await tester.pumpWidget(
        _app(
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

    testWidgets('initialValue 不变时失焦保留用户输入，onSaved 读取当前内容', (tester) async {
      final formKey = GlobalKey<FormState>();
      String? saved;
      await tester.pumpWidget(
        _app(
          Form(
            key: formKey,
            child: ThemedFormInput(
              initialValue: 'Uniform',
              onSaved: (value) => saved = value,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Casual');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(_text(tester), 'Casual');

      formKey.currentState!.save();
      expect(saved, 'Casual');
    });

    testWidgets('传入 controller 时以其内容为准，校验读取程序写入的最新内容', (tester) async {
      final controller = TextEditingController(text: 'abc');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
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
          _app(
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

String? _required(String? value) => (value ?? '').isEmpty ? 'Required' : null;

Widget _app(Widget child, {double textScale = 1}) {
  return MaterialApp(
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

Finder _insideSurface(Finder target) =>
    find.descendant(of: find.byType(InputSurfaceContainer), matching: target);

Finder _surfaceIn(Key key) => find.descendant(
  of: find.byKey(key),
  matching: find.byType(InputSurfaceContainer),
);

InputDecoration _decorationOf(WidgetTester tester, [Finder? field]) =>
    tester.widget<TextField>(field ?? find.byType(TextField).first).decoration!;

bool _surfaceHasError(WidgetTester tester) => tester
    .widget<InputSurfaceContainer>(find.byType(InputSurfaceContainer))
    .hasError;

String _text(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;
