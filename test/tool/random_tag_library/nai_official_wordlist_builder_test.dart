import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/random_tag_library/nai_official_wordlist_builder.dart';

void main() {
  test(
    'extracts every configured array in declaration order deterministically',
    () {
      final source = StringBuffer();
      var expectedEntries = 0;
      for (final generator in naiOfficialGeneratorGroups.entries) {
        for (final group in generator.value.keys) {
          final records = <List<Object?>>[
            [group, 1],
          ];
          if (generator.key == 'characterPrompts') {
            records.single.addAll([
              ['declared'],
              ['required'],
              ['excluded'],
              99,
            ]);
          }
          if (generator.key == 'legacyAnime' && group == r'l$') {
            records.add([group, 2, <String>[]]);
          }
          expectedEntries += records.length;
          source.write('$group=${jsonEncode(records)};');
        }
      }
      final bytes = utf8.encode(source.toString());

      final first = buildNaiOfficialWordlistAsset(
        sourceBytes: bytes,
        sourceFileName: 'fixture.js',
      );
      final second = buildNaiOfficialWordlistAsset(
        sourceBytes: bytes,
        sourceFileName: 'fixture.js',
      );

      expect(first.encodedBytes, second.encodedBytes);
      expect(first.outputSha256, second.outputSha256);
      expect(first.totalEntryCount, expectedEntries);
      expect(
        first.groupCounts.values.fold<int>(
          0,
          (sum, groups) => sum + groups.length,
        ),
        118,
      );
      expect(
        (first.asset['generators'] as List<dynamic>).map(
          (value) => (value as Map<String, dynamic>)['id'],
        ),
        naiOfficialGeneratorGroups.keys,
      );
    },
  );

  test('array scanner preserves nested fields, escapes, and record order', () {
    const source = r'x=[["first ] value",5,["flag"]],["second",1,[],7]];';

    expect(decodeAssignedArray(source, 'x'), [
      [
        'first ] value',
        5,
        ['flag'],
      ],
      ['second', 1, [], 7],
    ]);
  });

  test('array scanner rejects missing or unterminated assignments', () {
    expect(() => decodeAssignedArray('other=[];', 'x'), throwsFormatException);
    expect(
      () => decodeAssignedArray('x=[["value",1]', 'x'),
      throwsFormatException,
    );
  });
}
