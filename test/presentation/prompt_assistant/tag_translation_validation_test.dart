import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';

void main() {
  test('accepts a complete strict JSON tag mapping', () {
    final result = PromptAssistantService.validateTagTranslationResponse(
      '{"blue_eyes":"蓝眼睛","long_hair":"长发"}',
      ['blue_eyes', 'long_hair'],
    );

    expect(result, {'blue_eyes': '蓝眼睛', 'long_hair': '长发'});
  });

  test('rejects unknown keys, incomplete mappings, and invalid values', () {
    expect(
      () => PromptAssistantService.validateTagTranslationResponse(
        '{"unknown":"未知"}',
        ['blue_eyes'],
      ),
      throwsFormatException,
    );
    expect(
      () => PromptAssistantService.validateTagTranslationResponse(
        '{"blue_eyes":"蓝眼睛"}',
        ['blue_eyes', 'long_hair'],
      ),
      throwsFormatException,
    );
    expect(
      () => PromptAssistantService.validateTagTranslationResponse(
        '{"blue_eyes":"line\\nbreak"}',
        ['blue_eyes'],
      ),
      throwsFormatException,
    );
  });
}
