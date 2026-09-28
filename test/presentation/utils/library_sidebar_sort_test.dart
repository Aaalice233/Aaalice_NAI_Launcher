import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/utils/library_sidebar_sort.dart';

typedef _Item = ({String id, String name, int count, int order});

List<_Item> _sorted(List<_Item> items, LibrarySidebarSort sort) =>
    sortLibrarySidebarItems(
      items,
      sort: sort,
      idOf: (item) => item.id,
      nameOf: (item) => item.name,
      countOf: (item) => item.count,
      orderOf: (item) => item.order,
    );

void main() {
  test('date names are newest first across months and years', () {
    final items = [
      (id: 'a', name: '2026-09-07', count: 1, order: 0),
      (id: 'b', name: '2025-12-31', count: 1, order: 1),
      (id: 'c', name: '2026-10-01', count: 1, order: 2),
      (id: 'd', name: '2026-09-06', count: 1, order: 3),
    ];
    expect(_sorted(items, LibrarySidebarSort.nameDescending).map((i) => i.id), [
      'c',
      'a',
      'd',
      'b',
    ]);
    expect(items.map((i) => i.id), ['a', 'b', 'c', 'd']);
  });

  test('natural name order handles numbers, case, and non-date names', () {
    final items = [
      (id: 'a', name: 'Sketch 10', count: 4, order: 0),
      (id: 'b', name: 'sketch 2', count: 4, order: 1),
      (id: 'c', name: '构图 10', count: 0, order: 2),
      (id: 'd', name: '构图 2', count: 0, order: 3),
    ];
    expect(_sorted(items, LibrarySidebarSort.nameAscending).map((i) => i.id), [
      'b',
      'a',
      'd',
      'c',
    ]);
    expect(_sorted(items, LibrarySidebarSort.nameDescending).map((i) => i.id), [
      'c',
      'd',
      'a',
      'b',
    ]);
    expect(_sorted(items, LibrarySidebarSort.original), items);
  });

  test('counts use natural names for ties and include empty categories', () {
    final items = [
      (id: 'a', name: 'Folder 10', count: 8, order: 0),
      (id: 'b', name: 'Folder 2', count: 8, order: 1),
      (id: 'c', name: 'Empty', count: 0, order: 2),
    ];
    expect(
      _sorted(items, LibrarySidebarSort.countDescending).map((i) => i.id),
      ['b', 'a', 'c'],
    );
    expect(_sorted(items, LibrarySidebarSort.countAscending).map((i) => i.id), [
      'c',
      'b',
      'a',
    ]);
  });

  test('equal names and order have deterministic identity ordering', () {
    final items = [
      (id: 'b', name: 'Same', count: 0, order: 1),
      (id: 'a', name: 'same', count: 0, order: 1),
      (id: 'c', name: 'Same', count: 0, order: 0),
    ];
    for (final sort in LibrarySidebarSort.values) {
      expect(_sorted(items, sort).map((i) => i.id), ['c', 'a', 'b']);
      expect(_sorted(items.reversed.toList(), sort), _sorted(items, sort));
      expect(_sorted([], sort), isEmpty);
    }
  });
}
