import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/repositories/online_gallery_local_favorites_repository.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_remote_catalog_service.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_user_service.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_blacklist_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_local_favorites_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'random draws never repeat and disabling restores normal cache',
    () async {
      final adapter = _RandomFakeAdapter([
        [_item(1), _item(2)],
        [_item(2), _item(3)],
        [_item(3), _item(4)],
      ]);
      final container = _container(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      notifier.saveScrollOffset(42);
      await notifier.setRandomEnabled(true);
      await notifier.loadMore();

      var state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2, 3]);
      expect(state.randomSession.seenStableKeys, hasLength(3));

      notifier.saveScrollOffset(
        84,
        anchorStableKey: 'danbooru:2',
        anchorLocalOffset: 7,
      );
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2, 3]);
      expect(state.randomSession.cache.scrollOffset, 84);
      expect(state.randomSession.cache.anchorStableKey, 'danbooru:2');

      await notifier.refresh();
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [4]);
      expect(state.randomSession.seenStableKeys, hasLength(4));

      await notifier.setSource(GallerySourceId.safebooru);
      expect(
        container.read(onlineGalleryNotifierProvider).sourceId,
        GallerySourceId.safebooru,
      );
      await notifier.setRandomEnabled(false);
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.sourceId, GallerySourceId.danbooru);
      expect(state.posts.map((item) => item.id), [100]);
      expect(state.scrollOffset, 42);
      expect(adapter.searchCalls, 1);
    },
  );

  test('random search preserves fuzzy matching and resets its scope', () async {
    final adapter = _RandomFakeAdapter([
      [_item(1)],
      [_item(2)],
      [_item(3)],
    ]);
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setRandomEnabled(true);
    await notifier.search('cat dog');
    await notifier.setFuzzySearchEnabled(true);

    final request = adapter.lastRandomRequest as GalleryRandomSearchRequest;
    expect(request.query, '*cat* *dog*');
    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.randomEnabled, isTrue);
    expect(state.posts.map((item) => item.id), [3]);
    expect(state.randomSession.seenStableKeys, {'danbooru:3'});
  });

  test('QuickTagCloud never receives booru fuzzy wildcards', () async {
    final storage = _MemoryStorage();
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      encodeOnlineGalleryBrowsingSession(
        const OnlineGalleryState(
          sourceId: GallerySourceId.quickTagCloud,
          searchQuery: 'cat',
          fuzzySearchEnabled: true,
        ),
      ),
    );
    final adapter = _QueryRecordingAdapter(GallerySourceId.quickTagCloud);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.quickTagCloud
                ? adapter
                : _EmptyAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.loadPosts();
    await notifier.setRandomEnabled(true);

    expect(adapter.lastSearchRequest?.query, 'cat');
    expect(
      (adapter.lastRandomRequest as GalleryRandomSearchRequest).query,
      'cat',
    );
  });

  test('QuickTagCloud random applies the shared blacklist', () async {
    final storage = _MemoryStorage();
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      encodeOnlineGalleryBrowsingSession(
        const OnlineGalleryState(sourceId: GallerySourceId.quickTagCloud),
      ),
    );
    final item = _quickItem('blocked').copyWith(tags: const ['blocked_tag']);
    final adapter = _QueryRecordingAdapter(
      GallerySourceId.quickTagCloud,
      randomItems: [item],
    );
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.quickTagCloud
                ? adapter
                : _EmptyAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .addLocalTag('blocked_tag');

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setRandomEnabled(true);

    final request = adapter.lastRandomRequest as GalleryRandomSearchRequest;
    expect(request.blacklistTags, {'blocked_tag'});
    expect(container.read(onlineGalleryNotifierProvider).posts, isEmpty);
  });

  test('unfavoriting in random local favorites restarts the draw', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'online-gallery-random-favorites-',
    );
    Hive.init(tempDirectory.path);
    await Hive.openBox<dynamic>(StorageKeys.localFavoritesBox);
    addTearDown(() async {
      await Hive.close();
      await tempDirectory.delete(recursive: true);
    });

    final storage = _MemoryStorage();
    const initialState = OnlineGalleryState(
      viewMode: GalleryViewMode.favorites,
      favoritesSourceId: GallerySourceId.quickTagCloud,
    );
    final favoriteCacheKey = initialState.currentCacheKey;
    await storage.setSetting(
      StorageKeys.onlineGalleryBrowsingSessionV1,
      encodeOnlineGalleryBrowsingSession(
        initialState.copyWith(
          caches: {
            favoriteCacheKey: const ModeCache(scrollOffset: 42),
            '$favoriteCacheKey:other-query': const ModeCache(scrollOffset: 84),
          },
        ),
      ),
    );
    final adapter = _FavoriteQuickTagCloudAdapter(storage);
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        quickTagCloudGallerySourceAdapterProvider.overrideWithValue(adapter),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.quickTagCloud
                ? adapter
                : _EmptyAdapter(source),
        }),
      ],
    );
    addTearDown(container.dispose);
    final localFavorites = container.read(
      onlineGalleryLocalFavoritesProvider.notifier,
    );
    final first = _quickItem(
      'one',
    ).copyWith(rating: 'g', rawSourceMetadata: const {'codexId': 'suozhang'});
    final second = _quickItem(
      'two',
    ).copyWith(rating: 'g', rawSourceMetadata: const {'codexId': 'suozhang'});
    await localFavorites.upsert(
      GalleryDetail(
        item: first,
        media: [first.cover],
        rawSourceMetadata: const {'codexId': 'suozhang'},
      ),
    );
    await localFavorites.upsert(
      GalleryDetail(
        item: second,
        media: [second.cover],
        rawSourceMetadata: const {'codexId': 'suozhang'},
      ),
    );
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    expect(container.read(onlineGalleryLocalFavoritesProvider).count, 2);
    expect(
      localFavorites
          .query(
            const OnlineGalleryFavoriteQuery(
              sourceId: GallerySourceId.quickTagCloud,
              ratings: {'g', 's', 'q', 'e'},
              codexId: 'suozhang',
              limit: 10,
            ),
          )
          .total,
      2,
    );
    expect(
      container.read(onlineGalleryNotifierProvider).viewMode,
      GalleryViewMode.favorites,
    );
    expect(
      container.read(onlineGalleryNotifierProvider).favoritesSourceId,
      GallerySourceId.quickTagCloud,
    );

    await notifier.setRandomEnabled(true);
    final activeFilter = container.read(quickTagCloudFilterProvider);
    expect(
      localFavorites
          .query(
            OnlineGalleryFavoriteQuery(
              sourceId: GallerySourceId.quickTagCloud,
              ratings: container
                  .read(onlineGalleryNotifierProvider)
                  .selectedRatings,
              blacklistTags: container
                  .read(onlineGalleryBlacklistNotifierProvider)
                  .effectiveTags,
              codexId: activeFilter.codexId,
              categoryPath: activeFilter.categoryPath,
              mediaFilter: activeFilter.mediaFilter.name,
              limit: 10,
            ),
          )
          .total,
      2,
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      if (container.read(onlineGalleryNotifierProvider).posts.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final refreshed = container.read(onlineGalleryNotifierProvider);
    expect(refreshed.error, isNull);
    expect(refreshed.posts, isNotEmpty);
    final removed = refreshed.posts.first;
    final snapshot = await notifier.loadDetail(removed);
    expect(snapshot.item.stableKey, removed.stableKey);
    expect(adapter.detailCalls, 0);

    await notifier.toggleFavorite(removed);
    expect(adapter.detailCalls, 0);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (container.read(onlineGalleryNotifierProvider).posts.length == 1) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, hasLength(1));
    expect(state.posts.single.stableKey, isNot(removed.stableKey));
    expect(state.randomSession.seenStableKeys, {state.posts.single.stableKey});
    expect(
      state.caches.keys.where(
        (key) => key.startsWith('favorites:quick_tag_cloud'),
      ),
      isEmpty,
    );
  });

  test('blacklisted results never consume random seen keys', () async {
    const blocked = GalleryItem(
      id: 8,
      sourceId: GallerySourceId.danbooru,
      tags: ['blocked_tag'],
      cover: GalleryMedia(
        id: '8',
        previewUrl: 'https://example.test/8-preview.webp',
        displayUrl: 'https://example.test/8.webp',
        downloadUrl: 'https://example.test/8.webp',
      ),
    );
    final adapter = _RandomFakeAdapter([
      [blocked, _item(9)],
    ]);
    final container = _container(adapter);
    addTearDown(container.dispose);
    await container
        .read(onlineGalleryBlacklistNotifierProvider.notifier)
        .addLocalTag('blocked_tag');

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setRandomEnabled(true);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.id), [9]);
    expect(state.randomSession.seenStableKeys, {'danbooru:9'});
  });

  test('random seen keys stop at 20,000 without evicting old keys', () async {
    final adapter = _RandomFakeAdapter([
      [for (var id = 1; id <= 20001; id++) _item(id)],
    ]);
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setRandomEnabled(true);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.randomSession.seenStableKeys, hasLength(20000));
    expect(state.randomSession.seenStableKeys, contains('danbooru:1'));
    expect(
      state.randomSession.seenStableKeys,
      isNot(contains('danbooru:20001')),
    );
    expect(state.randomSession.exhausted, isTrue);
  });

  test('four empty unique draws exhaust until explicit restart', () async {
    final adapter = _RandomFakeAdapter([
      const [],
      const [],
      const [],
      const [],
      [_item(7)],
    ]);
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setRandomEnabled(true);
    for (var i = 0; i < 3; i++) {
      await notifier.loadMore();
    }
    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.randomSession.consecutiveMisses, 4);
    expect(state.randomSession.exhausted, isTrue);

    await notifier.loadMore();
    expect(adapter.randomCalls, 4);

    await notifier.restartRandom();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.single.id, 7);
    expect(state.randomSession.seenStableKeys, {'danbooru:7'});
    expect(state.randomSession.exhausted, isFalse);
  });

  test(
    'source switch starts the new random request without awaiting the old one',
    () async {
      final oldRequest = Completer<GalleryPage>();
      final danbooru = _ControlledRandomAdapter(
        GallerySourceId.danbooru,
        responses: [oldRequest.future],
      );
      final safebooru = _ControlledRandomAdapter(
        GallerySourceId.safebooru,
        responses: [
          Future.value(_page([_sourceItem(2, GallerySourceId.safebooru)])),
        ],
      );
      final container = _containerWithAdapters(danbooru, safebooru);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final enabling = notifier.setRandomEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await notifier.setSource(GallerySourceId.safebooru);

      final state = container.read(onlineGalleryNotifierProvider);
      expect(danbooru.cancelTokens.single.isCancelled, isTrue);
      expect(safebooru.randomCalls, 1);
      expect(state.sourceId, GallerySourceId.safebooru);
      expect(state.posts.single.stableKey, 'safebooru:2');

      oldRequest.complete(_page([_item(99)]));
      await enabling;
      expect(
        container.read(onlineGalleryNotifierProvider).posts.single.stableKey,
        'safebooru:2',
      );
    },
  );

  test('rapid source switches commit only the latest random query', () async {
    final danbooruRequest = Completer<GalleryPage>();
    final safebooruRequest = Completer<GalleryPage>();
    final danbooru = _ControlledRandomAdapter(
      GallerySourceId.danbooru,
      responses: [danbooruRequest.future],
    );
    final safebooru = _ControlledRandomAdapter(
      GallerySourceId.safebooru,
      responses: [safebooruRequest.future],
    );
    final gelbooru = _ControlledRandomAdapter(
      GallerySourceId.gelbooru,
      responses: [
        Future.value(_page([_sourceItem(3, GallerySourceId.gelbooru)])),
      ],
    );
    final container = _containerWithAdapters(danbooru, safebooru, gelbooru);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    final first = notifier.setRandomEnabled(true);
    await Future<void>.delayed(Duration.zero);
    final second = notifier.setSource(GallerySourceId.safebooru);
    await Future<void>.delayed(Duration.zero);
    await notifier.setSource(GallerySourceId.gelbooru);

    expect(danbooru.cancelTokens.single.isCancelled, isTrue);
    expect(safebooru.cancelTokens.single.isCancelled, isTrue);
    expect(
      container.read(onlineGalleryNotifierProvider).posts.single.stableKey,
      'gelbooru:3',
    );

    safebooruRequest.complete(
      _page([_sourceItem(22, GallerySourceId.safebooru)]),
    );
    danbooruRequest.complete(_page([_item(11)]));
    await Future.wait([first, second]);
    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.sourceId, GallerySourceId.gelbooru);
    expect(state.posts.single.stableKey, 'gelbooru:3');
  });

  test(
    'refresh cancels the active random draw and starts a replacement',
    () async {
      final pending = Completer<GalleryPage>();
      final adapter = _ControlledRandomAdapter(
        GallerySourceId.danbooru,
        responses: [
          pending.future,
          Future.value(_page([_item(8)])),
        ],
      );
      final container = _containerWithAdapters(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final first = notifier.setRandomEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await notifier.refresh();

      expect(adapter.randomCalls, 2);
      expect(adapter.cancelTokens.first.isCancelled, isTrue);
      expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 8);

      pending.complete(_page([_item(9)]));
      await first;
      expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 8);
    },
  );

  test(
    'disabling random cancels an in-flight draw without reporting an error',
    () async {
      final pending = Completer<GalleryPage>();
      final adapter = _ControlledRandomAdapter(
        GallerySourceId.danbooru,
        responses: [pending.future],
      );
      final container = _containerWithAdapters(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final enabling = notifier.setRandomEnabled(true);
      await Future<void>.delayed(Duration.zero);
      await notifier.setRandomEnabled(false);

      var state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.cancelTokens.single.isCancelled, isTrue);
      expect(state.randomEnabled, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.hasError, isFalse);

      pending.complete(_page([_item(9)]));
      await enabling;
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.randomEnabled, isFalse);
      expect(state.posts, isEmpty);
    },
  );
}

