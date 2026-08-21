import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_character_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  group('character limit', () {
    late ProviderContainer container;

    setUp(() async {
      await Hive.box(StorageKeys.settingsBox).clear();
      await Hive.box(StorageKeys.historyBox).clear();
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('rejects additions beyond the official V4.5 limit of six', () {
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateModel(
            ImageModels.animeDiffusionV45Full,
            persist: false,
            followDefaults: false,
          );
      notifier.clearAllCharacters();

      for (var i = 0; i < 8; i++) {
        notifier.addCharacter(CharacterGender.female);
      }

      expect(
        container.read(characterPromptNotifierProvider).characters.length,
        6,
      );
      expect(container.read(characterLimitReachedProvider), isTrue);
    });

    test('allows up to 32 characters on V5', () {
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateModel(
            ImageModels.animeDiffusionV5Curated,
            persist: false,
            followDefaults: false,
          );
      notifier.clearAllCharacters();

      for (var i = 0; i < 40; i++) {
        notifier.addCharacter(CharacterGender.female);
      }

      expect(
        container.read(characterPromptNotifierProvider).characters.length,
        32,
      );
      expect(container.read(characterLimitReachedProvider), isTrue);
    });

    test('reports the limit as reachable again after removals', () {
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateModel(
            ImageModels.animeDiffusionV45Full,
            persist: false,
            followDefaults: false,
          );
      notifier.clearAllCharacters();

      for (var i = 0; i < 6; i++) {
        notifier.addCharacter(CharacterGender.female);
      }
      expect(container.read(characterLimitReachedProvider), isTrue);

      final firstId = container
          .read(characterPromptNotifierProvider)
          .characters
          .first
          .id;
      notifier.removeCharacter(firstId);

      expect(container.read(characterLimitReachedProvider), isFalse);
      notifier.addCharacter(CharacterGender.male);
      expect(
        container.read(characterPromptNotifierProvider).characters.length,
        6,
      );
    });

    test('truncates bulk imports to the active model limit', () {
      final notifier = container.read(characterPromptNotifierProvider.notifier);
      container
          .read(generationParamsNotifierProvider.notifier)
          .updateModel(
            ImageModels.animeDiffusionV45Full,
            persist: false,
            followDefaults: false,
          );
      final imported = List<CharacterPrompt>.generate(
        8,
        (index) => CharacterPrompt(
          id: 'character-$index',
          name: 'Character $index',
          prompt: 'character $index',
        ),
      );

      notifier.replaceAll(imported);

      final stored = container.read(characterPromptNotifierProvider);
      expect(stored.characters, hasLength(6));
      expect(stored.characters.last.id, 'character-5');
    });

    test('limits V5 character state for V4.5 without mutating the source', () {
      final v5Config = CharacterPromptConfig(
        characters: List<CharacterPrompt>.generate(
          32,
          (index) => CharacterPrompt(
            id: 'character-$index',
            name: 'Character $index',
            prompt: 'character $index',
          ),
        ),
      );

      final limited = limitCharacterConfigForModel(
        v5Config,
        ImageModels.animeDiffusionV45Curated,
      );

      expect(v5Config.characters, hasLength(32));
      expect(limited.characters, hasLength(6));
      expect(limited.characters.last.id, 'character-5');
    });
  });
}
