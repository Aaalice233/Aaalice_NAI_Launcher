import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_preset_resolution.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_request_preparation_service.dart';

void main() {
  test(
    'disabled aliases never reach expansion and request snapshots retain only active content',
    () async {
      final expanded = <String>[];
      final service = GenerationRequestPreparationService(
        GenerationPreparationDependencies(
          prompt: GenerationPromptPreparation(
            randomModeEnabled: false,
            queueExecuting: false,
            generateAndApplyRandomPrompt: (_) async => '',
            resolveAliases: (source) {
              expanded.add(source);
              return source;
            },
            applyFixedPositiveTags: (source) => '$source, /*disabled:fixed*/',
            applyFixedNegativeTags: (source) => source,
            fixedTagUsageSnapshot: const FixedTagUsageSnapshot(),
            resolvePresets: (params) => PromptPresetResolution(
              prompt: params.prompt,
              negativePrompt: params.negativePrompt,
              qualityToggle: false,
              ucPreset: 0,
              omitQualityTagHint: false,
              omitUcPresetTagHint: false,
            ),
          ),
          characters: GenerationCharacterPreparation(
            read: (_) => const CharacterPreparationSnapshot(
              characters: [
                CharacterPrompt(
                  prompt: 'girl, /*disabled:hat*/',
                  negativePrompt: '/*disabled:bad*/',
                ),
              ],
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
      const original = ImageParams(
        prompt: 'cat, /*disabled:<random:secret1,secret2>*/',
        negativePrompt: 'bad, /*disabled:noise*/',
      );
      final prepared = await service.prepareInitial(original);
      expect(expanded, ['cat', 'bad']);
      expect(prepared.params.prompt, 'cat');
      expect(prepared.params.negativePrompt, 'bad');
      expect(prepared.params.characters.single.prompt, 'girl');
      expect(prepared.params.characters.single.negativePrompt, '');
      expect(original.prompt, contains('/*disabled:'));
    },
  );
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
            fixedTagUsageSnapshot: const FixedTagUsageSnapshot(),
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
