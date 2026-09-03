import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_usage_snapshot.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations_en.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/utils/metadata_import_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveTempDir;

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'metadata_import_coordinator_test_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDown(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(StorageKeys.historyBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  test(
    'applies the same prompt, character, vibe, and precise data as drop',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final preciseBytes = Uint8List.fromList([1, 2, 3, 4]);
      final metadata = NaiImageMetadata(
        prompt: '1girl, sunset',
        characterPrompts: const ['1girl, blue hair'],
        characterNegativePrompts: const ['bad hands'],
        characterInfos: const [
          CharacterPromptInfo(
            prompt: '1girl, blue hair',
            negativePrompt: 'bad hands',
            centerX: 0.24,
            centerY: 0.73,
          ),
        ],
        characterUseCoords: true,
        vibeReferences: [
          VibeReference(
            displayName: 'Imported style',
            vibeEncoding: 'encoded-style',
            thumbnail: Uint8List.fromList([9, 8, 7]),
            sourceType: VibeSourceType.naiv4vibe,
          ),
        ],
        preciseReferenceImages: [base64Encode(preciseBytes)],
        preciseReferenceTypes: const ['character&style'],
        preciseReferenceStrengths: const [0.8],
        preciseReferenceFidelities: const [0.9],
      );
      const options = MetadataImportOptions(
        importNegativePrompt: false,
        importFixedTags: false,
        importQualityTags: false,
        selectedCharacterIndices: [0],
        selectedVibeIndices: [0],
        selectedPreciseReferenceIndices: [0],
      );

      final appliedCount = await MetadataImportCoordinator.apply(
        read: container.read,
        metadata: metadata,
        options: options,
        l10n: AppLocalizationsEn(),
      );

      final params = container.read(generationParamsNotifierProvider);
      final characters = container.read(characterPromptNotifierProvider);
      expect(appliedCount, 4);
      expect(params.prompt, '1girl, sunset');
      expect(params.vibeReferencesV4, hasLength(1));
      expect(params.vibeReferencesV4.single.vibeEncoding, 'encoded-style');
      expect(params.preciseReferences, hasLength(1));
      expect(params.preciseReferences.single.image, preciseBytes);
      expect(
        params.preciseReferences.single.type,
        PreciseRefType.characterAndStyle,
      );
      expect(params.preciseReferences.single.strength, 0.8);
      expect(params.preciseReferences.single.fidelity, 0.9);
      expect(characters.characters, hasLength(1));
      expect(characters.characters.single.prompt, '1girl, blue hair');
      expect(characters.characters.single.negativePrompt, 'bad hands');
      expect(characters.globalAiChoice, isFalse);
      expect(
        characters.characters.single.customPosition?.column,
        closeTo(0.24, 0.0001),
      );
      expect(
        characters.characters.single.customPosition?.row,
        closeTo(0.73, 0.0001),
      );
    },
  );

  test(
    'official centers are retained while use_coords false restores AI mode',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const metadata = NaiImageMetadata(
        characterPrompts: ['1boy, black hair'],
        characterInfos: [
          CharacterPromptInfo(
            prompt: '1boy, black hair',
            centerX: 0.8,
            centerY: 0.2,
          ),
        ],
        characterUseCoords: false,
      );

      await MetadataImportCoordinator.apply(
        read: container.read,
        metadata: metadata,
        options: const MetadataImportOptions(
          importPrompt: false,
          importNegativePrompt: false,
          importFixedTags: false,
          importQualityTags: false,
          selectedCharacterIndices: [0],
        ),
        l10n: AppLocalizationsEn(),
      );

      final characters = container.read(characterPromptNotifierProvider);
      expect(characters.globalAiChoice, isTrue);
      expect(characters.characters.single.customPosition?.column, 0.8);
      expect(characters.characters.single.customPosition?.row, 0.2);
    },
  );

  test('reimporting the same weighted comma fixed tag stays unique', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const fragment = '{{{masterpiece, best_quality, year_2024}}}';
    const metadata = NaiImageMetadata(fixedPrefixTags: [fragment]);
    const options = MetadataImportOptions(
      importPrompt: false,
      importNegativePrompt: false,
      importFixedTags: true,
      importFixedPrefix: true,
      importFixedSuffix: false,
      importQualityTags: false,
      importCharacterPrompts: false,
      importVibeReferences: false,
      importPreciseReferences: false,
    );

    await MetadataImportCoordinator.apply(
      read: container.read,
      metadata: metadata,
      options: options,
      l10n: AppLocalizationsEn(),
    );
    await MetadataImportCoordinator.apply(
      read: container.read,
      metadata: metadata,
      options: options,
      l10n: AppLocalizationsEn(),
    );

    final fixedTags = container.read(fixedTagsNotifierProvider).entries;
    expect(fixedTags, hasLength(1));
    expect(fixedTags.single.content, fragment);
    expect(fixedTags.single.enabled, isTrue);
  });

  test('model import preserves the image guidance value', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(generationParamsNotifierProvider.notifier);
    notifier.updateModel(
      ImageModels.animeDiffusionV4Full,
      persist: false,
      followDefaults: false,
    );
    notifier.updateScale(5.5);

    const metadata = NaiImageMetadata(
      model: ImageModels.animeDiffusionV45Full,
      scale: 5.5,
    );
    const options = MetadataImportOptions(
      importPrompt: false,
      importNegativePrompt: false,
      importFixedTags: false,
      importQualityTags: false,
      importCharacterPrompts: false,
      importVibeReferences: false,
      importPreciseReferences: false,
      importScale: true,
      importModel: true,
    );

    final appliedCount = await MetadataImportCoordinator.apply(
      read: container.read,
      metadata: metadata,
      options: options,
      l10n: AppLocalizationsEn(),
    );

    final params = container.read(generationParamsNotifierProvider);
    expect(appliedCount, 2);
    expect(params.model, ImageModels.animeDiffusionV45Full);
    expect(params.scale, 5.5);
  });

  test('structured fixed tags replace the enabled scope', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(fixedTagsNotifierProvider.notifier);
    final old = await notifier.addEntry(
      name: 'current',
      content: 'current tag',
    );
    final target = await notifier.addEntry(
      name: 'recorded',
      content: 'recorded tag',
      enabled: false,
    );
    final snapshot = FixedTagUsageSnapshot(
      entries: [FixedTagUsageEntry.fromFixedTag(target, order: 0)],
    );
    final metadata = NaiImageMetadata(
      prompt: 'recorded tag, subject',
      fixedPrefixTags: const ['recorded tag'],
      fixedTagUsageData: snapshot.toJson(),
    );

    await MetadataImportCoordinator.apply(
      read: container.read,
      metadata: metadata,
      options: const MetadataImportOptions(
        importNegativePrompt: false,
        importFixedSuffix: false,
        importQualityTags: false,
        importCharacterPrompts: false,
        importVibeReferences: false,
        importPreciseReferences: false,
      ),
      l10n: AppLocalizationsEn(),
    );

    final entries = container.read(fixedTagsNotifierProvider).entries;
    expect(entries.singleWhere((entry) => entry.id == old.id).enabled, isFalse);
    expect(
      entries.singleWhere((entry) => entry.id == target.id).enabled,
      isTrue,
    );
  });

  test('fixed-tag restoration changes only the four selected scopes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(fixedTagsNotifierProvider.notifier);
    final positivePrefix = await notifier.addEntry(
      name: 'positive prefix',
      content: 'old positive prefix',
    );
    final positiveSuffix = await notifier.addEntry(
      name: 'positive suffix',
      content: 'old positive suffix',
      position: FixedTagPosition.suffix,
    );
    final negativePrefix = await notifier.addEntry(
      name: 'negative prefix',
      content: 'old negative prefix',
      promptType: FixedTagPromptType.negative,
    );
    final negativeSuffix = await notifier.addEntry(
      name: 'negative suffix',
      content: 'old negative suffix',
      position: FixedTagPosition.suffix,
      promptType: FixedTagPromptType.negative,
    );
    const snapshot = FixedTagUsageSnapshot(
      entries: [
        FixedTagUsageEntry(
          name: 'image prefix',
          content: 'image positive prefix',
          weight: 1,
          renderedContent: 'image positive prefix',
          position: FixedTagPosition.prefix,
          promptType: FixedTagPromptType.positive,
          order: 0,
        ),
      ],
    );

    await MetadataImportCoordinator.apply(
      read: container.read,
      metadata: NaiImageMetadata(
        prompt: 'image positive prefix, subject',
        fixedPrefixTags: const ['image positive prefix'],
        fixedTagUsageData: snapshot.toJson(),
      ),
      options: const MetadataImportOptions(
        importPrompt: false,
        importNegativePrompt: false,
        importFixedPrefix: true,
        importFixedSuffix: false,
        importFixedNegativePrefix: false,
        importFixedNegativeSuffix: true,
        importQualityTags: false,
        importCharacterPrompts: false,
        importVibeReferences: false,
        importPreciseReferences: false,
      ),
      l10n: AppLocalizationsEn(),
    );

    final entries = container.read(fixedTagsNotifierProvider).entries;
    bool enabled(String id) =>
        entries.singleWhere((entry) => entry.id == id).enabled;
    expect(enabled(positivePrefix.id), isFalse);
    expect(enabled(positiveSuffix.id), isTrue);
    expect(enabled(negativePrefix.id), isTrue);
    expect(enabled(negativeSuffix.id), isFalse);
    expect(
      entries
          .singleWhere((entry) => entry.content == 'image positive prefix')
          .enabled,
      isTrue,
    );
  });

  test('changed fixed tag id creates and reuses an image version', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(fixedTagsNotifierProvider.notifier);
    final current = await notifier.addEntry(name: 'A', content: 'best quality');
    final sameContentEntry = await notifier.addEntry(
      name: 'B',
      content: 'masterpiece',
      enabled: false,
    );
    final snapshot = FixedTagUsageSnapshot(
      entries: [
        FixedTagUsageEntry(
          fixedTagId: current.id,
          name: 'A',
          content: 'masterpiece',
          weight: 1,
          renderedContent: 'masterpiece',
          position: FixedTagPosition.prefix,
          promptType: FixedTagPromptType.positive,
          order: 0,
        ),
      ],
    );
    final metadata = NaiImageMetadata(
      prompt: 'masterpiece, subject',
      fixedPrefixTags: const ['masterpiece'],
      fixedTagUsageData: snapshot.toJson(),
    );
    const options = MetadataImportOptions(
      importNegativePrompt: false,
      importFixedSuffix: false,
      importQualityTags: false,
      importCharacterPrompts: false,
      importVibeReferences: false,
      importPreciseReferences: false,
    );

    for (var i = 0; i < 2; i++) {
      await MetadataImportCoordinator.apply(
        read: container.read,
        metadata: metadata,
        options: options,
        l10n: AppLocalizationsEn(),
      );
    }

    final entries = container.read(fixedTagsNotifierProvider).entries;
    expect(entries, hasLength(3));
    expect(
      entries.singleWhere((entry) => entry.id == current.id).content,
      'best quality',
    );
    final historical = entries.singleWhere(
      (entry) => entry.importedFromFixedTagId == current.id,
    );
    expect(historical.content, 'masterpiece');
    expect(historical.enabled, isTrue);
    expect(
      entries.singleWhere((entry) => entry.id == sameContentEntry.id).enabled,
      isFalse,
    );
  });

  test('unknown legacy prompt asks policy through options', () async {
    Future<bool> apply(UnknownFixedTagPolicy policy) async {
      await Hive.box(StorageKeys.settingsBox).clear();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final entry = await container
          .read(fixedTagsNotifierProvider.notifier)
          .addEntry(name: 'current', content: 'current tag');
      await MetadataImportCoordinator.apply(
        read: container.read,
        metadata: const NaiImageMetadata(prompt: 'shared subject'),
        options: MetadataImportOptions(
          importNegativePrompt: false,
          importQualityTags: false,
          importCharacterPrompts: false,
          importVibeReferences: false,
          importPreciseReferences: false,
          unknownFixedTagPolicy: policy,
        ),
        l10n: AppLocalizationsEn(),
      );
      return container
          .read(fixedTagsNotifierProvider)
          .entries
          .singleWhere((candidate) => candidate.id == entry.id)
          .enabled;
    }

    expect(await apply(UnknownFixedTagPolicy.disableCurrent), isFalse);
    expect(await apply(UnknownFixedTagPolicy.keepCurrent), isTrue);
  });
}
