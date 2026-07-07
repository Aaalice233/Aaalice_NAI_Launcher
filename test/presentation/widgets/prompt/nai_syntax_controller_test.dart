import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';

void main() {
  group('NaiSyntaxController', () {
    testWidgets('highlights complete multi-word weighted tags', (tester) async {
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
      expect(_plainText(children), isNot(contains(' hair')));
      expect(_plainText(children), isNot(contains(' nun habit')));
      expect(_plainText(children), equals(', , '));
    });

    testWidgets('keeps leading-only weighted tag highlighting', (tester) async {
      final controller = NaiSyntaxController(text: '1.2::white_hair, plain');
      addTearDown(controller.dispose);

      final children = await _buildTextSpanChildren(tester, controller);

      expect(_highlightedTexts(children), equals(['1.2::white_hair']));
      expect(_plainText(children), equals(', plain'));
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
