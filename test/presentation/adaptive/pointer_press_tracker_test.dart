import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/pointer_press_tracker.dart';

void main() {
  testWidgets('tracks mouse buttons from press until release or cancel', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    PointerPressTracker.observe();
    addTearDown(PointerPressTracker.unobserve);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    expect(PointerPressTracker.mouseButtonHeld, isFalse);

    await mouse.down(const Offset(10, 10));
    expect(PointerPressTracker.mouseButtonHeld, isTrue);
    await mouse.moveTo(const Offset(40, 40));
    expect(PointerPressTracker.mouseButtonHeld, isTrue);
    await mouse.up();
    expect(PointerPressTracker.mouseButtonHeld, isFalse);

    await mouse.down(const Offset(10, 10));
    expect(PointerPressTracker.mouseButtonHeld, isTrue);
    await mouse.cancel();
    expect(PointerPressTracker.mouseButtonHeld, isFalse);
    await mouse.removePointer();
  });

  testWidgets('a hover clears a press whose release was never delivered', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    PointerPressTracker.observe();
    addTearDown(PointerPressTracker.unobserve);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.down(const Offset(10, 10)));
    expect(PointerPressTracker.mouseButtonHeld, isTrue);

    await tester.sendEventToBinding(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        device: mouse.device,
        position: const Offset(20, 20),
      ),
    );
    expect(PointerPressTracker.mouseButtonHeld, isFalse);
    await tester.sendEventToBinding(mouse.up());
  });

  testWidgets('touches never count as held mouse buttons', (tester) async {
    await tester.pumpWidget(const SizedBox.expand());
    PointerPressTracker.observe();
    addTearDown(PointerPressTracker.unobserve);

    final touch = await tester.startGesture(
      const Offset(10, 10),
      kind: PointerDeviceKind.touch,
    );
    expect(PointerPressTracker.mouseButtonHeld, isFalse);
    await touch.up();
  });

  testWidgets('the last observer leaving clears the recorded state', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.expand());
    PointerPressTracker.observe();
    PointerPressTracker.observe();
    final mouse = await tester.startGesture(
      const Offset(10, 10),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    expect(PointerPressTracker.mouseButtonHeld, isTrue);

    PointerPressTracker.unobserve();
    expect(PointerPressTracker.mouseButtonHeld, isTrue);
    PointerPressTracker.unobserve();
    expect(PointerPressTracker.mouseButtonHeld, isFalse);
    await mouse.up();
  });
}
