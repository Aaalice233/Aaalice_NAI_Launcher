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

  late WordlistService service;
  late OfficialRandomPromptGenerator generator;

  setUpAll(() async {
    final content = await File(officialWordlistAssetPath).readAsString();
    service = WordlistService(assetBundle: _StringAssetBundle(content));
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

  // Upstream re-adds field 3 on a pick, so declared flags never took effect.
  test(
    'Character Prompts gates on fields 3 and 4 and records declared field 2',
    () {
      final entries = [
        OfficialWordlistEntry.fromRaw(
          groupId: 'fixture',
          raw: [
            'conditional',
            10,
            ['declared'],
            ['required'],
            ['excluded'],
            37,
          ],
        ),
        OfficialWordlistEntry.fromRaw(groupId: 'fixture', raw: ['fallback', 1]),
      ];

      final emptyState = <String>{};
      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: entries,
          state: emptyState,
          randomValue: 0,
        ),
        'fallback',
      );
      expect(emptyState, isEmpty);

      final allowedState = <String>{'required'};
      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: entries,
          state: allowedState,
          randomValue: 0,
        ),
        'conditional',
      );
      expect(allowedState, {'required', 'declared'});

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

  group('asset flags gate Character Prompts roles', () {
    late OfficialWordlist library;
    late List<_Role> roles;

    setUpAll(() async {
      library = await service.getOfficialWordlist(WordlistType.v4);
      roles = await _sampleRoles(generator, library, seeds: 8000);
    });

    test('a role starts from the shared state plus its own gender flag', () {
      final shared = {'legs', 'feet'};

      expect(
        OfficialRandomPromptGenerator.characterStateForTest(
          globalState: shared,
          gender: 'f',
        ),
        {'legs', 'feet', 'female'},
      );
      expect(
        OfficialRandomPromptGenerator.characterStateForTest(
          globalState: shared,
          gender: 'm',
        ),
        {'legs', 'feet', 'male'},
      );
      expect(
        OfficialRandomPromptGenerator.characterStateForTest(
          globalState: shared,
          gender: 'o',
        ),
        {'legs', 'feet'},
      );
      expect(shared, {'legs', 'feet'});
    });

    test(
      'roles without a gender flag never draw gender-restricted entries',
      () {
        final state = OfficialRandomPromptGenerator.characterStateForTest(
          globalState: const {'legs', 'feet', 'body'},
          gender: 'o',
        );
        for (final groupId in ['dv', 'dD', 'dA', 'dc']) {
          final restricted = _valuesWhere(
            library,
            groupId,
            (entry) => entry
                .stringFieldValues(3)
                .any(const {'female', 'male'}.contains),
          );
          for (var step = 0; step < 200; step++) {
            final picked =
                OfficialRandomPromptGenerator.selectCharacterRecordForTest(
                  entries: library.group(groupId).entries,
                  state: {...state},
                  randomValue: step / 200,
                );
            expect(restricted, isNot(contains(picked)), reason: groupId);
          }
        }
      },
    );

    test('female roles draw dresses, swimsuits and skirts', () {
      final girls = roles.where((role) => role.gender == 'girl').toList();
      Set<String> femaleOnly(String groupId) => _valuesWhere(
        library,
        groupId,
        (entry) => entry.stringFieldValues(3).contains('female'),
      );
      final dresses = femaleOnly('dv');
      final swimsuits = femaleOnly('dD');
      final skirts = femaleOnly('dA').where((v) => v.contains('skirt')).toSet();

      expect(
        girls.where((role) => role.wears(dresses)).length,
        greaterThan(50),
      );
      expect(
        girls.where((role) => role.wears(swimsuits)).length,
        greaterThan(50),
      );
      expect(girls.where((role) => role.wears(skirts)).length, greaterThan(50));
    });

    test('male roles draw entries that require male', () {
      final maleOnly = {
        for (final groupId in ['dc', 'd_', 'dM', 'dD', 'dT'])
          ..._valuesWhere(
            library,
            groupId,
            (entry) => entry.stringFieldValues(3).contains('male'),
          ),
      };
      final boys = roles.where((role) => role.gender == 'boy');

      expect(
        boys.where((role) => role.wears(maleOnly)).length,
        greaterThan(50),
      );
    });

    test('legless roles skip bottoms, footwear and legwear', () {
      final legwear = _values(library, 'dk');
      final footwear = _values(library, 'dI');
      final bottoms = _values(library, 'dA');
      // Uniform records bundle a whole outfit, e.g. "sukeban, ..., long skirt";
      // only the dedicated clothing picks are gated by legs.
      final outfits = _values(
        library,
        'dM',
      ).where((outfit) => outfit.contains(', ')).toList();
      final legless = roles
          .where(
            (role) => role.tags.any(
              const {'mermaid', 'lamia', 'centaur', 'scylla'}.contains,
            ),
          )
          .toList();

      expect(legless.length, greaterThan(40));
      expect(legless.where((role) => role.showsLegs).length, greaterThan(10));
      for (final role in legless) {
        final picks = role.withoutOutfits(outfits);
        expect(picks.wears(bottoms), isFalse, reason: role.prompt);
        expect(picks.wears(footwear), isFalse, reason: role.prompt);
        expect(picks.wears(legwear), isFalse, reason: role.prompt);
      }

      final legged = roles.where(
        (role) => role.framing == 'full body' && !legless.contains(role),
      );
      expect(legged.where((role) => role.wears(bottoms)), isNotEmpty);
      expect(legged.where((role) => role.wears(footwear)), isNotEmpty);
      expect(legged.where((role) => role.wears(legwear)), isNotEmpty);
    });

    test('closed eyes never come with an eye color', () {
      final eyeColors = _values(library, 'dN');
      final closedEyes = roles
          .where((role) => role.tags.contains('closed eyes'))
          .toList();

      expect(closedEyes.length, greaterThan(10));
      for (final role in closedEyes) {
        expect(role.wears(eyeColors), isFalse, reason: role.prompt);
      }
    });
  });

  group('upstream filters take effect in Legacy and Furry', () {
    late OfficialWordlist legacy;
    late OfficialWordlist furry;

    setUpAll(() async {
      legacy = await service.getOfficialWordlist(WordlistType.legacy);
      furry = await service.getOfficialWordlist(WordlistType.furry);
    });

    Future<List<List<String>>> soloPrompts(
      RandomPromptProfile profile,
      bool Function(List<String> tags) isSolo,
    ) async {
      final prompts = <List<String>>[];
      for (var seed = 0; seed < 4000; seed++) {
        final result = await generator.generate(profile: profile, seed: seed);
        final tags = result.mainPrompt
            .split(', ')
            .map((tag) => tag.replaceAll(RegExp(r'^\{|\}$'), ''))
            .toList();
        if (isSolo(tags)) prompts.add(tags);
      }
      return prompts;
    }

    test('Legacy legless species skip bottoms, footwear and legwear', () async {
      final prompts = await soloPrompts(
        RandomPromptProfile.legacyAnime,
        _isLegacySolo,
      );
      final colors = _values(legacy, 'cg');
      final legClothing = {
        'bottoms': _values(legacy, 'l9'),
        'footwear': _values(legacy, 'ce'),
        'legwear': _values(legacy, 'l4'),
      };
      final legless = prompts
          .where(
            (tags) => tags.any(const {'mermaid', 'lamia', 'centaur'}.contains),
          )
          .toList();

      expect(legless.length, greaterThan(10));
      for (final tags in legless) {
        for (final entry in legClothing.entries) {
          expect(
            _wears(tags, entry.value, colors),
            isFalse,
            reason: '${entry.key}: $tags',
          );
        }
        expect(tags.where((tag) => tag.contains('legwear')), isEmpty);
      }
      final girls = prompts.where(
        (tags) => tags.contains('1girl') && !legless.contains(tags),
      );
      for (final entry in legClothing.entries) {
        expect(
          girls.where((tags) => _wears(tags, entry.value, colors)),
          isNotEmpty,
          reason: entry.key,
        );
      }
    });

    test('Furry legless species skip bottoms, footwear and legwear', () async {
      final prompts = await soloPrompts(
        RandomPromptProfile.furryV3,
        (tags) => tags.contains('solo'),
      );
      final colors = _values(furry, 'c8');
      final legClothing = {
        'bottoms': _values(furry, 'cY'),
        'footwear': _values(furry, 'cQ'),
        'legwear': _values(furry, 'cG'),
      };
      final legless = prompts
          .where((tags) => tags.any(_furryLeglessSpecies.contains))
          .toList();

      expect(legless.length, greaterThan(100));
      for (final tags in legless) {
        for (final entry in legClothing.entries) {
          expect(
            _wears(tags, entry.value, colors),
            isFalse,
            reason: '${entry.key}: $tags',
          );
        }
        expect(
          tags.where((tag) => tag.contains('legwear') || tag.contains('legs')),
          isEmpty,
        );
      }
      final legged = prompts.where(
        (tags) =>
            tags.contains('full-length portrait') && !legless.contains(tags),
      );
      for (final entry in legClothing.entries) {
        expect(
          legged.where((tags) => _wears(tags, entry.value, colors)),
          isNotEmpty,
          reason: entry.key,
        );
      }
    });

    test('sleeping or closed eyes remove eye colors', () async {
      final legacyPrompts = await soloPrompts(
        RandomPromptProfile.legacyAnime,
        _isLegacySolo,
      );
      final legacyEyes = _values(legacy, 'ch');
      final legacySleepy = legacyPrompts.where(
        (tags) => tags.any(
          (tag) => const ['sleeping', 'zzz', 'closed eyes'].any(tag.contains),
        ),
      );
      expect(legacySleepy.length, greaterThan(20));
      for (final tags in legacySleepy) {
        expect(tags.where(legacyEyes.contains), isEmpty, reason: '$tags');
      }

      final furryPrompts = await soloPrompts(
        RandomPromptProfile.furryV3,
        (tags) => tags.contains('solo'),
      );
      final furryEyes = {
        ..._values(furry, 'cP'),
        ..._values(furry, 'cz'),
        ..._values(furry, 'cq'),
      };
      final furrySleepy = furryPrompts.where(
        (tags) => tags.any(
          (tag) => const ['sleeping', 'zzz', 'eyes closed'].any(tag.contains),
        ),
      );
      expect(furrySleepy.length, greaterThan(20));
      for (final tags in furrySleepy) {
        expect(tags.where(furryEyes.contains), isEmpty, reason: '$tags');
      }
    });
  });
}

