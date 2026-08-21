import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';

void main() {
  group('TransparencyBackgrounds.normalize', () {
    test('缺省与未知值回落到主题棋盘格', () {
      expect(
        TransparencyBackgrounds.normalize(null),
        TransparencyBackgrounds.checker,
      );
      expect(
        TransparencyBackgrounds.normalize(''),
        TransparencyBackgrounds.checker,
      );
      expect(
        TransparencyBackgrounds.normalize('bogus'),
        TransparencyBackgrounds.checker,
      );
      // 位数不足的颜色串同样按非法处理
      expect(
        TransparencyBackgrounds.normalize('#abc'),
        TransparencyBackgrounds.checker,
      );
    });

    test('官网档位原样保留', () {
      for (final style in [
        TransparencyBackgrounds.checker,
        TransparencyBackgrounds.checkerLight,
        TransparencyBackgrounds.checkerDark,
        TransparencyBackgrounds.none,
        'black',
        'white',
        'gray',
        'red',
        'green',
        'blue',
      ]) {
        expect(TransparencyBackgrounds.normalize(style), style);
      }
    });

    test('自定义颜色统一成小写', () {
      expect(TransparencyBackgrounds.normalize('#FF8800'), '#ff8800');
    });
  });

  group('自定义颜色编解码', () {
    test('解析六位十六进制并补满不透明度', () {
      expect(
        TransparencyBackgrounds.parseCustomColor('#ff8800'),
        const Color(0xFFFF8800),
      );
    });

    test('非自定义值或位数不符返回 null', () {
      expect(TransparencyBackgrounds.parseCustomColor('red'), isNull);
      expect(TransparencyBackgrounds.parseCustomColor('#12345'), isNull);
      expect(TransparencyBackgrounds.parseCustomColor('#zzzzzz'), isNull);
    });

    test('编码后可原样解析回同一颜色', () {
      const color = Color(0xFF3366CC);
      final encoded = TransparencyBackgrounds.encodeCustomColor(color);
      expect(encoded, '#3366cc');
      expect(TransparencyBackgrounds.parseCustomColor(encoded), color);
    });
  });

  group('档位取色', () {
    final theme = ThemeData.dark();

    test('固定棋盘格档位取官网配色', () {
      expect(
        TransparencyBackgrounds.checkerColorsOf(
          TransparencyBackgrounds.checkerLight,
          theme,
        ),
        (const Color(0xFFCCCCCC), const Color(0xFFFFFFFF)),
      );
      expect(
        TransparencyBackgrounds.checkerColorsOf(
          TransparencyBackgrounds.checkerDark,
          theme,
        ),
        (const Color(0xFF494949), const Color(0xFF2A2A2A)),
      );
    });

    test('主题棋盘格跟随当前主题的表面色', () {
      final colors = TransparencyBackgrounds.checkerColorsOf(
        TransparencyBackgrounds.checker,
        theme,
      );
      expect(colors, isNotNull);
      expect(colors!.$2, theme.colorScheme.surface);
      expect(colors.$1, isNot(colors.$2));
    });

    test('纯色档位不当作棋盘格，棋盘格档位不当作纯色', () {
      expect(TransparencyBackgrounds.checkerColorsOf('red', theme), isNull);
      expect(
        TransparencyBackgrounds.solidColorOf(TransparencyBackgrounds.checker),
        isNull,
      );
      expect(
        TransparencyBackgrounds.solidColorOf('red'),
        const Color(0xFFFF0000),
      );
      expect(
        TransparencyBackgrounds.solidColorOf('#3366cc'),
        const Color(0xFF3366CC),
      );
    });
  });

  group('TransparencyBackgroundLayer', () {
    testWidgets('none 档位不铺任何底色', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TransparencyBackgroundLayer(
            style: TransparencyBackgrounds.none,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(TransparencyBackgroundLayer),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TransparencyBackgroundLayer),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('纯色档位铺 ColoredBox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TransparencyBackgroundLayer(style: 'red')),
      );

      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(TransparencyBackgroundLayer),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, const Color(0xFFFF0000));
    });

    testWidgets('棋盘格档位走自绘', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TransparencyBackgroundLayer(
            style: TransparencyBackgrounds.checkerDark,
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(TransparencyBackgroundLayer),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });
  });
}
