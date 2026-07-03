import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/prompt_semantics_utils.dart';

void main() {
  group('buildPromptSemanticsSnapshot', () {
    test('should preserve base prompts while computing effective prompts', () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl, sunset',
        negativePrompt: 'bad hands',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: true,
        ucPreset: UcPresets.toApiValue(UcPresetType.heavy),
      );

      expect(snapshot.basePrompt, equals('1girl, sunset'));
      expect(snapshot.baseNegativePrompt, equals('bad hands'));
      expect(
        snapshot.effectivePrompt,
        equals('1girl, sunset, location, very aesthetic, masterpiece, no text'),
      );
      expect(
        snapshot.effectiveNegativePrompt,
        startsWith('lowres, artistic error'),
      );
      expect(snapshot.effectiveNegativePrompt, isNot(contains('nsfw')));
      expect(snapshot.effectiveNegativePrompt, endsWith('bad hands'));
    });

    test(
        'should keep prompt unchanged when quality and uc presets are disabled',
        () {
      final snapshot = buildPromptSemanticsSnapshot(
        prompt: '1girl',
        negativePrompt: 'blurry',
        model: ImageModels.animeDiffusionV45Full,
        qualityToggle: false,
        ucPreset: UcPresets.toApiValue(UcPresetType.none),
      );

      expect(snapshot.basePrompt, equals('1girl'));
      expect(snapshot.baseNegativePrompt, equals('blurry'));
      expect(snapshot.effectivePrompt, equals('1girl'));
      expect(snapshot.effectiveNegativePrompt, equals('blurry'));
    });
  });
}