const _furryLeglessSpecies = {
  'taur',
  'serpentine',
  'naga',
  'centaur',
  'feral',
  'merfolk',
  'lamia',
};

const _characterFramings = {
  'portrait',
  'upper body',
  'cowboy shot',
  'full body',
};

bool _isLegacySolo(List<String> tags) {
  final counts = tags.where(
    (tag) => RegExp(r'^\d+(girl|boy|other)s?$').hasMatch(tag),
  );
  return counts.length == 1 && counts.single.startsWith('1');
}

Set<String> _values(OfficialWordlist library, String groupId) =>
    _valuesWhere(library, groupId, (_) => true);

Set<String> _valuesWhere(
  OfficialWordlist library,
  String groupId,
  bool Function(OfficialWordlistEntry entry) test,
) => library.group(groupId).entries.where(test).map((e) => e.text).toSet();

bool _wears(List<String> tags, Set<String> values, Set<String> colors) =>
    tags.any(
      (tag) =>
          values.contains(tag) ||
          colors.any(
            (color) =>
                tag.startsWith('$color ') &&
                values.contains(tag.substring(color.length + 1)),
          ),
    );

class _Role {
  _Role(this.prompt, this.colors, {required this.framing})
    : tags = prompt.split(', ');

  final String prompt;
  final List<String> tags;
  final Set<String> colors;
  final String? framing;

  String get gender => tags.first;

  bool get showsLegs => framing == 'cowboy shot' || framing == 'full body';

  bool wears(Set<String> values) => _wears(tags, values, colors);

  _Role withoutOutfits(Iterable<String> outfits) => _Role(
    outfits.fold(prompt, (text, outfit) => text.replaceAll(outfit, '')),
    colors,
    framing: framing,
  );
}

Future<List<_Role>> _sampleRoles(
  OfficialRandomPromptGenerator generator,
  OfficialWordlist library, {
  required int seeds,
}) async {
  final colors = _values(library, 'dO');
  final roles = <_Role>[];
  for (var seed = 0; seed < seeds; seed++) {
    final result = await generator.generate(
      profile: RandomPromptProfile.characterPrompts,
      seed: seed,
    );
    final framing = result.mainPrompt
        .split(', ')
        .where(_characterFramings.contains)
        .firstOrNull;
    for (final character in result.characters) {
      roles.add(_Role(character.prompt, colors, framing: framing));
    }
  }
  return roles;
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
