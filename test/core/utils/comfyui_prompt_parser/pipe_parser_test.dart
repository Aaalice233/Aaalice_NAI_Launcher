import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/comfyui_prompt_parser/pipe_parser.dart';

void main() {
  group('PipeParser', () {
    test('splits line-start and spaced pipes into characters', () {
      const prompt =
          '2girls, masterpiece\n| girl, black hair\n| girl, white hair';

      expect(PipeParser.isPipeFormat(prompt), isTrue);
      final result = PipeParser.parse(prompt);
      expect(result.globalPrompt, '2girls, masterpiece');
      expect(result.characters.map((c) => c.prompt), [
        'girl, black hair',
        'girl, white hair',
      ]);
    });

    test('does not treat random choice blocks as characters', () {
      expect(
        PipeParser.isPipeFormat('1girl, ||red hair | blue hair||, smile'),
        isFalse,
      );
      expect(
        PipeParser.isPipeFormat('1girl, solo\n||standing|sitting||'),
        isFalse,
      );
    });

    test('closes random blocks nested in emphasis before the next role', () {
      final result = PipeParser.parse('2girls, {||red | blue|| hair}\n| alice');

      expect(result.globalPrompt, '2girls, {||red | blue|| hair}');
      expect(result.characters.single.prompt, 'alice');
    });

    test('keeps random choice blocks inside character segments', () {
      final result = PipeParser.parse(
        '2girls, ||day | night||\n| girl, ||red | blue|| hair\n| girl, smile',
      );

      expect(result.globalPrompt, '2girls, ||day | night||');
      expect(result.characters.map((c) => c.prompt), [
        'girl, ||red | blue|| hair',
        'girl, smile',
      ]);
    });
  });
}
