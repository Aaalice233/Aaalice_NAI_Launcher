import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';

void main() {
  testWidgets('visibility changes hit testing and opacity in the same pump', (
    tester,
  ) async {
    var visible = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            setHostState = setState;
            return CardActionButtons(
              visible: visible,
              buttons: [
                CardActionButtonConfig(
                  icon: Icons.download,
                  tooltip: 'download',
                  onPressed: () {},
                ),
              ],
            );
          },
        ),
      ),
    );

    final opacity = find.descendant(
      of: find.byType(CardActionButtons),
      matching: find.byType(Opacity),
    );
    final hitTestGate = find.descendant(
      of: find.byType(CardActionButtons),
      matching: find.byType(IgnorePointer),
    );

    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(tester.widget<Opacity>(opacity).opacity, 0);
    expect(tester.widget<IgnorePointer>(hitTestGate).ignoring, isTrue);

    setHostState(() => visible = true);
    await tester.pump();

    expect(tester.widget<Opacity>(opacity).opacity, 1);
    expect(tester.widget<IgnorePointer>(hitTestGate).ignoring, isFalse);

    setHostState(() => visible = false);
    await tester.pump();

    expect(tester.widget<Opacity>(opacity).opacity, 0);
    expect(tester.widget<IgnorePointer>(hitTestGate).ignoring, isTrue);
  });
}
