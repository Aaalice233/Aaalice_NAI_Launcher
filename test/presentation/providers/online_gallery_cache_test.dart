import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

void main() {
  test('ordinary query cache retains at most 12 most-recent queries', () {
    var state = const OnlineGalleryState();

    for (var index = 0; index < 14; index++) {
      state = state.copyWith(searchQuery: 'query-$index');
      state = state.updateCurrentCache(
        ModeCache(posts: [_item(index)], page: index + 1),
      );
    }

    expect(state.caches, hasLength(12));
    expect(state.currentCache.posts.single.id, 13);
    expect(state.currentCache.page, 14);
    expect(
      state.caches.values.expand((cache) => cache.posts).map((item) => item.id),
      isNot(contains(0)),
    );
  });

  test('background cache updates never evict the active query', () {
    const base = OnlineGalleryState(searchQuery: 'keep-me');
    final caches = <String, ModeCache>{
      base.currentCacheKey: const ModeCache(page: 9),
    };
    for (var index = 0; index < 11; index++) {
      caches['old-$index'] = ModeCache(page: index);
    }
    final state = base
        .copyWith(caches: caches)
        .updateFavoritesCache(
          GallerySourceId.gelbooru,
          const ModeCache(page: 2),
        );

    expect(state.caches, hasLength(12));
    expect(state.caches, contains(base.currentCacheKey));
    expect(state.currentCache.page, 9);
  });

  test('QuickTagCloud filters own independent list caches', () {
    const firstFilter = OnlineGalleryState(
      sourceId: GallerySourceId.quickTagCloud,
      quickTagCloudFilterKey: 'book-a|people',
    );
    final withFirst = firstFilter.updateCurrentCache(
      ModeCache(posts: [_item(1)], page: 2),
    );
    final secondFilter = withFirst.copyWith(
      quickTagCloudFilterKey: 'book-b|concepts',
    );

    expect(secondFilter.currentCache.posts, isEmpty);
    final restored = secondFilter.copyWith(
      quickTagCloudFilterKey: 'book-a|people',
    );
    expect(restored.currentCache.posts.single.id, 1);
    expect(restored.currentCache.page, 2);
  });

  test(
    'mode cache preserves post anchor and uses pixel offset as fallback',
    () {
      const cache = ModeCache(
        scrollOffset: 640,
        anchorStableKey: 'danbooru:42',
        anchorLocalOffset: 18,
      );
      final state = const OnlineGalleryState().updateCurrentCache(cache);

      expect(state.scrollOffset, 640);
      expect(state.currentCache.anchorStableKey, 'danbooru:42');
      expect(state.currentCache.anchorLocalOffset, 18);
    },
  );
}

GalleryItem _item(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.danbooru,
  cover: GalleryMedia(id: '$id'),
  createdAt: '2026-01-01',
);
