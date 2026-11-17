import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';

void main() {
  final created = DateTime(2026);

  TagLibraryEntry entry(
    String id, {
    String name = '',
    String content = '',
    List<String> tags = const [],
  }) => TagLibraryEntry(
    id: id,
    name: name,
    content: content,
    tags: tags,
    createdAt: created,
    updatedAt: created,
  );

  List<String> ids(List<TagLibraryEntry> entries) => [
    for (final e in entries) e.id,
  ];

  group('词库条目搜索', () {
    final entries = [
      entry('spaced', content: 'Long Hair, blue eyes'),
      entry('underscored', content: '1girl, long_hair'),
      entry('named', name: 'Long_Hair 合集'),
      entry('tagged', tags: ['long hair']),
      entry('other', name: 'short', content: 'short_hair'),
    ];

    test('下划线查询命中空格写法的条目', () {
      expect(ids(entries.search('long_hair')), [
        'spaced',
        'underscored',
        'named',
        'tagged',
      ]);
    });

    test('空格查询命中下划线写法的条目', () {
      expect(ids(entries.search('LONG HAIR')), [
        'spaced',
        'underscored',
        'named',
        'tagged',
      ]);
    });

    test('空查询原样返回全部条目', () {
      expect(entries.search(''), orderedEquals(entries));
    });

    test('普通子串匹配保持不变', () {
      expect(ids(entries.search('合集')), ['named']);
      expect(ids(entries.search('blue')), ['spaced']);
    });
  });
}
