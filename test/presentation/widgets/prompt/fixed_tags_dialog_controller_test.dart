import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog_controller.dart';

void main() {
  testWidgets('responsive transition tolerates two attached list positions', (
    tester,
  ) async {
    final controller = FixedTagsDialogController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              for (var index = 0; index < 2; index++)
                Expanded(
                  child: ListView(
                    controller: controller.positiveListController,
                    children: const [SizedBox(height: 800)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(controller.positiveListController.positions, hasLength(2));
    expect(
      controller.scrollOffsetFor(FixedTagPromptType.positive),
      isNonNegative,
    );
    expect(tester.takeException(), isNull);
  });
}
