import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/gallery_tree_drop_slot.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  final created = DateTime(2026);

  TagLibraryEntry entry(String id, {required int order, String? category}) =>
      TagLibraryEntry(
        id: id,
        name: id,
        content: id,
        sortOrder: order,
        categoryId: category,
        createdAt: created,
        updatedAt: created,
      );

  TagLibraryCategory folder(String id, {required int order, String? parent}) =>
      TagLibraryCategory(
        id: id,
        name: id,
        parentId: parent,
        sortOrder: order,
        createdAt: created,
      );

  Future<({ProviderContainer container, _MemoryStorage storage})> seeded({
    List<TagLibraryEntry> entries = const [],
    List<TagLibraryCategory> categories = const [],
  }) async {
    final storage = _MemoryStorage();
    await storage.setTagLibraryEntriesJson(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
    await storage.setTagLibraryCategoriesJson(
      jsonEncode(categories.map((c) => c.toJson()).toList()),
    );
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    return (container: container, storage: storage);
  }

  List<String> displayed(ProviderContainer container) => [
    for (final e
        in container.read(tagLibraryPageNotifierProvider).filteredEntries)
      e.id,
  ];

  List<String> stored(_MemoryStorage storage) => [
    for (final e
        in (jsonDecode(storage.getTagLibraryEntriesJson()!) as List)
            .map((e) => TagLibraryEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList()
            .sortedByOrder())
      e.id,
  ];

  final abc = [
    entry('a', order: 0),
    entry('b', order: 1),
    entry('c', order: 2),
  ];

  group('moveEntries', () {
    test('移动后显示顺序与存储一致', () async {
      final (:container, :storage) = await seeded(entries: abc);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);

      final moved = await notifier.moveEntries(
        ['c'],
        anchor: (entryId: 'a', after: false),
      );

      expect(moved, isTrue);
      expect(displayed(container), ['c', 'a', 'b']);
      expect(stored(storage), ['c', 'a', 'b']);
    });

    test('非自定义排序时不移动', () async {
      final (:container, :storage) = await seeded(entries: abc);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier)
        ..setSortBy(TagLibrarySortBy.name);
      final writes = storage.writeCount;

      final moved = await notifier.moveEntries(
        ['c'],
        anchor: (entryId: 'a', after: false),
      );

      expect(moved, isFalse);
      expect(storage.writeCount, writes);
    });

    test('分组视图跨组放下时移入锚点所在分类', () async {
      final (:container, storage: _) = await seeded(
        entries: [
          entry('a1', order: 0, category: 'a'),
          entry('b1', order: 1, category: 'b'),
        ],
        categories: [folder('a', order: 0), folder('b', order: 1)],
      );
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);

      await notifier.moveEntries(
        ['a1'],
        anchor: (entryId: 'b1', after: true),
        groupedByCategory: true,
      );

      final entries = container.read(tagLibraryPageNotifierProvider).entries;
      expect(entries.firstWhere((e) => e.id == 'a1').categoryId, 'b');
      expect(displayed(container), ['b1', 'a1']);
    });

    test('条目已不存在时明确报错且不改动', () async {
      final (:container, :storage) = await seeded(entries: abc);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
      final writes = storage.writeCount;

      await expectLater(
        notifier.moveEntries(
          ['c', 'gone'],
          anchor: (entryId: 'a', after: false),
        ),
        throwsStateError,
      );
      expect(displayed(container), ['a', 'b', 'c']);
      expect(storage.writeCount, writes);
    });

    test('保存失败时回滚并抛出', () async {
      final (:container, :storage) = await seeded(entries: abc);
      final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
      storage.failWrites = true;

      await expectLater(
        notifier.moveEntries(['c'], anchor: (entryId: 'a', after: false)),
        throwsA(isA<StateError>()),
      );
      expect(displayed(container), ['a', 'b', 'c']);
    });
  });

  test('移动后删除条目保持自定义顺序，且不改其余条目的更新时间', () async {
    final (:container, :storage) = await seeded(entries: abc);
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    await notifier.moveEntries(['c'], anchor: (entryId: 'a', after: false));

    await notifier.deleteEntry('b');

    final entries = container.read(tagLibraryPageNotifierProvider).entries;
    expect(displayed(container), ['c', 'a']);
    expect(stored(storage), ['c', 'a']);
    expect(entries.map((e) => e.sortOrder), [0, 1]);
    expect(entries.every((e) => e.updatedAt == created), isTrue);
  });

  test('新条目排在现有最大序号之后', () async {
    final (:container, storage: _) = await seeded(
      entries: [entry('a', order: 0), entry('b', order: 5)],
    );
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);

    final added = await notifier.addEntry(name: 'c', content: 'c');

    expect(added.sortOrder, 6);
    expect(displayed(container).last, added.id);
  });

  test('拖拽排好的分类在删除其他分类后保持顺序', () async {
    final (:container, storage: _) = await seeded(
      categories: [
        folder('a', order: 0),
        folder('a-child', order: 0, parent: 'a'),
        folder('b', order: 1),
        folder('a-child-2', order: 1, parent: 'a'),
      ],
    );
    final notifier = container.read(tagLibraryPageNotifierProvider.notifier);
    List<String> roots() => [
      for (final c
          in container
              .read(tagLibraryPageNotifierProvider)
              .categories
              .where((c) => c.parentId == null)
              .toList()
              .sortedByOrder())
        c.id,
    ];

    await notifier.moveCategoryToSlot('b', 'a', GalleryTreeDropSlot.before);
    expect(roots(), ['b', 'a']);

    await notifier.deleteCategory('a-child-2');
    expect(roots(), ['b', 'a']);

    final added = await notifier.addCategory(name: 'c');
    expect(roots(), ['b', 'a', added!.id]);
  });
}

class _MemoryStorage extends MemoryLocalStorage {
  int writeCount = 0;
  bool failWrites = false;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (failWrites) throw StateError('storage unavailable');
    writeCount++;
    await super.setSetting(key, value);
  }
}
