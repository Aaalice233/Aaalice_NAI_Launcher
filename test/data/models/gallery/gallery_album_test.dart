import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/data/models/gallery/gallery_album.dart';

GalleryAlbum album(
  String id, {
  String? parentId,
  int sortOrder = 0,
}) {
  return GalleryAlbum(
    id: id,
    name: id,
    parentId: parentId,
    sortOrder: sortOrder,
    createdAt: DateTime(2025),
    updatedAt: DateTime(2025),
  );
}

void main() {
  test('buildTree sorts siblings by sortOrder', () {
    final tree = [
      album('b', sortOrder: 1),
      album('a', sortOrder: 0),
      album('a2', parentId: 'a', sortOrder: 1),
      album('a1', parentId: 'a', sortOrder: 0),
    ].buildTree();

    expect(tree[null]!.map((a) => a.id).toList(), ['a', 'b']);
    expect(tree['a']!.map((a) => a.id).toList(), ['a1', 'a2']);
  });

  test('wouldCreateCycle detects self, ancestor, and rejects valid moves',
      () {
    final albums = [
      album('root'),
      album('mid', parentId: 'root'),
      album('leaf', parentId: 'mid'),
    ];

    expect(albums.wouldCreateCycle('mid', 'mid'), isTrue);
    expect(albums.wouldCreateCycle('root', 'leaf'), isTrue);
    expect(albums.wouldCreateCycle('leaf', 'root'), isFalse);
    expect(albums.wouldCreateCycle('leaf', null), isFalse);
  });

  test('getDescendantIds collects all levels', () {
    final albums = [
      album('root'),
      album('c1', parentId: 'root'),
      album('c2', parentId: 'root'),
      album('gc', parentId: 'c1'),
    ];

    expect(albums.getDescendantIds('root'), {'c1', 'c2', 'gc'});
    expect(albums.getDescendantIds('c2'), isEmpty);
    expect(albums.getWithDescendantIds('c1'), {'c1', 'gc'});
  });

  test('getPathString joins ancestor chain', () {
    final albums = [
      album('root'),
      album('mid', parentId: 'root'),
      album('leaf', parentId: 'mid'),
    ];

    expect(albums.getPathString('leaf'), 'root / mid / leaf');
    expect(albums.getPathString('root'), 'root');
  });
}
