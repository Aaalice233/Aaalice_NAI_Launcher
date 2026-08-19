import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'first load requests page 1, append advances and de-duplicates IDs',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          return switch (request.cursor) {
            '1' => _page(request.cursor, [_item(1), _item(2)], nextCursor: '2'),
            '2' => _page(request.cursor, [_item(2), _item(3)], nextCursor: '3'),
            _ => _page(request.cursor, const [], nextCursor: null),
          };
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.loadMore();

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '2']);
      expect(state.posts.map((item) => item.id), [1, 2, 3]);
      expect(state.page, 2);
      expect(state.currentCache.nextCursor, '3');
      expect(state.isLoadingMore, isFalse);
    },
  );

  test(
    'popular ranking advances from page 1 to page 2 without rendering page 1 again',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async => request.cursor == '1'
            ? _page(request.cursor, [_item(101)], nextCursor: '2')
            : _page(request.cursor, [_item(202)], nextCursor: '3'),
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.switchToPopular();
      await notifier.loadMore();

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '2']);
      expect(state.posts.map((item) => item.id), [101, 202]);
      expect(state.posts.map((item) => item.stableKey).toSet(), hasLength(2));
    },
  );

  test('a wholly repeated upstream page stops infinite loading', () async {
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async => request.cursor == '1'
          ? _page(request.cursor, [_item(1), _item(2)], nextCursor: '2')
          : _page(request.cursor, [_item(1), _item(2)], nextCursor: '3'),
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.loadPosts();
    await notifier.loadMore();
    await notifier.loadMore();

    final cache = container.read(onlineGalleryNotifierProvider).currentCache;
    expect(adapter.searchCursors, ['1', '2']);
    expect(cache.posts.map((item) => item.id), [1, 2]);
    expect(cache.hasMore, isFalse);
    expect(cache.nextCursor, isNull);
    expect(cache.endedByDuplicatePage, isTrue);
  });

  test(
    'total and explicit next cursor win over a short response page',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async => GalleryPage(
          items: [_item(1)],
          cursor: request.cursor,
          nextCursor: '2',
          total: 120,
          hasMore: true,
          rawItemCount: 1,
        ),
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);

      await container.read(onlineGalleryNotifierProvider.notifier).loadPosts();

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.currentCache.total, 120);
      expect(state.hasMore, isTrue);
      expect(state.currentCache.nextCursor, '2');
    },
  );

  test(
    'jumping to a page requests that page and replaces the visible page',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(int.parse(request.cursor)),
        ], nextCursor: '${int.parse(request.cursor) + 1}'),
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.goToPage(5);

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '5']);
      expect(state.posts.single.id, 5);
      expect(state.page, 5);
    },
  );

  test(
    'source caches are isolated and restored without a repeated request',
    () async {
      final danbooru = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async =>
            _page(request.cursor, [_item(11)], nextCursor: null),
      );
      final safebooru = _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(22, source: GallerySourceId.safebooru),
        ], nextCursor: null),
      );
      final container = _container(danbooru: danbooru, safebooru: safebooru);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.setSource(GallerySourceId.safebooru);
      expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 22);
      await notifier.setSource(GallerySourceId.danbooru);

      expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 11);
      expect(danbooru.searchCursors, ['1']);
      expect(safebooru.searchCursors, ['1']);
    },
  );

  test(
    'switching to a cached source clears loading from the cancelled request',
    () async {
      final pendingRefresh = Completer<GalleryPage>();
      var danbooruRequests = 0;
      final danbooru = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) {
          danbooruRequests++;
          if (danbooruRequests == 1) {
            return Future.value(
              _page(request.cursor, [_item(11)], nextCursor: null),
            );
          }
          return pendingRefresh.future;
        },
      );
      final safebooru = _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(22, source: GallerySourceId.safebooru),
        ], nextCursor: null),
      );
      final container = _container(danbooru: danbooru, safebooru: safebooru);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.setSource(GallerySourceId.safebooru);
      await notifier.setSource(GallerySourceId.danbooru);
      final refresh = notifier.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(onlineGalleryNotifierProvider).isLoading, isTrue);

      await notifier.setSource(GallerySourceId.safebooru);

      var state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.single.id, 22);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      pendingRefresh.complete(_page('1', [_item(99)], nextCursor: null));
      await refresh;
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.single.id, 22);
      expect(state.isLoading, isFalse);
    },
  );

  test('filtered empty Danbooru cursors advance the visible page', () async {
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async {
        return switch (request.cursor) {
          '1' => _page(
            request.cursor,
            const [],
            nextCursor: 'b900',
            rawItemCount: 40,
          ),
          'b900' => _page(request.cursor, [_item(2)], nextCursor: 'b800'),
          'b800' => _page(request.cursor, [_item(3)], nextCursor: 'b700'),
          _ => _page(request.cursor, const [], nextCursor: null),
        };
      },
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);

    await container.read(onlineGalleryNotifierProvider.notifier).loadPosts();

    var state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors, ['1', 'b900']);
    expect(state.posts.single.id, 2);
    expect(state.page, 2);
    expect(state.currentCache.nextCursor, 'b800');
    expect(state.hasMore, isTrue);
    expect(state.currentCache.endedByDuplicatePage, isFalse);

    await container.read(onlineGalleryNotifierProvider.notifier).loadMore();

    state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors, ['1', 'b900', 'b800']);
    expect(state.posts.map((item) => item.id), [2, 3]);
    expect(state.page, 3);
    expect(state.currentCache.nextCursor, 'b700');
  });

  test('continues after a full batch of filtered empty cursors', () async {
    const nextCursorByCursor = {
      '1': 'b900',
      'b900': 'b800',
      'b800': 'b700',
      'b700': 'b600',
      'b600': 'b500',
    };
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async {
        if (request.cursor == 'b500') {
          return _page(request.cursor, [_item(6)], nextCursor: 'b400');
        }
        return _page(
          request.cursor,
          const [],
          nextCursor: nextCursorByCursor[request.cursor],
          rawItemCount: 40,
        );
      },
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.loadPosts();

    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, isEmpty);
    expect(state.page, 5);
    expect(state.currentCache.nextCursor, 'b500');
    expect(state.hasMore, isTrue);

    await notifier.loadMore();

    state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors.last, 'b500');
    expect(state.posts.single.id, 6);
    expect(state.page, 6);
    expect(state.currentCache.nextCursor, 'b400');
  });

  test(
    'late results from a cancelled source cannot overwrite the new source',
    () async {
      final latePage = Completer<GalleryPage>();
      final danbooru = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (_, __) => latePage.future,
      );
      final safebooru = _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(22, source: GallerySourceId.safebooru),
        ], nextCursor: null),
      );
      final container = _container(danbooru: danbooru, safebooru: safebooru);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final oldRequest = notifier.loadPosts();
      await Future<void>.delayed(Duration.zero);
      await notifier.setSource(GallerySourceId.safebooru);
      latePage.complete(_page('1', [_item(99)], nextCursor: null));
      await oldRequest;

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.sourceId, GallerySourceId.safebooru);
      expect(state.posts.single.id, 22);
    },
  );

  test(
    'append failure retains existing posts and can retry in place',
    () async {
      var pageTwoAttempts = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          if (request.cursor == '1') {
            return _page(request.cursor, [_item(1)], nextCursor: '2');
          }
          pageTwoAttempts++;
          if (pageTwoAttempts == 1) {
            throw const GallerySourceException(
              GallerySourceErrorCode.network,
              source: GallerySourceId.danbooru,
            );
          }
          return _page(request.cursor, [_item(2)], nextCursor: null);
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.loadMore();
      var state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.single.id, 1);
      expect(
        state.currentCache.appendErrorCode,
        OnlineGalleryErrorCode.network,
      );

      await notifier.retryAppend();
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2]);
      expect(state.currentCache.appendErrorCode, isNull);
    },
  );
}

