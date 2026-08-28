import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';

void main() {
  group('NaiSyntaxController official emphasis parity', () {
    testWidgets('highlights complete multi-word numerical emphasis', (
      tester,
    ) async {
      final controller = NaiSyntaxController(
        text:
            '1.2::white hair::, '
            '1.2::torn nun habit::, '
            '1.2::white ear fluff::',
      );
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(
        _highlightedTexts(children),
        equals([
          '1.2::white hair',
          '::',
          '1.2::torn nun habit',
          '::',
          '1.2::white ear fluff',
          '::',
        ]),
      );
      expect(_plainText(children), equals(', , '));
      expect(_rgb(children[0].style!.backgroundColor!), 0xED5807);
      expect(_rgb(children[1].style!.backgroundColor!), 0x7ACC29);
    });

    testWidgets('keeps incomplete numerical emphasis active through spaces', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: '2::stomach bulge:');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['2::stomach bulge:']));
      expect(_plainText(children), isEmpty);
    });

    testWidgets('resets numerical emphasis at a bare double colon', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: '2::stomach::, plain');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['2::stomach', '::']));
      expect(_plainText(children), equals(', plain'));
      expect(_rgb(children[1].style!.backgroundColor!), 0x7ACC29);
    });

    testWidgets('applies nested brackets as cumulative actions', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: '{{tag}} plain');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(
        children.map((span) => span.text).toList(),
        equals(['{', '{tag', '}', '} plain']),
      );
      expect(_highlightedTexts(children), equals(['{', '{tag', '}']));
      final outerColor = children[0].style!.backgroundColor!;
      final nestedColor = children[1].style!.backgroundColor!;
      expect(children[2].style!.backgroundColor, outerColor);
      expect(nestedColor.a, greaterThan(outerColor.a));
    });

    testWidgets('does not treat unmatched brackets as syntax errors', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: '{unclosed tag');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['{unclosed tag']));
      expect(controller.syntaxErrors, isEmpty);
    });

    testWidgets('bare double colon clears bracket emphasis', (tester) async {
      final controller = NaiSyntaxController(text: '{rain ::plain');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['{rain ', '::']));
      expect(_plainText(children), equals('plain'));
      expect(_rgb(children[1].style!.backgroundColor!), 0x7ACC29);
      expect(controller.syntaxErrors, isEmpty);
    });

    testWidgets('accepts numerical emphasis without a leading zero', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: '.5::coat');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['.5::coat']));
      expect(_rgb(children.single.style!.backgroundColor!), 0x079CED);
    });

    testWidgets('disables numerical emphasis for models before V4', (
      tester,
    ) async {
      final controller = NaiSyntaxController(
        text: '2::plain, {strong}',
        numericEmphasisEnabled: false,
      );
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['{strong']));
      expect(_plainText(children), equals('2::plain, }'));
    });

    testWidgets('highlights every pipe independently of emphasis setting', (
      tester,
    ) async {
      final controller = NaiSyntaxController(
        text: '<alias>|character||random',
        highlightEnabled: false,
      );
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);
      final pipeSpans = children
          .where((span) => span.style?.fontWeight == FontWeight.w800)
          .toList();

      expect(pipeSpans.map((span) => span.text).toList(), equals(['|', '||']));
      expect(
        pipeSpans.every((span) => span.style?.backgroundColor == null),
        isTrue,
      );
      expect(
        children.every((span) => span.style?.backgroundColor == null),
        isTrue,
      );
    });

    testWidgets('tints the complete negative block without hiding weights', (
      tester,
    ) async {
      final controller = NaiSyntaxController(
        text: 'girl, negative({red hair}, 1.2::glasses::)',
      );
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);
      final negativeSpans = children
          .where((span) => span.style?.color != null)
          .toList();

      expect(
        negativeSpans.map((span) => span.text).join(),
        'negative({red hair}, 1.2::glasses::)',
      );
      expect(
        negativeSpans.any((span) => span.style?.backgroundColor != null),
        isTrue,
      );
      expect(controller.syntaxErrors, isEmpty);
    });

    testWidgets('keeps negative semantics when search highlighting overlaps', (
      tester,
    ) async {
      final controller = NaiSyntaxController(text: 'girl, negative(red hair)')
        ..updateSearchHighlights(
          matches: const [TextRange(start: 15, end: 23)],
          activeMatchIndex: 0,
        );
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);
      final match = children.singleWhere((span) => span.text == 'red hair');

      expect(match.style?.color, isNotNull);
      expect(match.style?.backgroundColor, isNotNull);
    });

    testWidgets('reports malformed negative block syntax', (tester) async {
      final controller = NaiSyntaxController(
        text: 'negative(), negative(red hair',
      );
      addTearDown(controller.dispose);

      await _buildTextSpanChildren(tester, controller);

      expect(controller.syntaxErrors, contains('negative(...) 块未闭合'));
      expect(controller.syntaxErrors, contains('negative(...) 块不能为空'));
    });
  });
}

Future<List<TextSpan>> _buildTextSpanChildren(
  WidgetTester tester,
  NaiSyntaxController controller,
) async {
  late TextSpan span;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          span = controller.buildTextSpan(
            context: context,
            style: const TextStyle(fontSize: 14),
            withComposing: false,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return span.children!.cast<TextSpan>().toList();
}

List<String> _highlightedTexts(List<TextSpan> spans) {
  return spans
      .where((span) => span.style?.backgroundColor != null)
      .map((span) => span.text!)
      .toList();
}

String _plainText(List<TextSpan> spans) {
  return spans
      .where((span) => span.style?.backgroundColor == null)
      .map((span) => span.text!)
      .join();
}

int _rgb(Color color) => color.toARGB32() & 0x00FFFFFF;
