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
}
