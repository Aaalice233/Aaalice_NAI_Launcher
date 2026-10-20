import 'tag_library_category.dart';
import 'tag_library_entry.dart';

/// 分组视图中的一组条目，[category] 为 null 表示未分类
typedef TagLibraryEntryGroup = ({
  TagLibraryCategory? category,
  List<TagLibraryEntry> entries,
});

extension TagLibraryEntryGrouping on List<TagLibraryEntry> {
  /// 按分类顺序分组，未分类排在最后；组内保持原有次序，没有条目的分类不成组
  List<TagLibraryEntryGroup> groupedByCategory(
    List<TagLibraryCategory> categories,
  ) {
    final byCategory = <String?, List<TagLibraryEntry>>{};
    for (final entry in this) {
      byCategory.putIfAbsent(entry.categoryId, () => []).add(entry);
    }
    return List.unmodifiable(<TagLibraryEntryGroup>[
      for (final category in categories.sortedByOrder())
        if (byCategory[category.id] case final entries?)
          (category: category, entries: List.unmodifiable(entries)),
      if (byCategory[null] case final entries?)
        (category: null, entries: List.unmodifiable(entries)),
    ]);
  }
}