ProviderContainer _container(_RandomFakeAdapter danbooru) =>
    _containerWithAdapters(danbooru);

ProviderContainer _containerWithAdapters(
  GallerySourceAdapter danbooru, [
  GallerySourceAdapter? safebooru,
  GallerySourceAdapter? gelbooru,
]) {
  final overrides = <GallerySourceId, GallerySourceAdapter>{
    GallerySourceId.danbooru: danbooru,
    if (safebooru != null) GallerySourceId.safebooru: safebooru,
    if (gelbooru != null) GallerySourceId.gelbooru: gelbooru,
  };
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        for (final source in GallerySourceId.values)
          source: overrides[source] ?? _EmptyAdapter(source),
      }),
    ],
  );
}

GalleryItem _item(int id) => _sourceItem(id, GallerySourceId.danbooru);

GalleryItem _sourceItem(int id, GallerySourceId sourceId) => GalleryItem(
  id: id,
  sourceId: sourceId,
  tags: const ['1girl'],
  cover: GalleryMedia(
    id: '$id',
    previewUrl: 'https://example.test/$id-preview.webp',
    displayUrl: 'https://example.test/$id.webp',
    downloadUrl: 'https://example.test/$id.webp',
  ),
);

GalleryItem _quickItem(String id) => GalleryItem(
  id: id.hashCode,
  sourceId: GallerySourceId.quickTagCloud,
  workId: 'book/$id',
  title: id,
  cover: GalleryMedia(
    id: id,
    previewUrl: 'https://example.test/$id-preview.webp',
    displayUrl: 'https://example.test/$id.webp',
    downloadUrl: 'https://example.test/$id.webp',
  ),
);

