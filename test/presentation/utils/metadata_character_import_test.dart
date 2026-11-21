import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/core/network/request_builders/nai_image_request_builder.dart';
import 'package:nai_launcher/core/services/character_conversion_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams, PreciseReference;
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/l10n/app_localizations_en.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/uc_preset_provider.dart';
import 'package:nai_launcher/presentation/services/image_metadata_import_workflow.dart';
import 'package:nai_launcher/presentation/utils/metadata_import_coordinator.dart';

import '../../helpers/memory_local_storage.dart';

const _existing = CharacterPrompt(
  id: 'old-id',
  name: 'Alice',
  gender: CharacterGender.male,
  enabled: false,
  prompt: 'old portrait',
  negativePrompt: 'old negative',
  thumbnailPath: '相簿/A.png',
  positionMode: CharacterPositionMode.custom,
  customPosition: CharacterPosition(
    mode: CharacterPositionMode.custom,
    column: 0.38,
    row: 0.71,
  ),
);
const _image = NaiImageMetadata(
  prompt: 'source fixed, source base',
  negativePrompt: 'source negative',
  ucPreset: UcPresets.lightApiValue,
  fixedPrefixTags: ['source fixed'],
  vibeReferences: [
    VibeReference(displayName: 'source vibe', vibeEncoding: 'source encoding'),
  ],
  preciseReferenceImages: ['AQID'],
  preciseReferenceTypes: ['style'],
  characterPrompts: ['B', 'C', 'D'],
  characterNegativePrompts: ['neg B'],
  characterInfos: [
    CharacterPromptInfo(prompt: 'B', centerX: 0.12, centerY: 0.66),
    CharacterPromptInfo(prompt: 'C'),
    CharacterPromptInfo(prompt: 'D'),
  ],
  characterUseCoords: true,
);
final _append = MetadataImportOptions.none().copyWith(
  importCharacterPrompts: true,
  characterImportMode: CharacterImportMode.append,
);

class _Characters extends CharacterPromptRepository {
  _Characters(this.initial);
  final CharacterPromptConfig initial;
  final saves = <CharacterPromptConfig>[];
  @override
  CharacterPromptConfig load() => initial;
  @override
  Future<bool> save(CharacterPromptConfig config) async {
    saves.add(config);
    return true;
  }
}

