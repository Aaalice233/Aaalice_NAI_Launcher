import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';

void main() {
  final categories = [
    TagLibraryCategory(id: 'root', name: 'Root', createdAt: DateTime(2026)),
    TagLibraryCategory(
      id: 'child',
      name: 'Child',
      parentId: 'root',
      createdAt: DateTime(2026),
    ),
    TagLibraryCategory(id: 'other', name: 'Other', createdAt: DateTime(2026)),
  ];
  final entries = _fixture();

  test('视图模式、加载与错误变化复用同一份筛选结果', () {
    final base = TagLibraryPageState(entries: entries, categories: categories);
    final filtered = base.filteredEntries;

    final unrelatedChanges = {
      'same state': base,
      'viewMode': base.copyWith(viewMode: TagLibraryViewMode.list),
      'isLoading': base.copyWith(isLoading: true),
      'error': base.copyWith(error: 'boom'),
    };
    for (final MapEntry(key: change, value: state)
        in unrelatedChanges.entries) {
      expect(state.filteredEntries, same(filtered), reason: change);
    }
    expect(
      () => filtered.add(entries.first),
      throwsUnsupportedError,
      reason: '共享的缓存结果不能被调用方原地修改',
    );
  });

  test('筛选、排序输入或条目/分类列表变化时重新计算', () {
    final base = TagLibraryPageState(entries: entries, categories: categories);
    final filtered = base.filteredEntries;

    final inputChanges = {
      'selectedCategoryId': base.copyWith(selectedCategoryId: 'root'),
      'favorites': base.copyWith(selectedCategoryId: 'favorites'),
      'searchQuery': base.copyWith(searchQuery: 'MIXED'),
      'sortBy': base.copyWith(sortBy: TagLibrarySortBy.name),
      'entries': base.copyWith(entries: List.of(entries)),
      'categories': base.copyWith(categories: List.of(categories)),
    };
    for (final MapEntry(key: change, value: state) in inputChanges.entries) {
      expect(state.filteredEntries, isNot(same(filtered)), reason: change);
    }
  });

  test('选中父分类时包含子分类条目，收藏条目排在前面', () {
    final state = TagLibraryPageState(
      entries: entries,
      categories: categories,
      selectedCategoryId: 'root',
    );
    final filtered = state.filteredEntries;

    expect(filtered.map((entry) => entry.categoryId).toSet(), {
      'root',
      'child',
    });
    final firstNonFavorite = filtered.indexWhere((entry) => !entry.isFavorite);
    expect(
      filtered.skip(firstNonFavorite).any((entry) => entry.isFavorite),
      isFalse,
    );
  });
}

List<TagLibraryEntry> _fixture() {
  const names = ['beta', 'Alpha', 'alpha', 'Mixed Case', 'MIXED', 'zeta'];
  const categoryIds = ['root', 'child', 'other', null];
  return [
    for (var index = 0; index < 40; index++)
      TagLibraryEntry(
        id: 'tag-$index',
        name: names[index % names.length],
        content: 'content $index',
        categoryId: categoryIds[index % categoryIds.length],
        tags: index % 5 == 0 ? const ['mixed-tag'] : const [],
        sortOrder: (index * 11) % 40,
        useCount: index % 4,
        isFavorite: index % 3 == 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026, 1, 1, index % 6),
      ),
  ];
}
