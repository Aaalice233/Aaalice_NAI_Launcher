import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';

void main() {
  final created = DateTime(2026);

  TagLibraryEntry entry(
    String id, {
    int order = 0,
    int useCount = 0,
    bool favorite = false,
    String? name,
  }) => TagLibraryEntry(
    id: id,
    name: name ?? id,
    content: id,
    sortOrder: order,
    useCount: useCount,
    isFavorite: favorite,
    createdAt: created,
    updatedAt: created,
  );

  TagLibraryCategory category(String id, {int order = 0, String? parent}) =>
      TagLibraryCategory(
        id: id,
        name: id,
        parentId: parent,
        sortOrder: order,
        createdAt: created,
      );

  group('词库条目列表', () {
    test('其他排序方式的并列项回退到自定义顺序', () {
      final entries = [
        entry('c', order: 2),
        entry('a', order: 0),
        entry('b', order: 1, useCount: 5),
      ];
      expect(entries.sortedByUseCount().map((e) => e.id), ['b', 'a', 'c']);
      expect(entries.sortedByUpdatedAt().map((e) => e.id), ['a', 'b', 'c']);

      final sameName = [
        entry('2', order: 1, name: 'Cat'),
        entry('1', order: 0, name: 'cat'),
      ];
      expect(sameName.sortedByName().map((e) => e.id), ['1', '2']);
    });

    test('收藏在前且各组保持原有次序', () {
      final entries = [
        entry('n1'),
        entry('f1', favorite: true),
        entry('n2'),
        entry('f2', favorite: true),
      ];
      expect(entries.favoritesFirst().map((e) => e.id), [
        'f1',
        'f2',
        'n1',
        'n2',
      ]);
    });

    test('重新编号不改更新时间，序号未变的条目保持同一实例', () {
      final entries = [entry('a'), entry('b', order: 5)];
      final reindexed = entries.reindex();
      expect(reindexed.map((e) => e.sortOrder), [0, 1]);
      expect(reindexed.first, same(entries.first));
      expect(reindexed.last.updatedAt, created);
    });

    test('新条目排在现有最大序号之后', () {
      expect(<TagLibraryEntry>[].nextSortOrder, 0);
      expect([entry('a', order: 7), entry('b', order: 2)].nextSortOrder, 8);
    });
  });

  group('词库分类列表', () {
    test('序号相同按 id 排列，与侧栏树一致', () {
      final categories = [
        category('b'),
        category('a'),
        category('c', order: -1),
      ];
      expect(categories.sortedByOrder().map((c) => c.id), ['c', 'a', 'b']);
    });

    test('新分类排在同级现有分类之后，不受其他层级与空洞影响', () {
      final categories = [
        category('root-a', order: 0),
        category('root-b', order: 4),
        category('child', order: 9, parent: 'root-a'),
      ];
      expect(categories.nextSortOrderUnder(null), 5);
      expect(categories.nextSortOrderUnder('root-a'), 10);
      expect(categories.nextSortOrderUnder('root-b'), 0);
      expect(categories.nextSortOrder, 10);
    });
  });
}