class _Generation extends GenerationParamsNotifier {
  _Generation(this.initial);
  final ImageParams initial;
  @override
  ImageParams build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Characters repository;
  final changes = <CharacterPromptConfig>[];
  void setup({
    List<CharacterPrompt> characters = const [_existing],
    bool ai = true,
    String model = ImageModels.animeDiffusionV45Full,
  }) {
    repository = _Characters(
      CharacterPromptConfig(characters: characters, globalAiChoice: ai),
    );
    final generation = ImageParams(
      model: model,
      prompt: 'keep base',
      negativePrompt: 'keep UC',
      ucPreset: UcPresets.humanFocusApiValue,
      seed: 12,
      vibeReferencesV4: const [
        VibeReference(displayName: 'old vibe', vibeEncoding: 'old encoding'),
      ],
      preciseReferences: [
        PreciseReference(
          type: PreciseRefType.character,
          image: Uint8List.fromList([7]),
        ),
      ],
    );
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
        characterPromptRepositoryProvider.overrideWithValue(repository),
        generationParamsNotifierProvider.overrideWith(
          () => _Generation(generation),
        ),
        tagTranslationLookupProvider.overrideWith((ref) {
          final lookup = TagTranslationLookup.fromResolver(
            (_) async => const {},
          );
          ref.onDispose(lookup.dispose);
          return lookup;
        }),
      ],
    );
    addTearDown(container.dispose);
    changes.clear();
    container.listen(
      characterPromptNotifierProvider,
      (_, next) => changes.add(next),
    );
  }

  Future<MetadataImportOutcome> apply(
    NaiImageMetadata image,
    MetadataImportOptions options,
  ) => MetadataImportCoordinator.apply(
    read: container.read,
    metadata: image,
    options: options,
    l10n: AppLocalizationsEn(),
  );

  for (final mode in CharacterImportMode.values) {
    test(
      '$mode applies only the selected characters in one saved snapshot',
      () async {
        setup();
        final before = container.read(generationParamsNotifierProvider);
        final tags = container.read(fixedTagsNotifierProvider.notifier);
        final fixedEntry = await tags.addEntry(
          name: 'fixed',
          content: 'old fixed',
        );
        container
            .read(ucPresetNotifierProvider.notifier)
            .setPresetType(UcPresetType.humanFocus);
        final ucPreset = container.read(ucPresetNotifierProvider);
        final result = await apply(
          _image,
          _append.copyWith(
            characterImportMode: mode,
            selectedCharacterIndices: [2, 0],
            selectedVibeIndices: [0],
            selectedPreciseReferenceIndices: [0],
            importFixedPrefix: true,
          ),
        );
        final config = container.read(characterPromptNotifierProvider);
        final append = mode == CharacterImportMode.append;
        expect(result.appliedCount, 1);
        expect(changes, [config]);
        expect(repository.saves, [config]);
        expect(config.globalAiChoice, append);
        expect(config.characters.map((c) => c.prompt), [
          if (append) _existing.prompt,
          'B',
          'D',
        ]);
        expect(config.characters.map((c) => c.name), [
          if (append) 'Alice',
          'Character ${append ? 2 : 1}',
          'Character ${append ? 3 : 2}',
        ]);
        if (append) expect(config.characters.first, same(_existing));
        final first = config.characters[append ? 1 : 0];
        expect(first.negativePrompt, 'neg B');
        expect(first.customPosition?.column, 0.12);
        expect(first.customPosition?.row, 0.66);
        expect(config.characters.last.negativePrompt, isEmpty);
        final after = container.read(generationParamsNotifierProvider);
        expect(after.vibeReferencesV4.single.vibeEncoding, 'old encoding');
        expect(after.preciseReferences.single.image, [7]);
        expect(after.negativePrompt, 'keep UC');
        expect(after.ucPreset, UcPresets.humanFocusApiValue);
        expect(after, before);
        expect(container.read(fixedTagsNotifierProvider).entries, [fixedEntry]);
        expect(container.read(ucPresetNotifierProvider), same(ucPreset));
      },
    );
  }

  for (final mode in CharacterImportMode.values) {
    test(
      '$mode with no selected rows or with characters turned off leaves the editor alone',
      () async {
        setup(model: ImageModels.animeDiffusionV3);
        for (final options in [
          _append.copyWith(characterImportMode: mode),
          _append.copyWith(
            characterImportMode: mode,
            importCharacterPrompts: false,
            selectedCharacterIndices: [0],
          ),
        ]) {
          final result = await apply(_image, options);
          expect(result.appliedCount, 0);
          expect(result.characterConflictLimit, isNull);
        }
        expect(changes, isEmpty);
        expect(repository.saves, isEmpty);
      },
    );
  }

  test(
    'detailed character records also import without parallel legacy arrays',
    () async {
      setup();
      final result = await apply(
        const NaiImageMetadata(
          characterInfos: [CharacterPromptInfo(prompt: 'structured')],
        ),
        _append.copyWith(selectedCharacterIndices: [0]),
      );
      expect(result.appliedCount, 1);
      expect(
        container.read(characterPromptNotifierProvider).characters.last.prompt,
        'structured',
      );
    },
  );

  testWidgets(
    'confirming character rows imports the prompts shown for a mixed cache',
    (tester) async {
      setup(characters: []);
      const image = NaiImageMetadata(
        characterPrompts: ['', 'C,  D ', '  '],
        characterInfos: [
          CharacterPromptInfo(prompt: 'B'),
          CharacterPromptInfo(prompt: 'stale'),
          CharacterPromptInfo(prompt: 'E'),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(),
          ),
        ),
      );
      final workflow = ImageMetadataImportWorkflow(
        resultReporter: (_, _, _) {},
      );
      final result = workflow.run(
        context: tester.element(find.byType(Scaffold)),
        read: container.read,
        metadata: image,
        openGenerationPage: false,
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Clear',
        'Character Prompts (3)',
        'Character 1: B',
        'Character 2: C,  D ',
        'Character 3: E',
        'Confirm',
      ]) {
        final item = find.text(label);
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
        expect(item.hitTestable(), findsOneWidget);
        await tester.tap(item);
        await tester.pumpAndSettle();
      }
      expect(find.text('Confirm'), findsNothing);
      expect(await result, ImageMetadataImportResult.applied);
      final characters = container
          .read(characterPromptNotifierProvider)
          .characters;
      expect(characters.map((character) => character.prompt), [
        'B',
        'C,  D ',
        'E',
      ]);
    },
  );

  test(
    'repeated legacy imports create distinct enabled rows even with matching text',
    () async {
      setup(characters: []);
      const image = NaiImageMetadata(characterPrompts: ['same']);
      await apply(image, _append);
      await apply(image, _append);
      final rows = container.read(characterPromptNotifierProvider).characters;
      expect(rows.map((c) => c.prompt), ['same', 'same']);
      expect(rows.map((c) => c.id).toSet(), hasLength(2));
      expect(rows.every((c) => c.enabled), isTrue);
    },
  );

  test(
    'append to an empty AI layout keeps the choice and the source center',
    () async {
      setup(characters: []);
      await apply(_image, _append.copyWith(selectedCharacterIndices: [0]));
      final config = container.read(characterPromptNotifierProvider);
      expect(config.globalAiChoice, isTrue);
      expect(config.characters.single.customPosition?.column, 0.12);
      expect(config.characters.single.customPosition?.row, 0.66);
    },
  );

  test(
    'replacing a manual layout with an AI image preserves its fallback centers',
    () async {
      setup(ai: false);
      await apply(
        const NaiImageMetadata(
          characterPrompts: ['B'],
          characterUseCoords: false,
        ),
        _append.copyWith(characterImportMode: CharacterImportMode.replace),
      );
      final config = container.read(characterPromptNotifierProvider);
      expect(config.globalAiChoice, isTrue);
      expect(
        config.characters.single.customPosition,
        CharacterPositionLayout.positionForIndex(0, 1),
      );
      expect(repository.saves, [config]);
    },
  );

  for (final (model, used, selected, accepted, limit) in [
    (ImageModels.animeDiffusionV45Full, 5, 3, 1, 6),
    (ImageModels.animeDiffusionV45Full, 6, 1, 0, 6),
    (ImageModels.animeDiffusionV5Full, 21, 2, 1, 22),
    (ImageModels.animeDiffusionV5Full, 22, 1, 0, 22),
  ]) {
    test(
      '$model accepts $accepted of $selected with $used slots occupied',
      () async {
        final existing = [
          for (var i = 0; i < used; i++)
            _existing.copyWith(id: 'old-$i', enabled: i != 0),
        ];
        setup(characters: existing, model: model);
        final result = await apply(
          _image,
          _append.copyWith(
            selectedCharacterIndices: [for (var i = 0; i < selected; i++) i],
          ),
        );
        expect(result.characterAppend, (
          added: accepted,
          skipped: selected - accepted,
          limit: limit,
        ));
        expect(result.appliedCount, accepted);
        final rows = container.read(characterPromptNotifierProvider).characters;
        expect(rows.take(used), existing);
        expect(
          rows.skip(used).map((c) => c.prompt),
          _image.characterPrompts.take(accepted),
        );
        expect(changes, hasLength(accepted));
        expect(repository.saves, hasLength(accepted));
        if (accepted == 0) {
          final withSeed = await apply(
            const NaiImageMetadata(characterPrompts: ['B'], seed: 42),
            _append.copyWith(importSeed: true),
          );
          expect(withSeed.appliedCount, 1);
          expect(withSeed.characterAppend, (
            added: 0,
            skipped: 1,
            limit: limit,
          ));
          expect(container.read(generationParamsNotifierProvider).seed, 42);
          expect(repository.saves, isEmpty);
        }
      },
    );
  }

  group('switching models with eight V5 characters', () {
    const image = NaiImageMetadata(
      model: ImageModels.animeDiffusionV45Full,
      prompt: 'new base',
      seed: 42,
      characterInfos: [CharacterPromptInfo(prompt: 'B')],
    );
    final options = MetadataImportOptions.none().copyWith(
      importModel: true,
      importPrompt: true,
      importSeed: true,
      importCharacterPrompts: true,
      selectedCharacterIndices: [0],
    );
    setUp(() {
      setup(
        model: ImageModels.animeDiffusionV5Full,
        characters: [for (var i = 0; i < 8; i++) _existing.copyWith(id: '$i')],
      );
    });

    test(
      'default replacement applies the V4.5 model, seed and selected row',
      () async {
        final result = await apply(image, options);
        expect(result.characterConflictLimit, isNull);
        expect(result.appliedCount, 4);
        final params = container.read(generationParamsNotifierProvider);
        expect(params.model, image.model);
        expect(params.seed, image.seed);
        expect(params.prompt, image.prompt);
        final config = container.read(characterPromptNotifierProvider);
        expect(config.characters.single.prompt, 'B');
        expect(changes, [config]);
        expect(repository.saves, [config]);
      },
    );

    for (final (model, mode, limit) in [
      (ImageModels.animeDiffusionV45Full, CharacterImportMode.append, 6),
      (ImageModels.animeDiffusionV3, CharacterImportMode.append, 0),
      (ImageModels.animeDiffusionV3, CharacterImportMode.replace, 0),
    ]) {
      test(
        '$mode reports the $model limit before applying any field',
        () async {
          final before = container.read(generationParamsNotifierProvider);
          final result = await apply(
            image.copyWith(model: model),
            options.copyWith(characterImportMode: mode),
          );
          expect(result.characterConflictLimit, limit);
          expect(result.appliedCount, 0);
          expect(container.read(generationParamsNotifierProvider), before);
          expect(
            container.read(characterPromptNotifierProvider),
            repository.initial,
          );
          expect(changes, isEmpty);
          expect(repository.saves, isEmpty);
        },
      );
    }
  });

  test('only an importable, selected model determines capacity', () async {
    setup(
      characters: [for (var i = 0; i < 6; i++) _existing.copyWith(id: '$i')],
    );
    const upgrade = NaiImageMetadata(
      model: ImageModels.v5StagingKey,
      characterPrompts: ['B'],
    );
    expect((await apply(upgrade, _append)).characterAppend, (
      added: 0,
      skipped: 1,
      limit: 6,
    ));
    final withModel = _append.copyWith(importModel: true);
    expect(
      (await apply(
        upgrade.copyWith(model: 'unknown'),
        withModel,
      )).characterAppend,
      (added: 0, skipped: 1, limit: 6),
    );
    expect((await apply(upgrade, withModel)).characterAppend, (
      added: 1,
      skipped: 0,
      limit: 22,
    ));
    expect(
      container.read(generationParamsNotifierProvider).model,
      ImageModels.animeDiffusionV5Curated,
    );
  });

  for (final ai in [true, false]) {
    test(
      'append retains AI choice $ai and keeps both request captions aligned',
      () async {
        final active = _existing.copyWith(
          id: 'active',
          prompt: 'A',
          enabled: true,
        );
        setup(ai: ai, characters: [_existing, active]);
        final image = _image.copyWith(
          characterUseCoords: ai,
          characterPrompts: ['B', ''],
          characterInfos: [
            const CharacterPromptInfo(prompt: 'B', centerX: 0.2, centerY: 0.34),
            const CharacterPromptInfo(
              prompt: '',
              negativePrompt: 'only negative',
            ),
          ],
        );
        await apply(image, _append.copyWith(selectedCharacterIndices: [0, 1]));
        final config = container.read(characterPromptNotifierProvider);
        expect(config.globalAiChoice, ai);
        expect(config.characters.take(2), [_existing, active]);
        expect(config.characters[2].customPosition?.column, 0.2);
        expect(config.characters[2].customPosition?.row, 0.34);
        expect(
          config.characters.last.customPosition,
          ai ? null : CharacterPositionLayout.positionForIndex(2, 3),
        );
        final converted = CharacterConversionService().convert(config);
        final request = await NAIImageRequestBuilder(
          params: ImageParams(
            model: ImageModels.animeDiffusionV45Full,
            useCoords: converted.useCoords,
            characters: converted.characters,
          ),
          encodeVibe: (_, {required model, informationExtracted = 1}) async =>
              fail('Unexpected Vibe'),
        ).build(sampler: 'k_euler');
        final positive = request.requestParameters['v4_prompt'];
        final negative = request.requestParameters['v4_negative_prompt'];
        final pos = positive['caption']['char_captions'] as List;
        final neg = negative['caption']['char_captions'] as List;
        expect(positive['use_coords'], !ai);
        expect(pos.map((row) => row['char_caption']), ['A', 'B', '']);
        expect(neg.last['char_caption'], 'only negative');
        expect(
          neg.map((row) => row['centers']),
          pos.map((row) => row['centers']),
        );
        if (!ai) {
          expect(pos.map((row) => row['centers'].single), [
            {'x': 0.38, 'y': 0.71},
            {'x': 0.2, 'y': 0.34},
            {'x': 0.8, 'y': 0.5},
          ]);
        }
      },
    );
  }
}
