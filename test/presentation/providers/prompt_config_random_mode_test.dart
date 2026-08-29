import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/datasources/local/pool_cache_service.dart';
import 'package:nai_launcher/data/datasources/local/tag_group_cache_service.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/character_count_config.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';
import 'package:nai_launcher/presentation/providers/random_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptConfigNotifier.generateRandomPrompt provider routing', () {
    test('default mode ignores the selected custom preset', () async {
      final container = _containerForMode(RandomGenerationMode.naiOfficial);
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Full,
            seed: 1,
          );

      expect(result.mode, RandomGenerationMode.naiOfficial);
      expect(result.mainPrompt, isNotEmpty);
      expect(result.mainPrompt, isNot(contains(_customTag)));
      expect(result.mainPrompt, isNot(contains(_defaultCatalogTag)));
    });

    test('default mode stays independent of catalog preset errors', () async {
      final container = _containerForMode(
        RandomGenerationMode.naiOfficial,
        presetError: 'catalog unavailable',
      );
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Curated,
            seed: 1,
          );

      expect(result.mode, RandomGenerationMode.naiOfficial);
      expect(result.mainPrompt, isNotEmpty);
    });

    test(
      'default mode executes the official asset for every V4/V5 id',
      () async {
        final container = _containerForMode(RandomGenerationMode.naiOfficial);
        addTearDown(container.dispose);

        for (final model in _v4AndV5ModelIds) {
          final result = await container
              .read(promptConfigNotifierProvider.notifier)
              .generateRandomPrompt(model: model, seed: 1);

          expect(result.mode, RandomGenerationMode.naiOfficial, reason: model);
          expect(result.mainPrompt, isNotEmpty, reason: model);
        }
      },
    );

    test(
      'each call resolves the supplied model instead of caching the previous one',
      () async {
        final container = _containerForMode(RandomGenerationMode.naiOfficial);
        addTearDown(container.dispose);
        final notifier = container.read(promptConfigNotifierProvider.notifier);

        final v4 = await notifier.generateRandomPrompt(
          model: ImageModels.animeDiffusionV4Full,
          seed: 42,
        );
        final v5 = await notifier.generateRandomPrompt(
          model: ImageModels.animeDiffusionV5Full,
          seed: 42,
        );

        expect(v4.mainPrompt, isNotEmpty);
        expect(v5.mainPrompt, v4.mainPrompt);
        expect(
          () => notifier.generateRandomPrompt(
            model: 'future-unknown-model',
            seed: 42,
          ),
          throwsA(
            isA<UnsupportedRandomPromptModelException>().having(
              (error) => error.model,
              'model',
              'future-unknown-model',
            ),
          ),
        );
      },
    );

    test('custom mode uses the selected RandomPreset', () async {
      final container = _containerForMode(RandomGenerationMode.custom);
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Full,
            seed: 1,
          );

      expect(result.mode, RandomGenerationMode.custom);
      expect(result.noHumans, isTrue);
      expect(result.mainPrompt, contains(_customTag));
      expect(result.mainPrompt, isNot(contains(_defaultCatalogTag)));
    });

    test('custom mode falls back to the default catalog preset', () async {
      final container = _containerForMode(
        RandomGenerationMode.custom,
        includeCustomPreset: false,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV4Full,
            seed: 1,
          );

      expect(result.mode, RandomGenerationMode.custom);
      expect(result.mainPrompt, contains(_defaultCatalogTag));
    });

    test('custom mode stays model-independent', () async {
      final container = _containerForMode(RandomGenerationMode.custom);
      addTearDown(container.dispose);
      final notifier = container.read(promptConfigNotifierProvider.notifier);

      for (final model in [
        ImageModels.animeDiffusionV3,
        ImageModels.animeDiffusionV5Full,
        'future-unknown-model',
      ]) {
        final result = await notifier.generateRandomPrompt(
          model: model,
          seed: 1,
        );

        expect(result.mode, RandomGenerationMode.custom, reason: model);
        expect(result.mainPrompt, contains(_customTag), reason: model);
      }
    });

    test(
      'hybrid mode combines the official source and selected catalog preset',
      () async {
        final officialContainer = _containerForMode(
          RandomGenerationMode.naiOfficial,
        );
        final hybridContainer = _containerForMode(RandomGenerationMode.hybrid);
        addTearDown(officialContainer.dispose);
        addTearDown(hybridContainer.dispose);

        final official = await officialContainer
            .read(promptConfigNotifierProvider.notifier)
            .generateRandomPrompt(
              model: ImageModels.animeDiffusionV5Full,
              seed: 1,
            );
        final result = await hybridContainer
            .read(promptConfigNotifierProvider.notifier)
            .generateRandomPrompt(
              model: ImageModels.animeDiffusionV5Full,
              seed: 1,
            );

        expect(result.mode, RandomGenerationMode.hybrid);
        expect(result.mainPrompt, startsWith(official.mainPrompt));
        expect(result.mainPrompt, contains(_customTag));
      },
    );

    test('hybrid mode falls back to the default catalog preset', () async {
      final container = _containerForMode(
        RandomGenerationMode.hybrid,
        includeCustomPreset: false,
      );
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Curated,
            seed: 1,
          );

      expect(result.mode, RandomGenerationMode.hybrid);
      expect(result.mainPrompt, isNotEmpty);
      expect(result.mainPrompt, contains(_defaultCatalogTag));
    });

    test(
      'unknown models fail explicitly in default and hybrid modes',
      () async {
        for (final mode in [
          RandomGenerationMode.naiOfficial,
          RandomGenerationMode.hybrid,
        ]) {
          final container = _containerForMode(mode);
          addTearDown(container.dispose);

          expect(
            () => container
                .read(promptConfigNotifierProvider.notifier)
                .generateRandomPrompt(model: 'future-unknown-model', seed: 1),
            throwsA(
              isA<UnsupportedRandomPromptModelException>().having(
                (error) => error.model,
                'model',
                'future-unknown-model',
              ),
            ),
          );
        }
      },
    );

    test(
      'preset load error is surfaced instead of returning an empty result',
      () async {
        final container = _containerForMode(
          RandomGenerationMode.custom,
          presetError: 'boom',
        );
        addTearDown(container.dispose);

        expect(
          () => container
              .read(promptConfigNotifierProvider.notifier)
              .generateRandomPrompt(
                model: ImageModels.animeDiffusionV5Full,
                seed: 1,
              ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('boom'),
            ),
          ),
        );
      },
    );
  });
}

