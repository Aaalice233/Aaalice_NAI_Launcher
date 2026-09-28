import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/gallery_tree_drop_slot.dart';
import 'package:nai_launcher/data/models/gallery/library_tree_order.dart';

typedef _Node = ({String id, String? parent, int order});

List<_Node>? _move(
  List<_Node> nodes,
  String source,
  String? target,
  GalleryTreeDropSlot slot,
) => moveLibraryTreeItem(
  nodes,
  sourceId: source,
  targetId: target,
  slot: slot,
  idOf: (n) => n.id,
  parentOf: (n) => n.parent,
  orderOf: (n) => n.order,
  withPlacement: (n, parent, order) => (id: n.id, parent: parent, order: order),
);

void main() {
  final nodes = <_Node>[
    (id: 'a', parent: null, order: 0),
    (id: 'b', parent: null, order: 1),
    (id: 'c', parent: 'a', order: 0),
  ];
  test(
    'rejects self, descendants, missing targets, and unchanged positions',
    () {
      expect(_move(nodes, 'a', 'a', GalleryTreeDropSlot.before), isNull);
      expect(_move(nodes, 'a', 'c', GalleryTreeDropSlot.child), isNull);
      expect(_move(nodes, 'a', 'missing', GalleryTreeDropSlot.after), isNull);
      expect(_move(nodes, 'a', 'b', GalleryTreeDropSlot.before), isNull);
      expect(_move(nodes, 'c', 'a', GalleryTreeDropSlot.child), isNull);
    },
  );
  test(
    'cross-parent insertion preserves all identities and unrelated parents',
    () {
      final moved = _move(nodes, 'c', 'b', GalleryTreeDropSlot.before)!;
      expect(moved.where((n) => n.parent == null).map((n) => n.id).toSet(), {
        'a',
        'b',
        'c',
      });
      expect(moved.singleWhere((n) => n.id == 'c').order, 1);
      expect(moved.singleWhere((n) => n.id == 'b').order, 2);
      expect(nodes.last.parent, 'a');
    },
  );
  test('stale display snapshots fail before modifying data', () {
    expect(
      () => applyLibraryDisplayOrder(
        nodes,
        {'a': 0, 'b': 1},
        idOf: (n) => n.id,
        withOrder: (n, order) => (id: n.id, parent: n.parent, order: order),
      ),
      throwsStateError,
    );
  });
}
