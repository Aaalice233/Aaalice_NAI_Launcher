import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/chunked_gallery_items.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_favorites_service.dart';

void main() {
  const service = OnlineGalleryFavoritesService();

  test('merges duplicate local and remote favorites without losing detail', () {
    final sparse = _item(1, title: 'remote title');
    final detailed = _item(
      1,
      tags: const ['artist:name', 'character'],
      displayUrl: 'https://example.test/full.jpg',
    );

    final merged = service.mergeItem(sparse, detailed);

    expect(merged.title, 'remote title');
    expect(merged.tags, containsAll(<String>['artist:name', 'character']));
    expect(merged.cover.displayUrl, 'https://example.test/full.jpg');
  });

  test('removing one branch preserves items retained by the other branch', () {
    final posts = ChunkedGalleryItems.from([_item(1), _item(2)]);

    final result = service.removeBranch(
      posts,
      branchKeys: const {'danbooru:1', 'danbooru:2'},
      retainedByOtherBranch: const {'danbooru:2'},
    );

    expect(result.map((item) => item.stableKey), ['danbooru:2']);
  });
}

GalleryItem _item(
  int id, {
  String? title,
  List<String> tags = const [],
  String displayUrl = '',
}) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.danbooru,
  title: title,
  tags: tags,
  cover: GalleryMedia(id: '$id', displayUrl: displayUrl),
  createdAt: '2026-01-01',
);
