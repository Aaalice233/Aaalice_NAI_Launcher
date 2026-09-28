import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/delayed_rich_tooltip.dart';
import 'package:nai_launcher/presentation/widgets/common/rich_tooltip_surface.dart';

void main() {
  testWidgets(
    'moving between previews always waits, entering content permits scrolling',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                for (final name in ['A', 'B'])
                  DelayedRichTooltip(
                    content: RichTooltipSurface(
                      maxHeight: 180,
                      child: Column(
                        children: [
                          for (var i = 0; i < 30; i++) Text('$name preview $i'),
                        ],
                      ),
                    ),
                    child: SizedBox(width: 100, height: 44, child: Text(name)),
                  ),
              ],
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(700, 500));
      await mouse.moveTo(tester.getCenter(find.text('A')));
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('A preview 0'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('A preview 0'), findsOneWidget);
      await mouse.moveTo(tester.getCenter(find.text('B')));
      await tester.pump(const Duration(milliseconds: 299));
      expect(find.text('A preview 0'), findsNothing);
      expect(find.text('B preview 0'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      final surface = find.byType(RichTooltipSurface);
      expect(surface, findsOneWidget);
      await mouse.moveTo(tester.getCenter(surface));
      await tester.pump(const Duration(milliseconds: 500));
      expect(surface, findsOneWidget);
      final scrollable = find.descendant(
        of: surface,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(120);
      await tester.pump();
      expect(position.pixels, 120);
      await mouse.moveTo(const Offset(700, 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(surface, findsNothing);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
