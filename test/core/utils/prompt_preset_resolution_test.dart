import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/prompt_preset_resolution.dart';
import 'package:nai_launcher/data/models/prompt/prompt_preset_mode.dart';

void main() {
  group('resolvePromptPresetSettings', () {
    test('keeps native presets as flags instead of mutating prompt text', () {
      final result = resolvePromptPresetSettings(
        prompt: '1girl, sunset',
        negativePrompt: 'bad hands',
        qualityMode: PromptPresetMode.naiDefault,
        qualityContent: QualityTags.getQualityTags(
          ImageModels.animeDiffusionV45Full,
        ),
        ucPresetType: UcPresetType.heavy,
        ucPresetContent: UcPresets.getPresetContent(
          ImageModels.animeDiffusionV45Full,
          UcPresetType.heavy,
        ),
        useCustomUcPreset: false,
      );

      expect(result.prompt, equals('1girl, sunset'));
      expect(result.negativePrompt, equals('bad hands'));
      expect(result.qualityToggle, isTrue);
      expect(result.ucPreset, equals(0));
    });

    test('turns custom presets into explicit request text', () {
      final result = resolvePromptPresetSettings(
        prompt: '1girl',
        negativePrompt: 'bad hands',
        qualityMode: PromptPresetMode.custom,
        qualityContent: 'cinematic lighting',
        ucPresetType: UcPresetType.heavy,
        ucPresetContent: 'lowres, bad anatomy',
        useCustomUcPreset: true,
      );

      expect(result.prompt, equals('1girl, cinematic lighting'));
      expect(result.negativePrompt, equals('lowres, bad anatomy, bad hands'));
      expect(result.qualityToggle, isFalse);
      expect(result.ucPreset, equals(UcPresets.noneApiValue));
    });

    test('matches legacy quality toggle and native uc preset request ids', () {
      expect(
        resolvePromptPresetSettings(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          qualityMode: PromptPresetMode.naiDefault,
          qualityContent: QualityTags.getQualityTags(
            ImageModels.animeDiffusionV45Full,
          ),
          ucPresetType: UcPresetType.heavy,
          ucPresetContent: UcPresets.getPresetContent(
            ImageModels.animeDiffusionV45Full,
            UcPresetType.heavy,
          ),
          useCustomUcPreset: false,
        ).qualityToggle,
        isTrue,
      );
      expect(
        resolvePromptPresetSettings(
          prompt: '1girl',
          negativePrompt: 'bad hands',
          qualityMode: PromptPresetMode.none,
          qualityContent: null,
          ucPresetType: UcPresetType.none,
          ucPresetContent: '',
          useCustomUcPreset: false,
        ).qualityToggle,
        isFalse,
      );

      expect(UcPresets.toApiValue(UcPresetType.heavy), equals(0));
      expect(UcPresets.toApiValue(UcPresetType.light), equals(1));
      expect(UcPresets.toApiValue(UcPresetType.humanFocus), equals(2));
      expect(UcPresets.toApiValue(UcPresetType.none), equals(3));
      expect(
        UcPresets.toApiValue(UcPresetType.furryFocus),
        equals(UCPresets.furryFocus),
      );
    });
  });
}