ProviderContainer _container({
  required _FakeGalleryAdapter danbooru,
  _FakeGalleryAdapter? safebooru,
}) {
  final safe =
      safebooru ??
      _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
      );
  final gelbooru = _FakeGalleryAdapter(
    GallerySourceId.gelbooru,
    onSearch: (request, _) async =>
        _page(request.cursor, const [], nextCursor: null),
  );
  final aiTag = _FakeGalleryAdapter(
    GallerySourceId.aiTag,
    onSearch: (request, _) async =>
        _page(request.cursor, const [], nextCursor: null),
  );
  return ProviderContainer(
    overrides: [
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        GallerySourceId.danbooru: danbooru,
        GallerySourceId.safebooru: safe,
        GallerySourceId.gelbooru: gelbooru,
        GallerySourceId.aiTag: aiTag,
      }),
    ],
  );
}

GalleryPage _page(
  String cursor,
  List<GalleryItem> items, {
  required String? nextCursor,
  int? rawItemCount,
}) {
  return GalleryPage(
    items: items,
    cursor: cursor,
    nextCursor: nextCursor,
    hasMore: nextCursor != null,
    rawItemCount: rawItemCount ?? items.length,
  );
}

GalleryItem _item(int id, {GallerySourceId source = GallerySourceId.danbooru}) {
  return GalleryItem(
    id: id,
    sourceId: source,
    createdAt: '2026-08-09',
    uploaderId: 1,
    width: 768,
    height: 1024,
    rating: 'g',
    tags: const ['1girl'],
    cover: GalleryMedia(
      id: '$id',
      previewUrl: 'https://example.test/${source.key}/$id-preview.webp',
      displayUrl: 'https://example.test/${source.key}/$id.webp',
      downloadUrl: 'https://example.test/${source.key}/$id.webp',
      width: 768,
      height: 1024,
      extension: 'webp',
    ),
  );
}

class _FakeGalleryAdapter implements GallerySourceAdapter {
  _FakeGalleryAdapter(this.sourceId, {required this.onSearch});

  @override
  final GallerySourceId sourceId;
  final Future<GalleryPage> Function(
    GallerySearchRequest request,
    CancelToken? cancelToken,
  )
  onSearch;
  final List<String> searchCursors = [];

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) {
    searchCursors.add(request.cursor);
    return onSearch(request, cancelToken);
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) {
    return search(
      GallerySearchRequest(cursor: request.cursor, pageSize: request.pageSize),
      cancelToken: cancelToken,
    );
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    return GalleryDetail(item: item, media: [item.cover]);
  }
}