GalleryPage _page(List<GalleryItem> items) => GalleryPage(
  items: items,
  cursor: 'random',
  nextCursor: 'random',
  hasMore: true,
  rawItemCount: items.length,
);

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

class _ControlledRandomAdapter extends GallerySourceAdapter {
  _ControlledRandomAdapter(this.sourceId, {required this.responses});

  @override
  final GallerySourceId sourceId;
  final List<Future<GalleryPage>> responses;
  final List<CancelToken> cancelTokens = [];
  int randomCalls = 0;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const []);

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) {
    cancelTokens.add(cancelToken!);
    return responses[randomCalls++];
  }
}

class _RandomFakeAdapter implements GallerySourceAdapter {
  _RandomFakeAdapter(this.batches);

  final List<List<GalleryItem>> batches;
  int randomCalls = 0;
  int searchCalls = 0;
  GalleryRandomRequest? lastRandomRequest;

  @override
  GallerySourceId get sourceId => GallerySourceId.danbooru;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  @override
  Random get randomGenerator => Random(1);

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    searchCalls++;
    return GalleryPage(
      items: [_item(100)],
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      rawItemCount: 1,
    );
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) => search(
    GallerySearchRequest(cursor: request.cursor, pageSize: request.pageSize),
    cancelToken: cancelToken,
  );

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    lastRandomRequest = request;
    final index = randomCalls++;
    return _page(index < batches.length ? batches[index] : const []);
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async => GalleryDetail(item: item, media: [item.cover]);
}

class _FavoriteQuickTagCloudAdapter extends QuickTagCloudGallerySourceAdapter {
  _FavoriteQuickTagCloudAdapter(LocalStorageService storage)
    : super(
        catalogService: QuickTagCloudRemoteCatalogService(),
        userService: QuickTagCloudUserService(storage),
        queryReader: () => const QuickTagCloudGalleryQuery(),
      );

  int detailCalls = 0;

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailCalls++;
    return GalleryDetail(item: item, media: [item.cover]);
  }
}

class _QueryRecordingAdapter extends GallerySourceAdapter {
  _QueryRecordingAdapter(this.sourceId, {this.randomItems = const []});

  @override
  final GallerySourceId sourceId;
  final List<GalleryItem> randomItems;

  GallerySearchRequest? lastSearchRequest;
  GalleryRandomRequest? lastRandomRequest;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    lastSearchRequest = request;
    return _page(const []);
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    lastRandomRequest = request;
    return _page(randomItems);
  }
}

class _EmptyAdapter implements GallerySourceAdapter {
  const _EmptyAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  @override
  Random get randomGenerator => Random(1);

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const []);

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const []);

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const []);

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async => GalleryDetail(item: item, media: [item.cover]);
}
