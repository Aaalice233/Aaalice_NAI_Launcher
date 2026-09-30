import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/official_wordlist.dart';
import 'package:nai_launcher/data/services/official_random_prompt_generator.dart';
import 'package:nai_launcher/data/services/official_wordlist_errata.dart';

void main() {
  late OfficialWordlistData data;
  late OfficialWordlist asset;
  late OfficialWordlist corrected;

  setUpAll(() async {
    data = await _loadAsset();
    asset = data.generatorsById['characterPrompts']!;
    corrected = applyOfficialWordlistErrata(
      asset,
      onSkipped: (erratum) => fail('${erratum.value} was skipped'),
    );
  });

  group('the errata table', () {
    test('every erratum matches exactly one record of the locked asset', () {
      for (final erratum in officialWordlistErrata) {
        final group = data.generatorsById[erratum.generatorId]!.group(
          erratum.groupId,
        );

        expect(
          group.entries.where(erratum.matches),
          hasLength(1),
          reason: '${erratum.value}',
        );
        expect(erratum.corrected.first, erratum.value);
        expect(erratum.corrected, isNot(erratum.original));
        expect(erratum.reason, isNotEmpty);
      }
    });

    test('correcting keeps counts, order and every other record', () {
      expect(corrected.entryCount, asset.entryCount);
      expect(corrected.entryFields, asset.entryFields);
      expect(
        corrected.groups.map((group) => group.id),
        asset.groups.map((group) => group.id),
      );
      var replaced = 0;
      for (final group in asset.groups) {
        final correctedEntries = corrected.group(group.id).entries;
        expect(correctedEntries, hasLength(group.entries.length));
        for (var index = 0; index < group.entries.length; index++) {
          final erratum = officialWordlistErrata
              .where((erratum) => erratum.groupId == group.id)
              .where((erratum) => erratum.matches(group.entries[index]))
              .firstOrNull;
          if (erratum == null) {
            expect(correctedEntries[index], same(group.entries[index]));
          } else {
            expect(correctedEntries[index].raw, erratum.corrected);
            replaced++;
          }
        }
      }
      expect(replaced, officialWordlistErrata.length);
    });
  });

  group('each erratum corrects its record', () {
    test('socks is drawn once the feet are visible', () {
      final erratum = _erratum('socks');
      const state = {'female', 'feet'};

      expect(_pick(erratum.original, {...state}), isEmpty);
      expect(_pick(erratum.corrected, {...state}), 'socks');
      expect(_pick(erratum.corrected, {'female', 'legs'}), isEmpty);
    });

    test('opaque glasses no longer cover an eye color', () {
      final erratum = _erratum('opaque glasses');

      expect(_pick(erratum.original, {'eyes'}), 'opaque glasses');
      expect(_pick(erratum.corrected, {'eyes'}), isEmpty);
      expect(_pick(erratum.corrected, {}), 'opaque glasses');
    });

    test('ocean occupies the single location slot', () {
      final erratum = _erratum('ocean');
      final otherLocations = asset
          .group('dz')
          .entries
          .where((entry) => entry.stringFieldValues(2).contains('location'))
          .toList();
      final before = <String>{};
      final after = <String>{};

      expect(_pick(erratum.original, before), 'ocean');
      expect(before, isEmpty);
      expect(_pick(erratum.corrected, after), 'ocean');
      expect(after, {'location'});
      expect(otherLocations, isNotEmpty);
      expect(
        OfficialRandomPromptGenerator.selectCharacterRecordForTest(
          entries: otherLocations,
          state: after,
          randomValue: 0.5,
        ),
        isEmpty,
      );
    });

    test('sleeping behaves like closed eyes', () {
      final erratum = _erratum('sleeping');
      final state = <String>{};

      expect(_pick(erratum.original, {'eyes'}), 'sleeping');
      expect(_pick(erratum.corrected, {'eyes'}), isEmpty);
      expect(_pick(erratum.corrected, {'noeyes'}), isEmpty);
      expect(_pick(erratum.corrected, state), 'sleeping');
      expect(state, {'eyes'});
      expect(
        erratum.corrected.skip(2),
        asset
            .group('dR')
            .entries
            .firstWhere((entry) => entry.text == 'closed eyes')
            .raw
            .skip(2),
      );
    });

    test('both ^_^ records now close the eyes', () {
      final erratum = _erratum('^_^');

      expect(_pick(erratum.original, {'eyes'}), '^_^');
      expect(_pick(erratum.corrected, {'eyes'}), isEmpty);
      final carets = corrected
          .group('dR')
          .entries
          .where((entry) => entry.text == '^_^')
          .map((entry) => entry.raw)
          .toList();
      expect(carets, hasLength(2));
      expect(carets.first, carets.last);
    });
  });

  group('changed assets', () {
    test('an erratum whose record changed is skipped and reported', () {
      final changed = OfficialWordlist(
        id: 'characterPrompts',
        entryFields: asset.entryFields,
        groups: [
          _group('dk', [
            [
              'socks',
              12,
              [],
              ['feet'],
              [],
            ],
            [
              'loose socks',
              12,
              [],
              ['feet'],
              [],
            ],
          ]),
          _group('dE', [
            ['sleeping', 12, [], [], []],
          ]),
          _group('dR', [
            ['^_^', 5, [], [], []],
          ]),
        ],
        declaredEntryCount: 4,
      );
      final skipped = <OfficialWordlistErratum>[];

      final result = applyOfficialWordlistErrata(
        changed,
        onSkipped: skipped.add,
      );

      expect(skipped.map((erratum) => erratum.value), [
        'socks',
        'opaque glasses',
        'ocean',
        '^_^',
      ]);
      expect(result.group('dk').entries.first.raw, [
        'socks',
        12,
        [],
        ['feet'],
        [],
      ]);
      expect(result.group('dR').entries.single.raw, ['^_^', 5, [], [], []]);
      expect(
        result.group('dE').entries.single.raw,
        _erratum('sleeping').corrected,
      );
    });

    test('a wordlist without matching records is returned as is', () {
      final skipped = <OfficialWordlistErratum>[];
      final unrelated = OfficialWordlist(
        id: 'characterPrompts',
        entryFields: asset.entryFields,
        groups: [
          _group('dk', [
            [
              'socks',
              12,
              [],
              ['feet'],
              [],
            ],
          ]),
        ],
        declaredEntryCount: 1,
      );

      expect(
        applyOfficialWordlistErrata(unrelated, onSkipped: skipped.add),
        same(unrelated),
      );
      expect(skipped, hasLength(officialWordlistErrata.length));

      for (final id in ['legacyAnime', 'furryV3']) {
        final wordlist = data.generatorsById[id]!;
        expect(
          applyOfficialWordlistErrata(
            wordlist,
            onSkipped: (erratum) => fail('${erratum.value} is not for $id'),
          ),
          same(wordlist),
        );
      }
    });

    test('each loaded wordlist is corrected once', () async {
      final first = correctedOfficialWordlist(asset);
      final reloaded = (await _loadAsset()).generatorsById['characterPrompts']!;

      expect(correctedOfficialWordlist(asset), same(first));
      expect(first, isNot(same(asset)));
      expect(correctedOfficialWordlist(reloaded), isNot(same(first)));
    });
  });
}

Future<OfficialWordlistData> _loadAsset() async =>
    OfficialWordlistData.fromJson(
      jsonDecode(await File(officialWordlistAssetPath).readAsString())
          as Map<String, dynamic>,
    );

OfficialWordlistErratum _erratum(String value) =>
    officialWordlistErrata.singleWhere((erratum) => erratum.value == value);

OfficialWordlistGroup _group(String id, List<List<Object?>> records) =>
    OfficialWordlistGroup(
      id: id,
      semantic: id,
      entries: [
        for (final raw in records)
          OfficialWordlistEntry.fromRaw(groupId: id, raw: raw),
      ],
    );

String _pick(List<Object?> raw, Set<String> state) =>
    OfficialRandomPromptGenerator.selectCharacterRecordForTest(
      entries: [OfficialWordlistEntry.fromRaw(groupId: 'fixture', raw: raw)],
      state: state,
      randomValue: 0,
    );
