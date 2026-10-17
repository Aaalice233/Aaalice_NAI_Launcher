import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry_order.dart';

void main() {
  final created = DateTime(2026, 1, 1);
  final moved = DateTime(2026, 10, 17);

  TagLibraryEntry entry(
    String id, {
    int order = 0,
    bool favorite = false,
    String? category,
    DateTime? createdAt,
  }) => TagLibraryEntry(
    id: id,
    name: id,
    content: id,
    sortOrder: order,
    isFavorite: favorite,
    categoryId: category,
    createdAt: createdAt ?? created,
    updatedAt: created,
  );

  List<String> ids(List<TagLibraryEntry> entries) => [
    for (final e in entries.sortedByOrder()) e.id,
  ];

  List<TagLibraryEntry>? move(
    List<TagLibraryEntry> entries, {
    List<String>? visible,
    required List<String> moving,
    required String anchor,
    bool after = false,
    TagLibraryEntryCategoryTarget? category,
  }) => moveTagLibraryEntries(
    entries,
    visibleIds:
        visible ??
        [for (final e in entries.sortedByOrder().favoritesFirst()) e.id],
    movedIds: moving,
    anchor: (entryId: anchor, after: after),
    category: category,
    now: () => moved,
  );

  final abcd = [
    entry('a', order: 0),
    entry('b', order: 1),
    entry('c', order: 2),
    entry('d', order: 3),
  ];

  group('单个条目', () {
    test('插到锚点之前与之后，序号重新连续编号', () {
      final before = move(abcd, moving: ['d'], anchor: 'b')!;
      expect(ids(before), ['a', 'd', 'b', 'c']);
      expect(before.map((e) => e.sortOrder), [0, 1, 2, 3]);

      final after = move(abcd, moving: ['a'], anchor: 'c', after: true)!;
      expect(ids(after), ['b', 'c', 'a', 'd']);
    });

    test('放回原位或放到自身上视为没有变化', () {
      expect(move(abcd, moving: ['b'], anchor: 'c'), isNull);
      expect(move(abcd, moving: ['b'], anchor: 'a', after: true), isNull);
      expect(move(abcd, moving: ['b'], anchor: 'b'), isNull);
    });

    test('锚点不在显示序列中时不移动', () {
      expect(
        move(abcd, visible: ['a', 'b'], moving: ['a'], anchor: 'd'),
        isNull,
      );
    });

    test('只调整顺序时不改更新时间，未移动的条目保持同一实例', () {
      final result = move(abcd, moving: ['d'], anchor: 'c')!;
      expect(result.every((e) => e.updatedAt == created), isTrue);
      expect(result.firstWhere((e) => e.id == 'a'), same(abcd.first));
    });
  });

  test('筛选视图里移动，只有被移动的条目改变相对位置', () {
    final entries = [
      entry('a', order: 0),
      entry('x', order: 1),
      entry('b', order: 2),
      entry('y', order: 3),
      entry('c', order: 4),
    ];
    final result = move(
      entries,
      visible: ['a', 'b', 'c'],
      moving: ['c'],
      anchor: 'a',
    )!;
    expect(ids(result), ['c', 'a', 'x', 'b', 'y']);
  });

  test('多个条目按给定次序整块移动，重复的 id 只算一次', () {
    final result = move(abcd, moving: ['d', 'a', 'd'], anchor: 'c')!;
    expect(ids(result), ['b', 'd', 'a', 'c']);
  });

  group('收藏分组', () {
    final entries = [
      entry('f1', order: 0, favorite: true),
      entry('f2', order: 1, favorite: true),
      entry('n1', order: 2),
      entry('n2', order: 3),
    ];

    test('非收藏拖到收藏之间时落在非收藏组的开头', () {
      final result = move(entries, moving: ['n2'], anchor: 'f1')!;
      expect(ids(result), ['f1', 'f2', 'n2', 'n1']);
    });

    test('收藏拖到非收藏之间时落在收藏组的末尾', () {
      final result = move(entries, moving: ['f1'], anchor: 'n2', after: true)!;
      expect(ids(result), ['f2', 'f1', 'n1', 'n2']);
    });

    test('收藏顺序原本不在最前时以显示顺序为准', () {
      final mixed = [
        entry('n1', order: 0),
        entry('f1', order: 1, favorite: true),
        entry('n2', order: 2),
      ];
      final result = move(mixed, moving: ['n2'], anchor: 'n1')!;
      expect(ids(result).toList(), ['f1', 'n2', 'n1']);
    });
  });

  group('分组视图跨组', () {
    final entries = [
      entry('a1', order: 0, category: 'a'),
      entry('a2', order: 1, category: 'a'),
      entry('b1', order: 2, category: 'b'),
      entry('b2', order: 3, category: 'b'),
    ];

    test('移入锚点所在分类并插到该位置，只刷新被移动条目的更新时间', () {
      final result = move(
        entries,
        visible: ['b1', 'b2'],
        moving: ['a1'],
        anchor: 'b2',
        category: (id: 'b'),
      )!;
      final byId = {for (final e in result) e.id: e};
      expect(ids(result), ['a2', 'b1', 'a1', 'b2']);
      expect(byId['a1']!.categoryId, 'b');
      expect(byId['a1']!.updatedAt, moved);
      expect(byId['b1']!.updatedAt, created);
    });

    test('移入未分类', () {
      final result = move(
        [...entries, entry('u1', order: 4)],
        visible: ['u1'],
        moving: ['b2'],
        anchor: 'u1',
        category: (id: null),
      )!;
      expect(result.firstWhere((e) => e.id == 'b2').categoryId, isNull);
    });

    test('位置不变但分类变化仍然算作移动', () {
      final result = move(
        entries,
        visible: ['b1', 'b2'],
        moving: ['a2'],
        anchor: 'b1',
        category: (id: 'b'),
      );
      expect(result, isNotNull);
      expect(result!.firstWhere((e) => e.id == 'a2').categoryId, 'b');
    });
  });

  test('旧数据序号重复时按创建时间与 id 确定次序，移动后归一化', () {
    final legacy = [
      entry('c', createdAt: DateTime(2026, 3)),
      entry('a', createdAt: DateTime(2026, 1)),
      entry('b', createdAt: DateTime(2026, 1)),
    ];
    expect(ids(legacy), ['a', 'b', 'c']);
    final result = move(legacy, moving: ['c'], anchor: 'b')!;
    expect(ids(result), ['a', 'c', 'b']);
    expect(result.map((e) => e.sortOrder), [0, 1, 2]);
  });
}
