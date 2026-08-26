import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';
import 'package:nai_launcher/data/models/prompt/official_wordlist.dart';
import 'package:nai_launcher/data/models/prompt/random_prompt_result.dart';
import 'package:nai_launcher/data/services/official_random_prompt_generator.dart';
import 'package:nai_launcher/data/services/wordlist_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfficialRandomPromptGenerator generator;

  setUpAll(() async {
    final content = await File(officialWordlistAssetPath).readAsString();
    final service = WordlistService(assetBundle: _StringAssetBundle(content));
    generator = OfficialRandomPromptGenerator(service);
  });

  test('fixed seeds reproduce all three official recipes', () async {
    for (final profile in RandomPromptProfile.values) {
      final first = await generator.generate(profile: profile, seed: 1729);
      final second = await generator.generate(profile: profile, seed: 1729);

      expect(second, first, reason: '$profile must be seed-reproducible');
      expect(first.mainPrompt, isNotEmpty);
      expect(first.seed, 1729);
    }
  });

  test(
    'Character Prompts keeps role prompts independent from the main prompt',
    () async {
      final result = await _firstCharacterResult(generator);

      expect(result.characters, isNotEmpty);
      for (final character in result.characters) {
        expect(character.prompt, isNotEmpty);
        expect(
          character.prompt.split(', ').first,
          anyOf('girl', 'boy', 'other'),
        );
        expect(result.mainPrompt, isNot(contains(character.prompt)));
        expect(character.centerX, 0.5);
        expect(character.centerY, 0.5);
      }
    },
  );

  test(
    'legacy dependency filtering and upstream ticket bounds are preserved',
    () {
      final entries = [
        OfficialWordlistEntry.fromRaw(
          groupId: 'fixture',
          raw: [
            'dependent',
            2,
            ['anchor'],
          ],
        ),
        OfficialWordlistEntry.fromRaw(groupId: 'fixture', raw: ['fallback', 1]),
      ];

      expect(
        OfficialRandomPromptGenerator.selectLegacyRecordForTest(
          entries: entries,
          selectedTags: const [],
          randomValue: 0,
        ),
        'fallback',
      );
      expect(
        OfficialRandomPromptGenerator.selectLegacyRecordForTest(
          entries: entries,
          selectedTags: const ['anchor'],
          randomValue: 0.999999,
        ),
        'dependent',
        reason:
            'the official totalWeight - 1 bound makes the last ticket unreachable',
      );
    },
  );

  test(
    'Character Prompts uses fields 3 and 4 and ignores declared field 2',
    () {
      final entries = [
        OfficialWordlistEntry.fromRaw(
          groupId: 'fixture',
          raw: [
            'conditional',
            10,
            ['declared-but-ignored'],
            ['required'],
            ['excluded'],
            37,
          ],
        ),
        OfficialWordlistEntry.fromRaw(groupId: 'fixture', raw: ['fallback', 1]),
      ];

      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: entries,
          state: <String>{},
          randomValue: 0,
        ),
        'fallback',
      );

      final allowedState = <String>{'required'};
      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: entries,
          state: allowedState,
          randomValue: 0,
        ),
        'conditional',
      );
      expect(allowedState, contains('required'));
      expect(allowedState, isNot(contains('declared-but-ignored')));

      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: entries,
          state: {'required', 'excluded'},
          randomValue: 0,
        ),
        'fallback',
      );
    },
  );
}

Future<RandomPromptResult> _firstCharacterResult(
  OfficialRandomPromptGenerator generator,
) async {
  for (var seed = 0; seed < 200; seed++) {
    final result = await generator.generate(
      profile: RandomPromptProfile.characterPrompts,
      seed: seed,
    );
    if (result.characters.isNotEmpty) return result;
  }
  fail('Character Prompts produced no character in 200 deterministic seeds');
}

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.content);

  final String content;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    return ByteData.sublistView(bytes);
  }
}
