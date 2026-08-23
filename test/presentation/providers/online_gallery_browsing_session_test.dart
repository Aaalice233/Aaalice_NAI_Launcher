import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

void main() {
  test('browsing session round-trips choices and per-query position', () {
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
    expect(restored.randomEnabled, isTrue);
    expect(restored.artistHuntEnabled, isTrue);
    expect(restored.currentCache.page, 7);
    expect(restored.currentCache.nextCursor, '7');
    expect(restored.currentCache.scrollOffset, 2048);
    expect(restored.currentCache.anchorStableKey, 'ai_tag:42');
    expect(restored.randomSession.cache.scrollOffset, 512);
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
  });

  test('restored page is re-fetched without losing its position', () async {
    final storage = _MemoryStorage();
    final initial = const OnlineGalleryState(
      searchQuery: 'restored',
    ).updateCurrentCache(const ModeCache(page: 3, scrollOffset: 120));
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      encodeOnlineGalleryBrowsingSession(initial),
    );
    final adapter = _CursorAdapter(GallerySourceId.danbooru);
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

    await container.read(onlineGalleryNotifierProvider.notifier).loadPosts();

    final restored = container.read(onlineGalleryNotifierProvider);
    expect(adapter.lastSearchCursor, '3');
    expect(restored.currentCache.page, 3);
    expect(restored.currentCache.scrollOffset, 120);
  });

  test('notifier restores and persists location changes', () async {
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
    expect(restored.currentCache.page, 3);

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
    expect(persisted.currentCache.scrollOffset, 456);
    expect(persisted.currentCache.anchorStableKey, 'danbooru:9');
    expect(persisted.currentCache.anchorLocalOffset, 8);
  });
}

class _CursorAdapter extends GallerySourceAdapter {
  _CursorAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;

  String? lastSearchCursor;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    lastSearchCursor = request.cursor;
    return GalleryPage(
      items: const [],
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
    );
  }
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
