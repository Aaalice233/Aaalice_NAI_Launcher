import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/input_surface_decoration.dart';

const _padding = EdgeInsets.all(4);

void main() {
  group('fieldDecoration', () {
    test('标签、提示、图标与前后缀文字交给输入框，边框、填充、帮助、错误与计数留给色面', () {
      const prefixIcon = Icon(Icons.scale);
      const suffixIcon = Icon(Icons.close);
      final field = InputSurfaceDecoration(
        const InputDecoration(
          labelText: 'Weight',
          hintText: 'Type',
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          prefixText: '~',
          suffixText: '%',
          helperText: 'Helper',
          errorText: 'Error',
          counterText: '3/10',
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.red,
        ),
        contentPadding: _padding,
      ).fieldDecoration;

      expect(field.labelText, 'Weight');
      expect(field.hintText, 'Type');
      expect(field.prefixIcon, same(prefixIcon));
      expect(field.suffixIcon, same(suffixIcon));
      expect(field.prefixText, '~');
      expect(field.suffixText, '%');
      expect(field.helperText, isNull);
      expect(field.errorText, isNull);
      expect(field.counterText, isEmpty);
      for (final border in [
        field.border,
        field.enabledBorder,
        field.focusedBorder,
        field.disabledBorder,
        field.errorBorder,
        field.focusedErrorBorder,
      ]) {
        expect(border, InputBorder.none);
      }
      expect(field.filled, isFalse);
      expect(field.fillColor, isNull);
      expect(field.isDense, isTrue);
    });

    test('decoration 的非空属性覆盖同名参数，未提供时沿用参数', () {
      const paramPrefix = Icon(Icons.abc);
      const paramSuffix = Icon(Icons.close);
      const decorationPrefix = Icon(Icons.person);
      InputDecoration fieldOf(InputDecoration? decoration) =>
          InputSurfaceDecoration(
            decoration,
            contentPadding: _padding,
            hintText: 'Param hint',
            hintStyle: const TextStyle(fontSize: 11),
            prefixIcon: paramPrefix,
            suffixIcon: paramSuffix,
          ).fieldDecoration;

      final overridden = fieldOf(
        const InputDecoration(
          hintText: 'Decoration hint',
          hintStyle: TextStyle(fontSize: 13),
          prefixIcon: decorationPrefix,
          contentPadding: EdgeInsets.all(20),
          isDense: false,
        ),
      );
      expect(overridden.hintText, 'Decoration hint');
      expect(overridden.hintStyle?.fontSize, 13);
      expect(overridden.prefixIcon, same(decorationPrefix));
      expect(overridden.suffixIcon, same(paramSuffix));
      expect(overridden.contentPadding, const EdgeInsets.all(20));
      expect(overridden.isDense, isFalse);

      final hintWidget = fieldOf(const InputDecoration(hint: Text('Widget')));
      expect(hintWidget.hintText, isNull);
      expect(hintWidget.hint, isA<Text>());

      final fallback = fieldOf(null);
      expect(fallback.hintText, 'Param hint');
      expect(fallback.hintStyle?.fontSize, 11);
      expect(fallback.prefixIcon, same(paramPrefix));
      expect(fallback.contentPadding, _padding);
    });
  });

  test('errorText 或 error 组件都算错误状态', () {
    bool hasError(InputDecoration? decoration) =>
        InputSurfaceDecoration(decoration, contentPadding: _padding).hasError;

    expect(hasError(null), isFalse);
    expect(hasError(const InputDecoration(helperText: 'Helper')), isFalse);
    expect(hasError(const InputDecoration(errorText: 'Error')), isTrue);
    expect(hasError(const InputDecoration(error: Text('Error'))), isTrue);
  });

  group('supportingText', () {
    test('没有帮助、错误与计数时不占位置', () {
      expect(
        InputSurfaceDecoration(
          const InputDecoration(labelText: 'Name'),
          contentPadding: _padding,
        ).supportingText(),
        isNull,
      );
    });

    testWidgets('错误替换帮助文字，使用错误色与 bodySmall', (tester) async {
      await _pumpSupporting(
        tester,
        InputSurfaceDecoration(
          const InputDecoration(
            helperText: 'Decoration helper',
            errorText: 'Name taken',
          ),
          contentPadding: _padding,
          helperText: 'Param helper',
        ),
      );

      final theme = Theme.of(tester.element(find.text('Name taken')));
      expect(find.text('Decoration helper'), findsNothing);
      expect(find.text('Param helper'), findsNothing);
      _expectStyle(
        tester,
        'Name taken',
        color: theme.colorScheme.error,
        fontSize: theme.textTheme.bodySmall!.fontSize!,
      );
    });

    testWidgets('帮助文字取 decoration 的、没有时取参数，使用 onSurfaceVariant', (
      tester,
    ) async {
      for (final (decoration, expected) in [
        (
          const InputDecoration(helperText: 'Decoration helper'),
          'Decoration helper',
        ),
        (null, 'Param helper'),
      ]) {
        await _pumpSupporting(
          tester,
          InputSurfaceDecoration(
            decoration,
            contentPadding: _padding,
            helperText: 'Param helper',
          ),
        );
        final theme = Theme.of(tester.element(find.text(expected)));
        _expectStyle(
          tester,
          expected,
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: theme.textTheme.bodySmall!.fontSize!,
        );
      }
    });

    testWidgets('计数排在帮助文字之后的末端，左右按内边距缩进', (tester) async {
      await _pumpSupporting(
        tester,
        InputSurfaceDecoration(
          const InputDecoration(helperText: 'Helper', counterText: '3/10'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );

      final helper = tester.getRect(find.text('Helper'));
      final counter = tester.getRect(find.text('3/10'));
      expect(counter.left, greaterThan(helper.right));
      expect(helper.left, 12);
      expect(counter.right, 300 - 12);
    });
  });
}

Future<void> _pumpSupporting(
  WidgetTester tester,
  InputSurfaceDecoration surface,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: surface.supportingText()),
      ),
    ),
  );
}

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
