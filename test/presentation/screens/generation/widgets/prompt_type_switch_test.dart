import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
