import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_checkbox.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_switch.dart';

void main() {
  testWidgets(
    'selection controls retain touch-safe targets after mixed input',
    (tester) async {
      await tester.pumpWidget(
        const InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: MaterialApp(home: Scaffold(body: _SelectionControlsHost())),
        ),
      );

      const checkboxKey = Key('test_checkbox');
      const switchKey = Key('test_switch');
      expect(tester.getSize(find.byKey(checkboxKey)), const Size.square(40));
      expect(tester.getSize(find.byKey(switchKey)).height, 40);

      final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
      addTearDown(touch.removePointer);
      await touch.down(tester.getCenter(find.byKey(checkboxKey)));
      await tester.pump();

      expect(tester.getSize(find.byKey(checkboxKey)), const Size.square(48));
      expect(tester.getSize(find.byKey(switchKey)).height, 48);
      await touch.up();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(find.byKey(switchKey)));
      await mouse.moveTo(
        tester.getCenter(find.byKey(switchKey)) + const Offset(1, 0),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(tester.getSize(find.byKey(checkboxKey)), const Size.square(48));
      expect(tester.getSize(find.byKey(switchKey)).height, 48);
    },
  );

  testWidgets('touch target edges activate both selection controls', (
    tester,
  ) async {
    var checkboxChanges = 0;
    var switchChanges = 0;
    await tester.pumpWidget(
      InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ThemedCheckbox(
                  key: const Key('edge_checkbox'),
                  value: false,
                  onChanged: (_) => checkboxChanges++,
                ),
                ThemedSwitch(
                  key: const Key('edge_switch'),
                  value: false,
                  onChanged: (_) => switchChanges++,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final checkboxRect = tester.getRect(find.byKey(const Key('edge_checkbox')));
    final switchRect = tester.getRect(find.byKey(const Key('edge_switch')));
    await tester.tapAt(checkboxRect.topLeft + const Offset(2, 2));
    await tester.pump();
    await tester.tapAt(switchRect.topLeft + const Offset(2, 2));
    await tester.pump();

    expect(checkboxChanges, 1);
    expect(switchChanges, 1);
  });
}

class _SelectionControlsHost extends StatelessWidget {
  const _SelectionControlsHost();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        ThemedCheckbox(
          key: Key('test_checkbox'),
          value: false,
          onChanged: _ignoreNullableBool,
        ),
        ThemedSwitch(
          key: Key('test_switch'),
          value: false,
          onChanged: _ignoreBool,
        ),
      ],
    );
  }

  static void _ignoreNullableBool(bool? value) {}
  static void _ignoreBool(bool value) {}
}
