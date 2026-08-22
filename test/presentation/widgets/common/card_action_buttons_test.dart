import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';

void main() {
  testWidgets('buttons appear and disappear in the same pump', (tester) async {
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

    expect(find.byIcon(Icons.download), findsNothing);
    setHostState(() => visible = true);
    await tester.pump();
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CardActionButtons),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(CardActionButtons),
        matching: find.byType(SlideTransition),
      ),
      findsNothing,
    );

    setHostState(() => visible = false);
    await tester.pump();
    expect(find.byIcon(Icons.download), findsNothing);
  });
}
