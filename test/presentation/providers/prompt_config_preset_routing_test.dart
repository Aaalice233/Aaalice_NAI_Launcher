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
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_scope.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/data/services/random_prompt_generator.dart';
import 'package:nai_launcher/data/services/sequential_state_service.dart';
import 'package:nai_launcher/data/services/tag_library_service.dart';
import 'package:nai_launcher/presentation/providers/prompt_config_provider.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PromptConfigNotifier.generateRandomPrompt preset routing', () {
    test('default preset only executes the official recipe', () async {
      final container = _container(selectedCustomPreset: false);
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Full,
            seed: 1,
          );

      expect(result.mainPrompt, isNotEmpty);
      expect(result.mainPrompt, isNot(contains(_customTag)));
      expect(result.mainPrompt, isNot(contains(_defaultCatalogTag)));
    });

    test(
      'default preset executes the official asset for every V4/V5 id',
      () async {
        final container = _container(selectedCustomPreset: false);
        addTearDown(container.dispose);

        for (final model in _v4AndV5ModelIds) {
          final result = await container
              .read(promptConfigNotifierProvider.notifier)
              .generateRandomPrompt(model: model, seed: 1);
          expect(result.mainPrompt, isNotEmpty, reason: model);
        }
      },
    );

    test('default preset rejects models without an official recipe', () async {
      final container = _container(selectedCustomPreset: false);
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
    });

    test('custom preset only uses its own wordlist', () async {
      final container = _container(selectedCustomPreset: true);
      addTearDown(container.dispose);

      final result = await container
          .read(promptConfigNotifierProvider.notifier)
          .generateRandomPrompt(
            model: ImageModels.animeDiffusionV5Full,
            seed: 1,
          );

      expect(result.noHumans, isTrue);
      expect(result.mainPrompt, contains(_customTag));
      expect(result.mainPrompt, isNot(contains(_defaultCatalogTag)));
    });

    test('custom preset is independent of the current model', () async {
      final container = _container(selectedCustomPreset: true);
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
        expect(result.mainPrompt, contains(_customTag), reason: model);
      }
    });

    test('preset load errors remain visible', () async {
      final container = _container(
        selectedCustomPreset: false,
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
    });
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

ProviderContainer _container({
  required bool selectedCustomPreset,
  String? presetError,
}) {
  final officialPreset = _preset(
    id: 'default_catalog',
    name: 'Default fixture',
    isDefault: true,
    tag: _defaultCatalogTag,
  );
  final customPreset = _preset(
    id: 'custom',
    name: 'Custom fixture',
    tag: _customTag,
  );
  return ProviderContainer(
    overrides: [
      randomPresetNotifierProvider.overrideWith(
        () => _FixedRandomPresetNotifier(
          RandomPresetState(
            presets: [officialPreset, customPreset],
            selectedPresetId: selectedCustomPreset
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
            name: 'Scene group',
            selectionMode: SelectionMode.all,
            shuffle: false,
            tags: [WeightedTag.simple(tag, 10)],
          ),
        ],
      ),
    ],
  );
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
