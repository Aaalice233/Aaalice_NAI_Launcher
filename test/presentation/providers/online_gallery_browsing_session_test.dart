import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';

void main() {
  test('browsing session restores choices but resets viewport position', () {
    const base = OnlineGalleryState(
      viewMode: GalleryViewMode.popular,
      sourceId: GallerySourceId.gelbooru,
      popularSourceId: GallerySourceId.aiTag,
      favoritesSourceId: GallerySourceId.gelbooru,
      searchQuery: '1girl sky',
      promptQuery: 'artist:foo',
      popularQuery: 'landscape',
      popularPromptQuery: 'cinematic',
      fuzzySearchEnabled: true,
      selectedRatings: {'g', 's'},
      popularScale: PopularScale.month,
      aiTagTimeRange: 'month',
      aiTagPopularPeriod: '2026-02',
      quickTagCloudFilterKey:
          'book%2Fone|%E4%BA%BA%E7%89%A9/%25|update%2F1|recent|withoutImages|true|false|false',
      randomEnabled: true,
      randomSession: RandomGallerySession(
        cache: ModeCache(
          scrollOffset: 512,
          anchorStableKey: 'ai_tag:88',
          anchorLocalOffset: 12,
        ),
      ),
      artistHuntEnabled: true,
    );
    final state = base.updateCurrentCache(
      const ModeCache(
        page: 7,
        scrollOffset: 2048,
        anchorStableKey: 'ai_tag:42',
        anchorLocalOffset: 16,
      ),
    );

    final restored = decodeOnlineGalleryBrowsingSession(
      encodeOnlineGalleryBrowsingSession(state),
    );

    expect(restored.viewMode, GalleryViewMode.popular);
    expect(restored.sourceId, GallerySourceId.gelbooru);
    expect(restored.popularSourceId, GallerySourceId.aiTag);
    expect(restored.favoritesSourceId, GallerySourceId.gelbooru);
    expect(restored.searchQuery, '1girl sky');
    expect(restored.promptQuery, 'artist:foo');
    expect(restored.popularQuery, 'landscape');
    expect(restored.popularPromptQuery, 'cinematic');
    expect(restored.fuzzySearchEnabled, isTrue);
    expect(restored.selectedRatings, {'g', 's'});
    expect(restored.popularScale, PopularScale.month);
    expect(restored.aiTagTimeRange, 'month');
    expect(restored.aiTagPopularPeriod, '2026-02');
    expect(
      restored.quickTagCloudFilterKey,
      'book%2Fone|%E4%BA%BA%E7%89%A9/%25|update%2F1|recent|withoutImages|true|false|false',
    );
    expect(restored.randomEnabled, isTrue);
    expect(restored.artistHuntEnabled, isTrue);
    expect(restored.currentCache.page, 1);
    expect(restored.currentCache.nextCursor, '1');
    expect(restored.currentCache.scrollOffset, 0);
    expect(restored.currentCache.anchorStableKey, isNull);
    expect(restored.randomSession.cache.scrollOffset, 0);
    final encoded = encodeOnlineGalleryBrowsingSession(state);
    expect(encoded, isNot(contains('positions')));
    expect(encoded, isNot(contains('randomPosition')));
  });

  test('legacy favorite position is ignored', () {
    final restored = decodeOnlineGalleryBrowsingSession(
      jsonEncode({
        'version': 1,
        'viewMode': 'favorites',
        'favoritesSourceId': 'gelbooru',
        'favoritesScope': 'remote',
        'positions': {
          'favorites:gelbooru:remote||egqs|codex:|blacklist:0': {
            'page': 4,
            'offset': 96,
          },
        },
      }),
    );

    expect(restored.viewMode, GalleryViewMode.favorites);
    expect(restored.currentCache.page, 1);
    expect(restored.currentCache.scrollOffset, 0);
    expect(
      encodeOnlineGalleryBrowsingSession(restored),
      isNot(contains('favoritesScope')),
    );
  });

  test('all legacy favorite positions are ignored', () {
    final restored = decodeOnlineGalleryBrowsingSession(
      jsonEncode({
        'version': 1,
        'viewMode': 'favorites',
        'favoritesSourceId': 'danbooru',
        'favoritesScope': 'remote',
        'positions': {
          'favorites:danbooru:local||egqs|codex:|blacklist:0': {
            'page': 2,
            'offset': 20,
          },
          'favorites:danbooru:remote||egqs|codex:|blacklist:0': {
            'page': 8,
            'offset': 80,
          },
        },
      }),
    );

    expect(restored.currentCache.page, 1);
    expect(restored.currentCache.scrollOffset, 0);
  });

  test('invalid or obsolete session safely falls back to defaults', () {
    expect(
      decodeOnlineGalleryBrowsingSession('{"version":99}').viewMode,
      GalleryViewMode.search,
    );
    expect(
      decodeOnlineGalleryBrowsingSession('not json').sourceId,
      GallerySourceId.danbooru,
    );
    expect(
      decodeOnlineGalleryBrowsingSession(
        '{"version":1,"quickTagCloudFilterKey":"invalid"}',
      ).quickTagCloudFilterKey,
      'suozhang|||catalog|all|false|false|false',
    );
  });

  test('legacy persisted page always reloads from page one', () async {
    final storage = _MemoryStorage();
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      jsonEncode({
        'version': 2,
        'searchQuery': 'restored',
        'positions': {
          'search:danbooru|restored|egqs|blacklist:0': {
            'page': 19,
            'scrollOffset': 12000,
          },
        },
      }),
    );
    final adapter = _CursorAdapter(
      GallerySourceId.danbooru,
      returnsItems: true,
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.danbooru
                ? adapter
                : _CursorAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.loadPosts();

    final restored = container.read(onlineGalleryNotifierProvider);
    expect(adapter.lastSearchCursor, '1');
    expect(restored.currentCache.page, 1);
    expect(restored.currentCache.scrollOffset, 0);
  });

  test(
    'restores the complete QuickTagCloud filter before first load',
    () async {
      final storage = _MemoryStorage();
      const filter = QuickTagCloudGalleryQuery(
        codexId: 'book/one',
        categoryPath: ['人物', '%'],
        updateFilterId: 'update/1',
        scope: QuickTagCloudBrowseScope.recent,
        mediaFilter: QuickTagCloudMediaFilter.withoutImages,
      );
      await storage.setSetting(
        StorageKeys.onlineGalleryBrowsingSessionV1,
        encodeOnlineGalleryBrowsingSession(
          OnlineGalleryState(
            sourceId: GallerySourceId.quickTagCloud,
            quickTagCloudFilterKey: filter.stableKey,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          onlineGallerySourceAdaptersProvider.overrideWithValue({
            for (final source in GallerySourceId.values)
              source: _CursorAdapter(source),
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onlineGalleryNotifierProvider.notifier).loadPosts();

      final restored = container.read(quickTagCloudFilterProvider);
      expect(restored.codexId, 'book/one');
      expect(restored.categoryPath, ['人物', '%']);
      expect(restored.updateFilterId, 'update/1');
      expect(restored.scope, QuickTagCloudBrowseScope.recent);
      expect(restored.mediaFilter, QuickTagCloudMediaFilter.withoutImages);
    },
  );

  test('favorite caches never leak across sources or queries', () {
    const aiItem = GalleryItem(
      id: 1,
      sourceId: GallerySourceId.aiTag,
      workId: 'ai-1',
    );
    var state = const OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: GallerySourceId.aiTag,
    );
    state = state.updateFavoritesCache(
      GallerySourceId.aiTag,
      const ModeCache(posts: [aiItem], hasMore: false),
    );

    expect(state.favoritesCacheFor(GallerySourceId.aiTag).posts, [aiItem]);
    expect(state.favoritesCacheFor(GallerySourceId.danbooru).posts, isEmpty);
    expect(state.favoritesCacheFor(GallerySourceId.gelbooru).posts, isEmpty);

    state = state.copyWith(favoriteSearchQuery: 'different query');
    expect(state.favoritesCacheFor(GallerySourceId.aiTag).posts, isEmpty);
  });

  test('mode changes keep the currently selected source', () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: _CursorAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.sourceId, GallerySourceId.aiTag);
    expect(state.popularSourceId, GallerySourceId.aiTag);
    expect(state.favoritesSourceId, GallerySourceId.aiTag);

    await notifier.switchToPopular();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.viewMode, GalleryViewMode.popular);
    expect(state.activeSourceId, GallerySourceId.aiTag);

    await notifier.switchToSearch();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.viewMode, GalleryViewMode.search);
    expect(state.activeSourceId, GallerySourceId.aiTag);
  });

  test('popular mode does not silently change an unsupported source', () async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: _CursorAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.gelbooru);
    await notifier.switchToPopular();

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.viewMode, GalleryViewMode.search);
    expect(state.activeSourceId, GallerySourceId.gelbooru);
  });

  test('notifier persists browsing intent but not location changes', () async {
    final storage = _MemoryStorage();
    final initial = const OnlineGalleryState(
      searchQuery: 'restored',
    ).updateCurrentCache(const ModeCache(page: 3, scrollOffset: 120));
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      encodeOnlineGalleryBrowsingSession(initial),
    );
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    final restored = container.read(onlineGalleryNotifierProvider);
    expect(restored.searchQuery, 'restored');
    expect(restored.currentCache.page, 1);

    container
        .read(onlineGalleryNotifierProvider.notifier)
        .saveScrollOffset(
          456,
          anchorStableKey: 'danbooru:9',
          anchorLocalOffset: 8,
        );
    await Future<void>.delayed(Duration.zero);

    final persisted = decodeOnlineGalleryBrowsingSession(
      storage.getSetting<String>(StorageKeys.onlineGalleryBrowsingSessionV1),
    );
    expect(persisted.currentCache.scrollOffset, 0);
    expect(persisted.currentCache.anchorStableKey, isNull);
    expect(persisted.currentCache.anchorLocalOffset, 0);
  });
}

class _CursorAdapter extends GallerySourceAdapter {
  _CursorAdapter(this.sourceId, {this.returnsItems = false});

  @override
  final GallerySourceId sourceId;
  final bool returnsItems;

  String? lastSearchCursor;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    lastSearchCursor = request.cursor;
    return _emptyPage(request.cursor);
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async => _emptyPage(request.cursor);

  GalleryPage _emptyPage(String cursor) => GalleryPage(
    items: returnsItems
        ? [GalleryItem(id: int.tryParse(cursor) ?? 1, sourceId: sourceId)]
        : const [],
    cursor: cursor,
    nextCursor: null,
    hasMore: false,
  );
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}
