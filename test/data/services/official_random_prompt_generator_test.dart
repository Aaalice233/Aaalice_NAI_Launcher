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

  test('legless picks skip records that bundle a blocked leg clothing tag', () {
    final entries = [
      OfficialWordlistEntry.fromRaw(
        groupId: 'fixture',
        raw: ['sukeban, delinquent, sarashi, long skirt', 10, [], [], []],
      ),
      OfficialWordlistEntry.fromRaw(
        groupId: 'fixture',
        raw: ['sailor', 1, [], [], []],
      ),
    ];

    expect(
      OfficialRandomPromptGenerator.selectCharacterRecordForTest(
        entries: entries,
        state: <String>{},
        randomValue: 0,
      ),
      'sukeban, delinquent, sarashi, long skirt',
    );
    expect(
      OfficialRandomPromptGenerator.selectCharacterRecordForTest(
        entries: entries,
        state: <String>{},
        randomValue: 0,
        blockedTags: const {'long skirt'},
      ),
      'sailor',
    );
    expect(
      OfficialRandomPromptGenerator.selectLegacyRecordForTest(
        entries: entries,
        selectedTags: const [],
        randomValue: 0,
        blockedTags: const {'long skirt'},
      ),
      'sailor',
    );
    expect(
      OfficialRandomPromptGenerator.selectLegacyRecordForTest(
        entries: entries,
        selectedTags: const [],
        randomValue: 0,
        blockedTags: const {'skirt'},
      ),
      'sukeban, delinquent, sarashi, long skirt',
      reason: 'only whole comma-separated tags are compared',
    );
  });

  group('asset flags gate Character Prompts roles', () {
    late OfficialWordlist library;
    late List<RandomPromptResult> results;
    late List<_Role> roles;

    setUpAll(() async {
      library = await service.getOfficialWordlist(WordlistType.v4);
      results = await _sampleCharacterPrompts(generator, seeds: 8000);
      roles = _rolesOf(results, library);
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
      final legless = roles.where((role) => role.isLegless).toList();

      expect(legless.length, greaterThan(40));
      expect(legless.where((role) => role.showsLegs).length, greaterThan(10));
      for (final role in legless) {
        expect(role.wears(bottoms), isFalse, reason: role.prompt);
        expect(role.wears(footwear), isFalse, reason: role.prompt);
        expect(role.wears(legwear), isFalse, reason: role.prompt);
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

    test('corrected eye-hiding records never come with an eye color', () {
      final eyeColors = _values(library, 'dN');
      final hidingEyes = roles
          .where(
            (role) => role.tags.any(
              const {'sleeping', '^_^', 'opaque glasses'}.contains,
            ),
          )
          .toList();

      expect(hidingEyes.length, greaterThan(10));
      for (final role in hidingEyes) {
        expect(role.wears(eyeColors), isFalse, reason: role.prompt);
      }
    });

    test('corrected socks are drawn only with visible feet', () {
      final socks = roles.where((role) => role.tags.contains('socks')).toList();

      expect(socks, isNotEmpty);
      for (final role in socks) {
        expect(role.framing, 'full body', reason: role.prompt);
      }
    });

    test('a scene with the corrected ocean holds no other location', () {
      // Scene types such as cityscape repeat a location without its flag.
      final locations = _valuesWhere(
        library,
        'dz',
        (entry) => entry.stringFieldValues(4).contains('location'),
      ).difference(_values(library, 'dn'));
      final oceans = results
          .map((result) => _tagsOf(result.mainPrompt))
          .where((tags) => tags.contains('ocean'))
          .toList();

      expect(oceans.length, greaterThan(5));
      for (final tags in oceans) {
        expect(tags.where(locations.contains), ['ocean'], reason: '$tags');
      }
    });
  });

  group('toenail polish follows bare feet', () {
    const footlessLegwear = {'leggings', 'leg warmers'};
    late OfficialWordlist library;
    late List<_Role> girls;
    late Set<String> footwear;
    late Set<String> legwear;

    setUpAll(() async {
      // At its asset weight the record is 1 of 496 and too rare to observe.
      final content = await _assetWithRecordWeight(
        groupId: 'dT',
        value: 'toenail polish',
        weight: 100000,
      );
      final boosted = WordlistService(assetBundle: _StringAssetBundle(content));
      library = await boosted.getOfficialWordlist(WordlistType.v4);
      final roles = _rolesOf(
        await _sampleCharacterPrompts(
          OfficialRandomPromptGenerator(boosted),
          seeds: 8000,
        ),
        library,
      );
      girls = roles.where((role) => role.gender == 'girl').toList();
      footwear = _values(library, 'dI');
      legwear = _values(library, 'dk');
    });

    bool paintsToenails(_Role role) => role.tags.contains('toenail polish');

    test('visible bare feet can show toenail polish', () {
      final barefoot = girls
          .where(
            (role) =>
                role.framing == 'full body' &&
                !role.isLegless &&
                !role.wears(footwear) &&
                !role.wears(legwear),
          )
          .toList();

      expect(barefoot.length, greaterThan(100));
      expect(
        barefoot.where(paintsToenails).length,
        greaterThan(barefoot.length ~/ 2),
      );
    });

    test('leggings and leg warmers leave the feet bare', () {
      final footless = girls
          .where(
            (role) =>
                role.framing == 'full body' &&
                role.wears(footlessLegwear) &&
                !role.wears(legwear.difference(footlessLegwear)) &&
                !role.wears(footwear),
          )
          .toList();

      expect(legwear, containsAll(footlessLegwear));
      expect(footless.length, greaterThan(20));
      expect(
        footless.where(paintsToenails).length,
        greaterThan(footless.length ~/ 2),
      );
    });

    test('footwear or feet-covering legwear hides toenail polish', () {
      final feetCovering = legwear.difference(footlessLegwear);
      final covered = girls
          .where(
            (role) =>
                role.framing == 'full body' &&
                (role.wears(footwear) || role.wears(feetCovering)),
          )
          .toList();

      expect(
        covered.where((role) => role.wears(feetCovering)).length,
        greaterThan(100),
      );
      expect(covered.where(paintsToenails), isEmpty);
    });

    test('hidden feet never show toenail polish', () {
      final hidden = girls.where((role) => role.framing != 'full body');

      expect(hidden.length, greaterThan(1000));
      expect(hidden.where(paintsToenails), isEmpty);
    });

    test('legless species never show toenail polish', () {
      final legless = girls
          .where((role) => role.framing == 'full body' && role.isLegless)
          .toList();

      expect(legless.length, greaterThan(5));
      expect(legless.where(paintsToenails), isEmpty);
    });
  });

  group('upstream filters take effect in Legacy and Furry', () {
    late OfficialWordlist legacy;
    late OfficialWordlist furry;
    late List<List<String>> legacyPrompts;
    late List<List<String>> furryPrompts;

    setUpAll(() async {
      legacy = await service.getOfficialWordlist(WordlistType.legacy);
      furry = await service.getOfficialWordlist(WordlistType.furry);
      legacyPrompts = await _soloPrompts(
        generator,
        RandomPromptProfile.legacyAnime,
        _isLegacySolo,
      );
      furryPrompts = await _soloPrompts(
        generator,
        RandomPromptProfile.furryV3,
        (tags) => tags.contains('solo'),
      );
    });

    test('Legacy legless species skip bottoms, footwear and legwear', () {
      final colors = _values(legacy, 'cg');
      final legClothing = {
        'bottoms': _values(legacy, 'l9'),
        'footwear': _values(legacy, 'ce'),
        'legwear': _values(legacy, 'l4'),
      };
      final legless = legacyPrompts
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
      final girls = legacyPrompts.where(
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

    test('Furry legless species skip bottoms, footwear and legwear', () {
      final colors = _values(furry, 'c8');
      final legClothing = {
        'bottoms': _values(furry, 'cY'),
        'footwear': _values(furry, 'cQ'),
        'legwear': _values(furry, 'cG'),
      };
      final legless = furryPrompts
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
      final legged = furryPrompts.where(
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

    test('sleeping or closed eyes remove eye colors', () {
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

const _characterLeglessSpecies = {'mermaid', 'lamia', 'centaur', 'scylla'};

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

  bool get isLegless => tags.any(_characterLeglessSpecies.contains);

  bool wears(Set<String> values) => _wears(tags, values, colors);
}

List<String> _tagsOf(String prompt) => prompt
    .split(', ')
    .map((tag) => tag.replaceAll(RegExp(r'^\{|\}$'), ''))
    .toList();

Future<List<List<String>>> _soloPrompts(
  OfficialRandomPromptGenerator generator,
  RandomPromptProfile profile,
  bool Function(List<String> tags) isSolo,
) async {
  final prompts = <List<String>>[];
  for (var seed = 0; seed < 4000; seed++) {
    final result = await generator.generate(profile: profile, seed: seed);
    final tags = _tagsOf(result.mainPrompt);
    if (isSolo(tags)) prompts.add(tags);
  }
  return prompts;
}

Future<List<RandomPromptResult>> _sampleCharacterPrompts(
  OfficialRandomPromptGenerator generator, {
  required int seeds,
}) async => [
  for (var seed = 0; seed < seeds; seed++)
    await generator.generate(
      profile: RandomPromptProfile.characterPrompts,
      seed: seed,
    ),
];

List<_Role> _rolesOf(
  List<RandomPromptResult> results,
  OfficialWordlist library,
) {
  final colors = _values(library, 'dO');
  return [
    for (final result in results)
      for (final character in result.characters)
        _Role(
          character.prompt,
          colors,
          framing: result.mainPrompt
              .split(', ')
              .where(_characterFramings.contains)
              .firstOrNull,
        ),
  ];
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

Future<String> _assetWithRecordWeight({
  required String groupId,
  required String value,
  required int weight,
}) async {
  final json =
      jsonDecode(await File(officialWordlistAssetPath).readAsString())
          as Map<String, dynamic>;
  final generator = (json['generators'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .singleWhere((generator) => generator['id'] == 'characterPrompts');
  final group = (generator['groups'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .singleWhere((group) => group['id'] == groupId);
  final record = (group['entries'] as List<dynamic>)
      .cast<List<dynamic>>()
      .singleWhere((record) => record.first == value);
  record[1] = weight;
  return jsonEncode(json);
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
