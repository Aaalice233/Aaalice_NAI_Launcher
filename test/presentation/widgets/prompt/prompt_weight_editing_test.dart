import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_weight_editing.dart';

void main() {
  for (final newline in ['\n', '\r\n']) {
    test(
      'repeated weight steps preserve multiline content ${newline.length}',
      () {
        final body =
            'cat,${newline}blue eyes,$newline$newline'
            '1.46::upper_body, {{{{three-quarter_view}}}}::,$newline'
            '0.90::backlighting, rim_light::, soft background';
        final controller = TextEditingController(text: body)
          ..selection = TextSelection(baseOffset: 0, extentOffset: body.length);
        addTearDown(controller.dispose);

        for (final expected in [0.95, 0.90, 0.95, 1.0, 1.05, 1.10, 1.05]) {
          final current = PromptWeightEditing.parseSelection(controller).weight;
          final step = expected > current ? 0.05 : -0.05;
          expect(
            PromptWeightEditing.applyWeight(controller, current + step),
            isTrue,
          );
          expect(
            controller.text,
            expected == 1 ? body : '${expected.toStringAsFixed(2)}::$body::',
          );
          expect(
            PromptWeightEditing.parseSelection(controller).weight,
            closeTo(expected, 0.00001),
          );
          expect(PromptWeightEditing.parseSelection(controller).baseText, body);
          expect(
            controller.selection,
            TextSelection(baseOffset: 0, extentOffset: controller.text.length),
          );
        }
      },
    );
  }
}
