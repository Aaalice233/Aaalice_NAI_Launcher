import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_blacklist_provider.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
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

  test('blacklisted results never consume random seen keys', () async {
    final blocked = GalleryItem(
      id: 8,
      sourceId: GallerySourceId.danbooru,
      tags: const ['blocked_tag'],
      cover: const GalleryMedia(
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
}

ProviderContainer _container(_RandomFakeAdapter danbooru) {
  final adapters = <GallerySourceId, GallerySourceAdapter>{
    GallerySourceId.danbooru: danbooru,
    for (final source in GallerySourceId.values)
      if (source != GallerySourceId.danbooru) source: _EmptyAdapter(source),
  };
  return ProviderContainer(
    overrides: [
      onlineGallerySourceAdaptersProvider.overrideWithValue(adapters),
    ],
  );
}

GalleryItem _item(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.danbooru,
  tags: const ['1girl'],
  cover: GalleryMedia(
    id: '$id',
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
