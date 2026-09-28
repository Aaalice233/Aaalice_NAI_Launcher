import 'package:collection/collection.dart';

import 'gallery_tree_drop_slot.dart';

/// Materialize display ordering only when the user commits a manual move.
List<T> applyLibraryDisplayOrder<T>(
  List<T> items,
  Map<String, int>? displayOrder, {
  required String Function(T) idOf,
  required T Function(T, int) withOrder,
}) {
  if (displayOrder == null) return [...items];
  if (displayOrder.length != items.length ||
      items.any((item) => !displayOrder.containsKey(idOf(item)))) {
    throw StateError('Category list changed during drag; retry the move');
  }
  return [for (final item in items) withOrder(item, displayOrder[idOf(item)]!)];
}

/// Compute an identity-based move without IO. Null denotes an unchanged order.
List<T>? moveLibraryTreeItem<T>(
  List<T> items, {
  required String sourceId,
  required String? targetId,
  required GalleryTreeDropSlot slot,
  required String Function(T) idOf,
  required String? Function(T) parentOf,
  required int Function(T) orderOf,
  required T Function(T item, String? parentId, int order) withPlacement,
  bool flat = false,
}) {
  final byId = {for (final item in items) idOf(item): item};
  final source = byId[sourceId];
  final target = byId[targetId];
  if (source == null ||
      (targetId != null && target == null) ||
      sourceId == targetId) {
    return null;
  }
  if (flat && slot == GalleryTreeDropSlot.child) return null;
  if (targetId == null && (flat || slot != GalleryTreeDropSlot.child)) {
    return null;
  }
  final parent = flat
      ? parentOf(source)
      : slot == GalleryTreeDropSlot.child
      ? targetId
      : parentOf(target as T);
  final visited = <String>{};
  var ancestor = parent;
  while (!flat && ancestor != null) {
    if (ancestor == sourceId) return null;
    if (!visited.add(ancestor)) {
      throw StateError('Category hierarchy contains a cycle');
    }
    final node = byId[ancestor];
    ancestor = node == null ? null : parentOf(node);
  }
  final siblings =
      items.where((item) => flat || parentOf(item) == parent).toList()
        ..sort((a, b) {
          final order = orderOf(a).compareTo(orderOf(b));
          return order == 0 ? idOf(a).compareTo(idOf(b)) : order;
        });
  final before = siblings.map(idOf).toList();
  final after = before.where((id) => id != sourceId).toList();
  final index = slot == GalleryTreeDropSlot.child
      ? after.length
      : after.indexOf(targetId!) + (slot == GalleryTreeDropSlot.after ? 1 : 0);
  after.insert(index, sourceId);
  if (const ListEquality<String>().equals(before, after)) return null;
  final positions = {for (var i = 0; i < after.length; i++) after[i]: i};
  return [
    for (final item in items)
      if (positions.containsKey(idOf(item)))
        withPlacement(
          item,
          flat ? parentOf(item) : parent,
          positions[idOf(item)]!,
        )
      else
        item,
  ];
}
