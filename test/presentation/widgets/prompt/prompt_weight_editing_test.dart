import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_weight_editing.dart';

TextEditingController _select(String text, String part) {
  final start = text.indexOf(part);
  return TextEditingController(text: text)
    ..selection = TextSelection(
      baseOffset: start,
      extentOffset: start + part.length,
    );
}

void main() {
  for (final newline in ['\n', '\r\n']) {
    test(
      'repeated weight steps preserve multiline content ${newline.length}',
      () {
        final body =
            'cat,${newline}blue eyes,$newline$newline'
            'upper_body, three-quarter_view,$newline'
            'backlighting, soft background';
        final controller = TextEditingController(text: body)
          ..selection = TextSelection(baseOffset: 0, extentOffset: body.length);
        addTearDown(controller.dispose);

        for (final (expected, label) in [
          (0.95, '0.95'),
          (0.90, '0.9'),
          (0.95, '0.95'),
          (1.0, ''),
          (1.05, '1.05'),
          (1.10, '1.1'),
          (1.05, '1.05'),
        ]) {
          final current = PromptWeightEditing.parseSelection(controller).weight;
          expect(
            PromptWeightEditing.stepWeight(
              controller,
              expected > current ? 0.05 : -0.05,
            ),
            isTrue,
          );
          expect(controller.text, label.isEmpty ? body : '$label::$body::');
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

    test('numeric weights inside a multiline selection get a bracket wrapper '
        '${newline.length}', () {
      final body =
          'cat,${newline}blue eyes,$newline$newline'
          '1.46::upper_body, {{{{three-quarter_view}}}}::,$newline'
          '0.90::backlighting, rim_light::, soft background';
      final controller = TextEditingController(text: body)
        ..selection = TextSelection(baseOffset: 0, extentOffset: body.length);
      addTearDown(controller.dispose);

      for (final (step, shell) in [
        (-0.05, ('[', ']')),
        (-0.05, ('[[', ']]')),
        (0.05, ('[', ']')),
        (0.05, ('', '')),
        (0.05, ('{', '}')),
        (0.05, ('{{', '}}')),
      ]) {
        PromptWeightEditing.stepWeight(controller, step);
        expect(controller.text, '${shell.$1}$body${shell.$2}');
        expect(PromptWeightEditing.parseSelection(controller).baseText, body);
        expect(
          controller.selection,
          TextSelection(baseOffset: 0, extentOffset: controller.text.length),
        );
      }
    });
  }

  group('selection resolves to the weight it lies in', () {
    const tagged = 'a, 1.05::iu::, b';
    const group = 'a, 1.2::x, y::, b';
    const sentence = 'a girl 1.05::red umbrella:: in rain';
    for (final (name, text, part, step, expected) in [
      ('whole tag', tagged, '1.05::iu::', 0.05, 'a, 1.1::iu::, b'),
      ('tag text', tagged, 'iu', 0.05, 'a, 1.1::iu::, b'),
      ('part of tag text', tagged, 'i', -0.05, 'a, iu, b'),
      ('missing closing', tagged, '1.05::iu', 0.05, 'a, 1.1::iu::, b'),
      ('leading separator', tagged, ', 1.05::iu::', 0.05, 'a, 1.1::iu::, b'),
      ('trailing separator', tagged, '1.05::iu::,', 0.05, 'a, 1.1::iu::, b'),
      ('stacked shell', '0.9::1.05::iu::::', 'iu', 0.05, '1.1::iu::'),
      ('group content', group, 'x, y', 0.05, 'a, 1.25::x, y::, b'),
      ('tag inside group', group, 'x', 0.05, 'a, 1.2::{x}, y::, b'),
      ('bracket tag', 'a, {{iu}}, b', 'iu', -0.05, 'a, 1.05::iu::, b'),
      (
        'unweighted words',
        'a, blue hair, b',
        'blue',
        0.05,
        'a, 1.05::blue:: hair, b',
      ),
      ('several tags', 'a, b, c', 'a, b', 0.05, '1.05::a, b::, c'),
      (
        'several tags with a numeric weight',
        tagged,
        'a, 1.05::iu::',
        0.05,
        '{a, 1.05::iu::}, b',
      ),
      (
        'inline weight',
        sentence,
        'red',
        0.05,
        'a girl 1.1::red umbrella:: in rain',
      ),
      (
        'outside inline weight',
        sentence,
        'girl',
        0.05,
        'a 1.05::girl:: 1.05::red umbrella:: in rain',
      ),
      (
        'partly covered inline weight',
        'a {red umbrella} b',
        'umbrella} b',
        0.05,
        'a 1.05::{red umbrella} b::',
      ),
    ]) {
      test(name, () {
        final controller = _select(text, part);
        addTearDown(controller.dispose);

        expect(PromptWeightEditing.stepWeight(controller, step), isTrue);
        expect(controller.text, expected);
      });
    }

    test('readout reports the enclosing weight', () {
      final controller = _select(tagged, 'iu');
      addTearDown(controller.dispose);

      expect(PromptWeightEditing.parseSelection(controller).weight, 1.05);
      expect(PromptWeightEditing.parseSelection(controller).baseText, 'iu');
    });

    test('a selection of separators alone is not weighted', () {
      final controller = _select(tagged, ', ');
      addTearDown(controller.dispose);

      expect(PromptWeightEditing.stepWeight(controller, 0.05), isFalse);
      expect(controller.text, tagged);
    });
  });

  test('written weights use the shared format and drop the wrapper at 1', () {
    expect(PromptWeightEditing.withWeight('iu', 0.5), '0.5::iu::');
    expect(PromptWeightEditing.withWeight('1.5::iu::', 1), 'iu');
  });
}
