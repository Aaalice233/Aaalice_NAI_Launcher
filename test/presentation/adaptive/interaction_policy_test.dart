import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';

void main() {
  group('InteractionPolicy', () {
    test('provides neutral and touch-first initial policies', () {
      expect(InteractionPolicy.neutral.modality, InteractionModality.unknown);
      expect(InteractionPolicy.neutral.touchAvailable, isFalse);
      expect(InteractionPolicy.neutral.precisePointerAvailable, isFalse);
      expect(InteractionPolicy.neutral.usesAnchoredMenus, isFalse);
      expect(InteractionPolicy.neutral.minimumControlExtent, 40);

      expect(InteractionPolicy.touchFirst.modality, InteractionModality.touch);
      expect(InteractionPolicy.touchFirst.touchAvailable, isTrue);
      expect(InteractionPolicy.touchFirst.precisePointerAvailable, isFalse);
      expect(InteractionPolicy.touchFirst.minimumControlExtent, 48);
    });

    test('retains capabilities while the active modality changes', () {
      const initial = InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      );

      final touch = initial.withPointerDevice(PointerDeviceKind.touch);
      expect(touch.modality, InteractionModality.touch);
      expect(touch.touchAvailable, isTrue);
      expect(touch.precisePointerAvailable, isTrue);
      expect(touch.minimumControlExtent, 48);
      expect(touch.prefersTouchPresentation, isTrue);
      expect(touch.shouldExposeTouchAlternatives, isTrue);
      expect(touch.usesTouchActionMenu, isTrue);
      expect(touch.usesAnchoredMenus, isFalse);

      final keyboard = touch.withModality(InteractionModality.keyboard);
      expect(keyboard.keyboardNavigationActive, isTrue);
      expect(keyboard.touchAvailable, isTrue);
      expect(keyboard.precisePointerAvailable, isTrue);
      expect(keyboard.minimumControlExtent, 48);
      expect(keyboard.prefersTouchPresentation, isFalse);
      expect(keyboard.shouldExposeTouchAlternatives, isTrue);
      expect(keyboard.usesTouchActionMenu, isFalse);
    });

    test('an observed mouse adds precise-pointer capability', () {
      const initial = InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      );

      final pointer = initial.withPointerDevice(PointerDeviceKind.mouse);
      expect(pointer.modality, InteractionModality.pointer);
      expect(pointer.touchAvailable, isTrue);
      expect(pointer.precisePointerAvailable, isTrue);
      expect(pointer.prefersTouchPresentation, isFalse);
      expect(pointer.shouldExposeTouchAlternatives, isTrue);
      expect(pointer.usesTouchActionMenu, isFalse);
      expect(pointer.usesAnchoredMenus, isTrue);
    });
  });

  testWidgets(
    'Windows touchscreen sequence retains touch targets after mouse and keyboard',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      await tester.pumpWidget(_policyHost());
      expect(find.text('unknown|false|false|40.0'), findsOneWidget);

      final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(touch.removePointer);
      await touch.down(const Offset(100, 100));
      await tester.pump();
      expect(find.text('touch|true|false|48.0'), findsOneWidget);
      await touch.up();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(100, 100));
      await mouse.moveTo(const Offset(101, 100));
      await tester.pump();
      expect(find.text('pointer|true|true|48.0'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.text('keyboard|true|true|48.0'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'mobile touch-first policy retains touch after an external mouse',
    (tester) async {
      await tester.pumpWidget(
        _policyHost(initialPolicy: InteractionPolicy.touchFirst),
      );
      expect(find.text('touch|true|false|48.0'), findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(100, 100));
      await mouse.moveTo(const Offset(101, 100));
      await tester.pump();
      expect(find.text('pointer|true|true|48.0'), findsOneWidget);
    },
  );

  testWidgets(
    'first touch callback reads the observed policy in the same event',
    (tester) async {
      InteractionPolicy? activatedPolicy;
      await tester.pumpWidget(
        InteractionPolicyScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      activatedPolicy = context.interactionPolicy;
                    },
                    child: const Text('Open menu'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open menu'));

      expect(activatedPolicy?.modality, InteractionModality.touch);
      expect(activatedPolicy?.prefersTouchPresentation, isTrue);
      expect(activatedPolicy?.minimumControlExtent, 48);
    },
  );

  testWidgets(
    'first secondary-click callback reads precise-pointer policy in same event',
    (tester) async {
      InteractionPolicy? activatedPolicy;
      await tester.pumpWidget(
        InteractionPolicyScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapDown: (_) {
                      activatedPolicy = context.interactionPolicy;
                    },
                    child: const SizedBox(
                      width: 120,
                      height: 48,
                      child: Center(child: Text('Open context menu')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Open context menu')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      addTearDown(gesture.removePointer);

      expect(activatedPolicy?.modality, InteractionModality.pointer);
      expect(activatedPolicy?.precisePointerAvailable, isTrue);
      expect(activatedPolicy?.usesAnchoredMenus, isTrue);
      await gesture.up();
    },
  );

  testWidgets('scope keeps observed input policy across viewport changes', (
    tester,
  ) async {
    await tester.pumpWidget(_policyHost(size: const Size(1200, 800)));

    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    addTearDown(touch.removePointer);
    await touch.down(const Offset(100, 100));
    await tester.pump();
    expect(find.text('touch|true|false|48.0'), findsOneWidget);

    await tester.pumpWidget(_policyHost(size: const Size(400, 800)));
    await tester.pump();
    expect(find.text('touch|true|false|48.0'), findsOneWidget);
  });
}

Widget _policyHost({
  Size size = const Size(800, 600),
  InteractionPolicy? initialPolicy,
}) {
  return MaterialApp(
    home: InteractionPolicyScope(
      initialPolicy: initialPolicy,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            final policy = context.interactionPolicy;
            return SizedBox.expand(
              child: Text(
                '${policy.modality.name}|${policy.touchAvailable}|'
                '${policy.precisePointerAvailable}|'
                '${policy.minimumControlExtent}',
              ),
            );
          },
        ),
      ),
    ),
  );
}
