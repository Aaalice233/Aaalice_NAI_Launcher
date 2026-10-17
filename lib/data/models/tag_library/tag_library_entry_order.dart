import 'package:collection/collection.dart';

import 'tag_library_entry.dart';

/// 放下位置：插到 [entryId] 之前或之后
typedef TagLibraryEntryAnchor = ({String entryId, bool after});

/// 移动时一并改到的分类，`id` 为 null 表示未分类
typedef TagLibraryEntryCategoryTarget = ({String? id});

/// 把 [movedIds] 按给定次序整块插到 [anchor] 前后，返回按新顺序重新编号的全部条目
///
/// [visibleIds] 是放下时所在的显示序列；被移动的条目紧挨着它在该序列里的邻居落位，
/// 其余条目之间的相对顺序不变。结果与显示规则一致收藏在前，移动不会穿越收藏分组。
/// 顺序与分类都没有变化时返回 null。
List<TagLibraryEntry>? moveTagLibraryEntries(
  List<TagLibraryEntry> entries, {
  required List<String> visibleIds,
  required List<String> movedIds,
  required TagLibraryEntryAnchor anchor,
  TagLibraryEntryCategoryTarget? category,
  DateTime Function() now = DateTime.now,
}) {
  final byId = {for (final entry in entries) entry.id: entry};
  final moved = [
    for (final id in {...movedIds})
      if (byId.containsKey(id)) id,
  ];
  if (moved.isEmpty || moved.contains(anchor.entryId)) return null;
  final movedSet = moved.toSet();
  final remaining = [
    for (final id in visibleIds)
      if (byId.containsKey(id) && !movedSet.contains(id)) id,
  ];
  final anchorIndex = remaining.indexOf(anchor.entryId);
  if (anchorIndex < 0) return null;
  final insertAt = anchor.after ? anchorIndex + 1 : anchorIndex;

  final changedAt = now();
  final arranged = [
    for (final id in remaining.take(insertAt)) byId[id]!,
    for (final id in moved) _placeIn(byId[id]!, category, changedAt),
    for (final id in remaining.skip(insertAt)) byId[id]!,
  ].favoritesFirst();

  final ordered = entries.sortedByOrder();
  final result = _withVisibleInDisplayOrder(
    [
      for (final entry in ordered)
        if (!movedSet.contains(entry.id)) entry,
    ],
    [
      for (final entry in arranged)
        if (!movedSet.contains(entry.id)) entry,
    ],
  );
  _insertMovedBlocks(result, arranged, movedSet);

  final orderUnchanged = const ListEquality<String>().equals(
    [for (final entry in ordered) entry.id],
    [for (final entry in result) entry.id],
  );
  final categoryUnchanged = moved.every(
    (id) => category == null || byId[id]!.categoryId == category.id,
  );
  if (orderUnchanged && categoryUnchanged) return null;
  return result.reindex();
}

// 显示序列里的条目按显示次序占回它们原有的位置；只有收藏分组会让两者不同
List<TagLibraryEntry> _withVisibleInDisplayOrder(
  List<TagLibraryEntry> rest,
  List<TagLibraryEntry> visibleInDisplayOrder,
) {
  final visibleIds = {for (final entry in visibleInDisplayOrder) entry.id};
  final placements = visibleInDisplayOrder.iterator;
  final result = <TagLibraryEntry>[];
  for (final entry in rest) {
    if (visibleIds.contains(entry.id)) {
      placements.moveNext();
      result.add(placements.current);
    } else {
      result.add(entry);
    }
  }
  return result;
}

// 收藏分组可能把被移动的条目拆成两段，每段贴着显示序列里的前一个邻居插入
void _insertMovedBlocks(
  List<TagLibraryEntry> result,
  List<TagLibraryEntry> arranged,
  Set<String> movedIds,
) {
  var index = 0;
  while (index < arranged.length) {
    if (!movedIds.contains(arranged[index].id)) {
      index++;
      continue;
    }
    final start = index;
    while (index < arranged.length && movedIds.contains(arranged[index].id)) {
      index++;
    }
    final insertAt = start > 0
        ? result.indexWhere((e) => e.id == arranged[start - 1].id) + 1
        : result.indexWhere((e) => e.id == arranged[index].id);
    result.insertAll(insertAt, arranged.sublist(start, index));
  }
}

TagLibraryEntry _placeIn(
  TagLibraryEntry entry,
  TagLibraryEntryCategoryTarget? category,
  DateTime changedAt,
) {
  if (category == null || entry.categoryId == category.id) return entry;
  return entry.copyWith(categoryId: category.id, updatedAt: changedAt);
}
