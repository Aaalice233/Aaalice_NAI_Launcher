import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';

void main() {
  testWidgets('hint follows scroll position, resized viewport and content', (
    tester,
  ) async {
    const hint = ValueKey('hint');
    const scroll = ValueKey('scroll');
    Future<void> pumpStrip(double width, double contentWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              child: HorizontalActionStrip(
                minimumExtent: 48,
                scrollKey: scroll,
                hintKey: hint,
                child: SizedBox(width: contentWidth, height: 48),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpStrip(320, 700);
    expect(find.byKey(hint), findsOneWidget);
    await tester.drag(find.byKey(scroll), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(hint), findsNothing);
    await tester.drag(find.byKey(scroll), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(hint), findsOneWidget);
    await pumpStrip(750, 700);
    expect(find.byKey(hint), findsNothing);
    await pumpStrip(320, 700);
    expect(find.byKey(hint), findsOneWidget);
    await pumpStrip(320, 200);
    expect(find.byKey(hint), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
