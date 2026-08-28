import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_preset_resolution.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_request_preparation_service.dart';

void main() {
  test(
    'ordinary library alias insertion submits only its positive portion',
    () async {
      final service = GenerationRequestPreparationService(
        GenerationPreparationDependencies(
          prompt: GenerationPromptPreparation(
            randomModeEnabled: false,
            queueExecuting: false,
            generateAndApplyRandomPrompt: (_) async => '',
            resolveAliases: (prompt) => prompt == '<alice>'
                ? 'girl, blue eyes, negative(red hair, glasses)'
                : prompt,
            applyFixedPositiveTags: (prompt) =>
                '$prompt, negative(fixed literal)',
            applyFixedNegativeTags: (prompt) => prompt,
            resolvePresets: (params) => PromptPresetResolution(
              prompt: params.prompt,
              negativePrompt: params.negativePrompt,
              qualityToggle: params.qualityToggle,
              ucPreset: params.ucPreset,
              omitQualityTagHint: params.omitQualityTagHint,
              omitUcPresetTagHint: params.omitUcPresetTagHint,
            ),
          ),
          characters: GenerationCharacterPreparation(
            read: (_) => const CharacterPreparationSnapshot(
              characters: [],
              useCoords: false,
            ),
          ),
          vibes: GenerationVibePreparation(prepare: (params) async => params),
          focused: GenerationFocusedPreparation(
            read: () => const GenerationFocusedSnapshot(
              enabled: false,
              minimumContextMegaPixels: 0,
            ),
          ),
        ),
      );

      final result = await service.prepareInitial(
        const ImageParams(prompt: '<alice>', negativePrompt: 'global uc'),
      );

      expect(result.params.prompt, 'girl, blue eyes, negative(fixed literal)');
      expect(result.params.negativePrompt, 'global uc');
      expect(result.params.prompt, isNot(contains('red hair')));
      expect(result.params.prompt, isNot(contains('glasses')));
    },
  );
}
