import 'package:collection/collection.dart';

enum LibrarySidebarSort {
  original,
  nameAscending,
  nameDescending,
  countDescending,
  countAscending,
}

/// Sort a sibling list without changing its stored order or tree membership.
List<T> sortLibrarySidebarItems<T>(
  Iterable<T> items, {
  required LibrarySidebarSort sort,
  required String Function(T) idOf,
  required String Function(T) nameOf,
  required int Function(T) countOf,
  required int Function(T) orderOf,
}) {
  int compareNames(T a, T b) =>
      compareNatural(nameOf(a).toLowerCase(), nameOf(b).toLowerCase());

  return [...items]..sort((a, b) {
    final comparison = switch (sort) {
      LibrarySidebarSort.original => orderOf(a).compareTo(orderOf(b)),
      LibrarySidebarSort.nameAscending => compareNames(a, b),
      LibrarySidebarSort.nameDescending => compareNames(b, a),
      LibrarySidebarSort.countDescending => countOf(b).compareTo(countOf(a)),
      LibrarySidebarSort.countAscending => countOf(a).compareTo(countOf(b)),
    };
    if (comparison != 0) return comparison;
    if (sort == LibrarySidebarSort.countAscending ||
        sort == LibrarySidebarSort.countDescending) {
      final nameComparison = compareNames(a, b);
      if (nameComparison != 0) return nameComparison;
    }
    // Equal labels/counts must not jump when a scan supplies a new list instance.
    final orderComparison = orderOf(a).compareTo(orderOf(b));
    return orderComparison != 0 ? orderComparison : idOf(a).compareTo(idOf(b));
  });
}
