import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_container.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

typedef _FieldBuilder =
    Widget Function({String? helperText, InputDecoration? decoration});

final _components = <String, _FieldBuilder>{
  'ThemedInput': ({helperText, decoration}) =>
      ThemedInput(helperText: helperText, decoration: decoration),
};

void main() {
  for (final MapEntry(key: name, value: build) in _components.entries) {
    group('$name 下方文字', () {
      testWidgets('decoration 的错误显示在色面下方并替换帮助文字，使用错误色与 bodySmall', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            build(
              helperText: 'Param helper',
              decoration: const InputDecoration(
                helperText: 'Decoration helper',
                errorText: 'Name taken',
              ),
            ),
          ),
        );

        final theme = Theme.of(tester.element(find.byType(TextField)));
        expect(find.text('Name taken'), findsOneWidget);
        expect(_insideSurface(find.text('Name taken')), findsNothing);
        expect(_below(tester, find.text('Name taken')), isTrue);
        expect(find.text('Decoration helper'), findsNothing);
        expect(find.text('Param helper'), findsNothing);
        expect(_surface(tester).hasError, isTrue);
        expect(_fieldDecoration(tester).errorText, isNull);
        _expectStyle(
          tester,
          'Name taken',
          color: theme.colorScheme.error,
          fontSize: theme.textTheme.bodySmall!.fontSize!,
        );
      });

      testWidgets('帮助文字在色面下方：decoration 优先于参数，使用 onSurfaceVariant', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            Column(
              children: [
                build(helperText: 'Param only'),
                build(
                  helperText: 'Param helper',
                  decoration: const InputDecoration(
                    helperText: 'Decoration helper',
                  ),
                ),
              ],
            ),
          ),
        );

        final theme = Theme.of(tester.element(find.byType(TextField).first));
        for (final text in ['Param only', 'Decoration helper']) {
          expect(find.text(text), findsOneWidget, reason: text);
          expect(_insideSurface(find.text(text)), findsNothing, reason: text);
          _expectStyle(
            tester,
            text,
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: theme.textTheme.bodySmall!.fontSize!,
          );
        }
        expect(find.text('Param helper'), findsNothing);
        expect(
          tester
              .widgetList<InputSurfaceContainer>(
                find.byType(InputSurfaceContainer),
              )
              .any((surface) => surface.hasError),
          isFalse,
        );
      });

      testWidgets('decoration 的计数显示在色面下方末端', (tester) async {
        await tester.pumpWidget(
          _app(
            build(
              decoration: const InputDecoration(
                helperText: 'Helper',
                counterText: '3/10',
              ),
            ),
          ),
        );

        expect(_insideSurface(find.text('3/10')), findsNothing);
        expect(
          tester.getCenter(find.text('3/10')).dx,
          greaterThan(tester.getCenter(find.text('Helper')).dx),
        );
      });
    });
  }

  group('ThemedInput 布局', () {
    testWidgets('错误随输入出现和消失时输入框不重建，焦点与输入法连接保持', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
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

      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump();
      expect(find.text('Invalid'), findsOneWidget);
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await tester.enterText(find.byType(TextField), 'good');
      await tester.pump();
      expect(find.text('Invalid'), findsNothing);
      expect(tester.state(find.byType(EditableText)), same(editable));
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(
        tester
            .state<EditableTextState>(find.byType(EditableText))
            .widget
            .focusNode
            .hasFocus,
        isTrue,
      );
    });

    testWidgets('没有下方文字时色面填满调用方给定的高度', (tester) async {
      await tester.pumpWidget(
        _app(
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
        _app(
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
}

Widget _app(Widget child) {
  return MaterialApp(
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

InputSurfaceContainer _surface(WidgetTester tester) =>
    tester.widget<InputSurfaceContainer>(find.byType(InputSurfaceContainer));

InputDecoration _fieldDecoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

bool _below(WidgetTester tester, Finder text) =>
    tester.getTopLeft(text).dy >=
    tester.getBottomLeft(find.byType(InputSurfaceContainer)).dy;

void _expectStyle(
  WidgetTester tester,
  String text, {
  required Color color,
  required double fontSize,
}) {
  final style = tester
      .renderObject<RenderParagraph>(find.text(text))
      .text
      .style;
  expect(style?.color, color, reason: text);
  expect(style?.fontSize, fontSize, reason: text);
}