const _v4AndV5ModelIds = [
  ImageModels.animeDiffusionV4Curated,
  ImageModels.animeDiffusionV4CuratedInpainting,
  ImageModels.animeDiffusionV4Full,
  ImageModels.animeDiffusionV4FullInpainting,
  ImageModels.animeDiffusionV45Curated,
  ImageModels.animeDiffusionV45CuratedInpainting,
  ImageModels.animeDiffusionV45Full,
  ImageModels.animeDiffusionV45FullInpainting,
  ImageModels.animeDiffusionV5Curated,
  ImageModels.animeDiffusionV5CuratedInpainting,
  ImageModels.animeDiffusionV5Full,
  ImageModels.animeDiffusionV5FullInpainting,
  ImageModels.v5StagingKey,
];

const _defaultCatalogTag = 'default catalog skyline fixture';
const _customTag = 'custom lantern fixture';

ProviderContainer _containerForMode(
  RandomGenerationMode mode, {
  bool includeCustomPreset = true,
  String? presetError,
}) {
  final officialPreset = _preset(
    id: 'default_catalog',
    name: 'Default catalog fixture',
    isDefault: true,
    tag: _defaultCatalogTag,
    groupName: 'Default catalog scene',
  );
  final customPreset = _preset(
    id: 'custom',
    name: 'Custom fixture',
    tag: _customTag,
    groupName: 'Custom Scene',
  );
  final presets = includeCustomPreset
      ? [officialPreset, customPreset]
      : [officialPreset];

  return ProviderContainer(
    overrides: [
      promptConfigNotifierProvider.overrideWith(_TestPromptConfigNotifier.new),
      randomModeNotifierProvider.overrideWith(
        () => _FixedRandomModeNotifier(mode),
      ),
      randomPresetNotifierProvider.overrideWith(
        () => _FixedRandomPresetNotifier(
          RandomPresetState(
            presets: presets,
            selectedPresetId: includeCustomPreset
                ? customPreset.id
                : officialPreset.id,
            error: presetError,
          ),
        ),
      ),
      randomPromptGeneratorProvider.overrideWith((ref) {
        return RandomPromptGenerator(
          _MockTagLibraryService(),
          _MockSequentialStateService(),
          _MockTagGroupCacheService(),
          _MockPoolCacheService(),
        );
      }),
    ],
  );
}

RandomPreset _preset({
  required String id,
  required String name,
  required String tag,
  required String groupName,
  bool isDefault = false,
}) {
  return RandomPreset(
    id: id,
    name: name,
    isDefault: isDefault,
    algorithmConfig: const AlgorithmConfig(
      characterCountConfig: _noHumanConfig,
      globalEmphasisProbability: 0,
    ),
    categories: [
      RandomCategory(
        id: '${id}_scene',
        name: 'Scene',
        key: 'scene',
        scope: TagScope.global,
        groupSelectionMode: SelectionMode.all,
        shuffle: false,
        groups: [
          RandomTagGroup(
            id: '${id}_scene_group',
            name: groupName,
            selectionMode: SelectionMode.all,
            shuffle: false,
            tags: [WeightedTag.simple(tag, 10)],
          ),
        ],
      ),
    ],
  );
}

class _TestPromptConfigNotifier extends PromptConfigNotifier {
  @override
  PromptConfigState build() {
    return const PromptConfigState(isLoading: false);
  }
}

class _FixedRandomModeNotifier extends RandomModeNotifier {
  _FixedRandomModeNotifier(this._mode);

  final RandomGenerationMode _mode;

  @override
  RandomGenerationMode build() => _mode;
}

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  _FixedRandomPresetNotifier(this._state);

  final RandomPresetState _state;

  @override
  RandomPresetState build() => _state;
}

class _MockTagLibraryService extends Mock implements TagLibraryService {}

class _MockSequentialStateService extends Mock
    implements SequentialStateService {
  @override
  Future<void> init() async {}
}

class _MockTagGroupCacheService extends Mock implements TagGroupCacheService {}

class _MockPoolCacheService extends Mock implements PoolCacheService {}

const _noHumanConfig = CharacterCountConfig(
  categories: [
    CharacterCountCategory(
      id: 'no_humans',
      count: 0,
      label: 'No humans',
      weight: 100,
      tagOptions: [
        CharacterTagOption(
          id: 'no_humans_scene',
          label: 'No humans',
          mainPromptTags: 'no humans',
          weight: 100,
        ),
      ],
    ),
  ],
);
