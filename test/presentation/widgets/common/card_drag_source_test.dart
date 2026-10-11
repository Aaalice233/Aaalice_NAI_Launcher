import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_drag_source.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

const _cardKey = ValueKey('card');

const _desktop = TargetPlatformVariant({
  TargetPlatform.windows,
  TargetPlatform.macOS,
});

void main() {
  late int taps;

  setUp(() => taps = 0);

  Widget host({bool mountSource = true, bool enabled = true}) {
    // A childless SizedBox is not hit-testable, which would hide every press.
    const card = ColoredBox(
      key: _cardKey,
      color: Colors.grey,
      child: SizedBox(width: 120, height: 80),
    );
    return MaterialApp(
      home: Scaffold(
        body: InteractionPolicyScope(
          initialPolicy: InteractionPolicy.neutral,
          child: Center(
            child: mountSource
                ? CardDragSource(
                    enabled: enabled,
                    resource: () =>
                        const CardDragResource(id: 'a', fileName: 'a.png'),
                    // Only fires when the drag recognizer did not claim the press.
                    child: GestureDetector(
                      onTap: () => taps++,
                      child: card,
                    ),
                  )
                : card,
          ),
        ),
      ),
    );
  }

  Future<TestGesture> hover(WidgetTester tester, PointerDeviceKind kind) async {
    final gesture = await tester.createGesture(kind: kind);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byKey(_cardKey)));
    await tester.pump();
    return gesture;
  }

  Future<void> pressAndDrag(WidgetTester tester, TestGesture mouse) async {
    final center = tester.getCenter(find.byKey(_cardKey));
    await mouse.moveTo(center);
    await tester.pump();
    await mouse.down(center);
    await mouse.moveBy(const Offset(12, 0));
    await mouse.up();
    await tester.pump();
  }

  bool widgetAllowsDrag(WidgetTester tester) => tester
      .widget<DraggableWidget>(find.byType(DraggableWidget))
      .isLocationDraggable(Offset.zero);

  testWidgets(
    'source mounted before any pointer input drags once a mouse is observed',
    (tester) async {
      await tester.pumpWidget(host());
      expect(widgetAllowsDrag(tester), isFalse);

      final mouse = await hover(tester, PointerDeviceKind.mouse);
      await pressAndDrag(tester, mouse);

      expect(taps, 0);
    },
    variant: _desktop,
  );

  testWidgets(
    'source mounted during pen input drags once the mouse returns',
    (tester) async {
      await tester.pumpWidget(host(mountSource: false));
      final mouse = await hover(tester, PointerDeviceKind.mouse);
      await hover(tester, PointerDeviceKind.stylus);

      await tester.pumpWidget(host());
      expect(widgetAllowsDrag(tester), isFalse);

      await pressAndDrag(tester, mouse);

      expect(taps, 0);
    },
    variant: _desktop,
  );

  testWidgets(
    'disabling a mounted source stops its recognizer from claiming the mouse',
    (tester) async {
      await tester.pumpWidget(host(mountSource: false));
      final mouse = await hover(tester, PointerDeviceKind.mouse);
      await tester.pumpWidget(host());
      await pressAndDrag(tester, mouse);
      expect(taps, 0);

      await tester.pumpWidget(host(enabled: false));
      await pressAndDrag(tester, mouse);

      expect(taps, 1);
    },
    variant: _desktop,
  );
}
