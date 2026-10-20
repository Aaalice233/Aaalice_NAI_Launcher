import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/data/models/online_gallery/ai_tag_generation_info.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/pending_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_coordinator.dart';
import 'package:nai_launcher/presentation/services/generation_prompt_transfer_service.dart';

void main() {
  for (final enabled in [false, true]) {
    for (final spaces in [false, true]) {
      String byMode(String disabled, String spaced, String underscored) =>
          !enabled
          ? disabled
          : spaces
          ? spaced
          : underscored;

      final positive = byMode(
        'long hair, blue_eyes',
        'long hair, blue eyes',
        'long_hair, blue_eyes',
      );
      final negative = byMode(
        'bad hands, low_quality',
        'bad hands, low quality',
        'bad_hands, low_quality',
      );

      ProviderContainer createContainer() {
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              _SettingsStorage({
                StorageKeys.autoFormatPrompt: enabled,
                StorageKeys.autocompleteReplaceUnderscores: spaces,
              }),
            ),
            generationParamsNotifierProvider.overrideWith(
              _TestGenerationParamsNotifier.new,
            ),
            promptConfigNotifierProvider.overrideWith(_FixedRandomPrompt.new),
            characterPromptNotifierProvider.overrideWith(_TestCharacters.new),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test(
        'random apply honors formatting=$enabled and spaces=$spaces',
        () async {
          final container = createContainer();
          await container
              .read(imageGenerationNotifierProvider.notifier)
              .generateAndApplyRandomPrompt();
          expect(
            container.read(generationParamsNotifierProvider).prompt,
            positive,
          );
          final character = container
              .read(characterPromptNotifierProvider)
              .characters
              .single;
          expect(character.prompt, positive);
          expect(character.negativePrompt, negative);
        },
      );

      testWidgets(
        'pending library transfer honors formatting=$enabled and spaces=$spaces',
        (tester) async {
          final container = createContainer();
          final controller = PromptInputController(
            prompt: '',
            negativePrompt: '',
          );
          addTearDown(controller.dispose);
          late PromptInputCoordinator coordinator;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: Consumer(
                builder: (context, ref, _) {
                  coordinator = PromptInputCoordinator(
                    ref: ref,
                    controller: controller,
                    context: () => context,
                    mounted: () => false,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          container
              .read(pendingPromptNotifierProvider.notifier)
              .set(
                prompt: 'long hair, blue_eyes',
                targetType: SendTargetType.mainPrompt,
              );
          coordinator.consumePendingPrompt();
          expect(controller.promptController.text, positive);
          expect(
            container.read(generationParamsNotifierProvider).prompt,
            positive,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      test('transfer honors formatting=$enabled and spaces=$spaces', () {
        final container = createContainer();
        container
            .read(generationPromptTransferServiceProvider)
            .replaceMainPrompt(
              prompt: 'long hair, blue_eyes',
              negativePrompt: 'bad hands, low_quality',
            );
        final params = container.read(generationParamsNotifierProvider);
        expect(params.prompt, positive);
        expect(params.negativePrompt, negative);
      });

      test(
        'character transfer converts SD syntax and honors formatting=$enabled '
        'and spaces=$spaces',
        () {
          final container = createContainer();
          container
              .read(generationPromptTransferServiceProvider)
              .replaceCharacterPrompts(const [
                CharacterPrompt(
                  id: 'a',
                  name: 'A',
                  prompt: '(long hair:1.2), blue_eyes',
                  negativePrompt: 'bad hands, low_quality',
                ),
                CharacterPrompt(id: 'b', name: 'B', prompt: 'solo'),
              ]);
          final characters = container
              .read(characterPromptNotifierProvider)
              .characters;
          expect(characters.map((character) => character.id), ['a', 'b']);
          expect(
            characters.first.prompt,
            byMode(
              '1.2::long hair::, blue_eyes',
              '1.2::long hair::, blue eyes',
              '1.2::long_hair::, blue_eyes',
            ),
          );
          expect(characters.first.negativePrompt, negative);
          expect(characters.last.prompt, 'solo');
          expect(characters.last.negativePrompt, isEmpty);
        },
      );
    }
  }

  test('transfer separates numeric closings when the setting is on', () {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          _SettingsStorage({StorageKeys.separateNumericWeightClosing: true}),
        ),
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(prompt: '1.05::year 2025::, other tags');
    expect(
      container.read(generationParamsNotifierProvider).prompt,
      '1.05::year_2025 ::, other_tags',
    );
  });

  test('cross-page prompt transfer updates generation state immediately', () {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(pendingPromptNotifierProvider.notifier)
        .set(prompt: 'stale prompt');
    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(
          prompt: 'blue_archive, 1girl',
          negativePrompt: 'lowres',
        );

    final params = container.read(generationParamsNotifierProvider);
    expect(params.prompt, 'blue_archive, 1girl');
    expect(params.negativePrompt, 'lowres');
    expect(container.read(pendingPromptNotifierProvider).prompt, isNull);
  });

  test('recognized NAI settings can be applied independently', () {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    const info = AiTagGenerationInfo(
      software: 'NovelAI',
      model: 'NovelAI Diffusion V4.5 Curated',
      sampler: 'DPM++ 2M',
      scheduler: 'Native',
      steps: 32,
      cfgScale: 5,
      cfgRescale: 0.2,
      seed: 42,
      width: 1024,
      height: 1024,
      smea: true,
      smeaDyn: false,
      extra: {'Model ID': ImageModels.animeDiffusionV45Curated},
      prettyJson: '{}',
      rawJson: '{}',
    );
    final configuration = GenerationTransferConfiguration.tryFromAiTag(info);
    expect(configuration, isNotNull);
    expect(
      configuration!.availableSettings,
      containsAll(GenerationTransferSetting.values),
    );

    container
        .read(generationPromptTransferServiceProvider)
        .replaceMainPrompt(
          prompt: '1girl',
          configuration: configuration,
          configurationSettings: const {
            GenerationTransferSetting.model,
            GenerationTransferSetting.seed,
            GenerationTransferSetting.cfgRescale,
            GenerationTransferSetting.smea,
          },
        );

    final params = container.read(generationParamsNotifierProvider);
    expect(params.model, ImageModels.animeDiffusionV45Curated);
    expect(params.seed, 42);
    expect(params.cfgRescale, 0.2);
    expect(params.smea, isTrue);
    // Unselected source settings leave the current form untouched.
    expect(params.sampler, Samplers.kEulerAncestral);
    expect((params.width, params.height), (832, 1216));
    expect(params.steps, 28);
    expect(params.scale, 4);
    expect(params.noiseSchedule, NoiseSchedules.karras);
    expect(params.smeaDyn, isFalse);
  });

  test('non-NAI config cannot be transferred', () {
    const info = AiTagGenerationInfo(
      software: 'Stable Diffusion WebUI',
      model: 'ponyDiffusionV6XL',
      sampler: 'Euler Ancestral',
      width: 1024,
      height: 1024,
      prettyJson: '{}',
      rawJson: '{}',
    );

    expect(GenerationTransferConfiguration.tryFromAiTag(info), isNull);
  });

  test('incomplete NAI config exposes only settings with usable values', () {
    const info = AiTagGenerationInfo(
      software: 'NovelAI',
      model: 'NovelAI Diffusion V5 Full',
      width: 832,
      height: 1216,
      prettyJson: '{}',
      rawJson: '{}',
    );

    final configuration = GenerationTransferConfiguration.tryFromAiTag(info);
    expect(configuration, isNotNull);
    expect(configuration!.availableSettings, {
      GenerationTransferSetting.model,
      GenerationTransferSetting.size,
    });
  });

  test('NAI CFG transfer uses the same range as the generation form', () {
    const supported = AiTagGenerationInfo(
      software: 'NovelAI',
      cfgScale: 12,
      prettyJson: '{}',
      rawJson: '{}',
    );
    const belowMinimum = AiTagGenerationInfo(
      software: 'NovelAI',
      cfgScale: 0,
      prettyJson: '{}',
      rawJson: '{}',
    );
    const aboveMaximum = AiTagGenerationInfo(
      software: 'NovelAI',
      cfgScale: 20.1,
      prettyJson: '{}',
      rawJson: '{}',
    );

    expect(GenerationTransferConfiguration.tryFromAiTag(supported)!.scale, 12);
    expect(
      GenerationTransferConfiguration.tryFromAiTag(belowMinimum)!.scale,
      isNull,
    );
    expect(
      GenerationTransferConfiguration.tryFromAiTag(aboveMaximum)!.scale,
      isNull,
    );
  });
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();

  @override
  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  @override
  void updateNegativePrompt(String prompt) {
    state = state.copyWith(negativePrompt: prompt);
  }

  @override
  void updateModel(
    String model, {
    bool persist = true,
    bool followDefaults = true,
  }) {
    state = state.copyWith(model: model);
  }

  @override
  void updateSize(int width, int height, {bool persist = true}) {
    state = state.copyWith(width: width, height: height);
  }

  @override
  void updateSampler(String sampler) {
    state = state.copyWith(sampler: sampler);
  }

  @override
  void updateSeed(int seed) {
    state = state.copyWith(seed: seed);
  }

  @override
  void updateSteps(int steps) {
    state = state.copyWith(steps: steps);
  }

  @override
  void updateScale(double scale) {
    state = state.copyWith(scale: scale);
  }

  @override
  void updateCfgRescale(double cfgRescale) {
    state = state.copyWith(cfgRescale: cfgRescale);
  }

  @override
  void updateNoiseSchedule(String noiseSchedule) {
    state = state.copyWith(noiseSchedule: noiseSchedule);
  }

  @override
  void updateSmea(bool smea) {
    state = state.copyWith(smea: smea);
  }

  @override
  void updateSmeaDyn(bool smeaDyn) {
    state = state.copyWith(smeaDyn: smeaDyn);
  }
}

class _SettingsStorage extends LocalStorageService {
  _SettingsStorage(this.values);

  final Map<String, Object> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values[key] as T? ?? defaultValue;
}

class _FixedRandomPrompt extends PromptConfigNotifier {
  @override
  Future<RandomPromptResult> generateRandomPrompt({
    required String model,
    int? seed,
  }) async => const RandomPromptResult(
    mainPrompt: 'long hair, blue_eyes',
    characters: [
      GeneratedCharacter(
        prompt: 'long hair, blue_eyes',
        negativePrompt: 'bad hands, low_quality',
      ),
    ],
  );
}

class _TestCharacters extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();

  @override
  void replaceAll(List<CharacterPrompt> characters) {
    state = CharacterPromptConfig(characters: characters);
  }
}
