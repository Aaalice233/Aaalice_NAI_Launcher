import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_type_switch.dart';

void main() {
  test('counts prompt segments without splitting a nested weighted group', () {
    final controller = PromptInputController(
      prompt: '{{{masterpiece, best quality}}}, 1girl',
      negativePrompt: 'lowres, bad anatomy, watermark',
    );
    addTearDown(controller.dispose);

    expect(controller.promptCount, 2);
    expect(controller.negativePromptCount, 3);
  });

  testWidgets('compact prompt type button always displays its tag count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 110,
              child: PromptTypeButton(
                icon: Icons.block,
                label: '负面',
                count: 0,
                isSelected: false,
                color: Colors.red,
                compact: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('负面'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rich prompt tooltip stays open while its controls are clicked', (
    tester,
  ) async {
    var actionCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: PromptTypeButton(
                icon: Icons.auto_awesome,
                label: '正面',
                count: 2,
                isSelected: true,
                color: Colors.blue,
                onTap: () {},
                tooltipBuilder: (_) => TextButton(
                  onPressed: () => actionCount++,
                  child: const Text('展开提示词'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('正面')));
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();

    final action = find.text('展开提示词');
    expect(action, findsOneWidget);
    await mouse.moveTo(tester.getCenter(action));
    await tester.pump();
    await mouse.down(tester.getCenter(action));
    await mouse.up();
    await tester.pumpAndSettle();

    expect(actionCount, 1);
    expect(action, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
