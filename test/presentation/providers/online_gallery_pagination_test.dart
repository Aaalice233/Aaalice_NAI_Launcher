import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/online_gallery_detail_coordinator.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/danbooru/danbooru_user.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/danbooru_auth_service.dart';
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
      expect(adapter.searchPageSizes, [60, 60]);
      expect(state.posts.map((item) => item.id), [1, 2, 3]);
      expect(state.page, 2);
      expect(state.currentCache.nextCursor, '3');
      expect(state.isLoadingMore, isFalse);
    },
  );

  test(
    'background pause cancels and automatically resumes page traffic',
    () async {
      final started = Completer<void>();
      var calls = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, cancelToken) async {
          calls++;
          if (calls == 1) {
            started.complete();
            throw await cancelToken!.whenCancel;
          }
          return _page(request.cursor, [_item(1)], nextCursor: null);
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final active = notifier.loadPosts();
      await started.future;
      notifier.setBackgroundNetworkPaused(true);
      await active;
      expect(container.read(onlineGalleryNotifierProvider).isLoading, isFalse);

      await notifier.loadPosts();
      expect(calls, 1);

      notifier.setBackgroundNetworkPaused(false);
      await _waitUntil(
        () =>
            calls == 2 &&
            container.read(onlineGalleryNotifierProvider).posts.length == 1,
      );
      expect(calls, 2);
      expect(container.read(onlineGalleryNotifierProvider).posts, hasLength(1));
    },
  );

  test(
    'background pause resumes an interrupted append from the same cursor',
    () async {
      final appendStarted = Completer<void>();
      var appendCalls = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, cancelToken) async {
          if (request.cursor == '1') {
            return _page('1', [_item(1)], nextCursor: '2');
          }
          appendCalls++;
          if (appendCalls == 1) {
            appendStarted.complete();
            throw await cancelToken!.whenCancel;
          }
          return _page('2', [_item(2)], nextCursor: null);
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);
      await notifier.loadPosts();

      final append = notifier.loadMore();
      await appendStarted.future;
      notifier.setBackgroundNetworkPaused(true);
      await append;
      notifier.setBackgroundNetworkPaused(false);

      await _waitUntil(
        () => container.read(onlineGalleryNotifierProvider).posts.length == 2,
      );
      expect(adapter.searchCursors, ['1', '2', '2']);
      expect(container.read(onlineGalleryNotifierProvider).page, 2);
    },
  );

  test(
    'concurrent load-more triggers claim one append synchronously',
    () async {
      final secondPage = Completer<GalleryPage>();
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) => request.cursor == '1'
            ? Future.value(_page('1', [_item(1)], nextCursor: '2'))
            : secondPage.future,
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);
      await notifier.loadPosts();

      final first = notifier.loadMore();
      final duplicate = notifier.loadMore();
      final underfillDuplicate = notifier.loadMore();

      expect(
        container.read(onlineGalleryNotifierProvider).isLoadingMore,
        isTrue,
      );
      await Future<void>.delayed(Duration.zero);
      expect(adapter.searchCursors, ['1', '2']);

      secondPage.complete(_page('2', [_item(2)], nextCursor: null));
      await Future.wait([first, duplicate, underfillDuplicate]);

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2]);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isFalse);
      await notifier.loadMore();
      expect(adapter.searchCursors, ['1', '2']);
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

  test(
    'popular ranking validates a query that the ranking feed ignores',
    () async {
      var requestCount = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          requestCount++;
          return switch (requestCount) {
            1 => _page(request.cursor, const [], nextCursor: null),
            2 => _page(request.cursor, [
              _item(1, tags: const ['other']),
            ], nextCursor: '2'),
            _ => _page(request.cursor, [
              _item(2, tags: const ['target']),
            ], nextCursor: null),
          };
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.switchToPopular();
      await notifier.searchPopular(query: 'target', prompt: '');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '1', '2']);
      expect(state.posts.map((item) => item.id), [2]);
      expect(state.hasMore, isFalse);
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

  test(
    'continues through filtered empty cursors until content arrives',
    () async {
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

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, [
        '1',
        'b900',
        'b800',
        'b700',
        'b600',
        'b500',
      ]);
      expect(state.posts.single.id, 6);
      expect(state.page, 6);
      expect(state.currentCache.nextCursor, 'b400');
      expect(state.hasMore, isTrue);
    },
  );

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

  test('failed initial load is not retried by load-more triggers', () async {
    var attempts = 0;
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (_, __) async {
        attempts++;
        throw const GallerySourceException(
          GallerySourceErrorCode.detailNotFound,
          source: GallerySourceId.danbooru,
        );
      },
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.loadPosts();
    await notifier.loadMore();
    await notifier.loadMore();

    expect(attempts, 1);
    expect(
      container.read(onlineGalleryNotifierProvider).errorCode,
      OnlineGalleryErrorCode.detailNotFound,
    );

    await notifier.refresh();
    expect(attempts, 2);
  });

  test(
    'a single residual negative clause is always filtered locally',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(1, tags: const ['a', 'b', 'blocked']),
          _item(2, tags: const ['a', 'b']),
        ], nextCursor: null),
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);

      await container
          .read(onlineGalleryNotifierProvider.notifier)
          .search('a b -blocked');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchQueries.single, 'a b');
      expect(state.posts.map((item) => item.id), [2]);
    },
  );

  test(
    'six-tag residual filtering consumes empty pages until matching work arrives',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          return switch (request.cursor) {
            '1' => _page('1', [
              _item(1, tags: const ['a', 'b', 'c']),
              _item(2, tags: const ['a', 'b', 'd']),
            ], nextCursor: '2'),
            '2' => _page('2', [
              _item(3, tags: const ['a', 'b', 'c', 'd', 'e', 'f']),
            ], nextCursor: '3'),
            _ => _page('3', const [], nextCursor: null),
          };
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);

      await container
          .read(onlineGalleryNotifierProvider.notifier)
          .search('a b c d e f');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '2', '3']);
      expect(adapter.searchQueries.toSet(), {'a b'});
      expect(state.posts.map((item) => item.id), [3]);
      expect(state.currentCache.queryRequestCount, 3);
      expect(state.currentCache.queryCandidateCount, 3);
      expect(state.hasMore, isFalse);
    },
  );

  test(
    'residual scans pause at the page budget and resume from the cursor',
    () async {
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          final page = int.parse(request.cursor);
          return _page(request.cursor, [
            _item(
              page,
              tags: page == 9 ? const ['a', 'b', 'c'] : const ['a', 'b'],
            ),
          ], nextCursor: page < 9 ? '${page + 1}' : null);
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.search('a b c');
      var state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, [
        for (var page = 1; page <= 8; page++) '$page',
      ]);
      expect(state.posts, isEmpty);
      expect(state.hasMore, isTrue);
      expect(state.currentCache.nextCursor, '9');
      expect(state.currentCache.queryScanPaused, isTrue);

      await notifier.loadMore();
      state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors.last, '9');
      expect(state.posts.single.id, 9);
      expect(state.hasMore, isFalse);
      expect(state.currentCache.queryScanPaused, isFalse);
    },
  );

  test('raw-page repetition is detected across scan-budget resumes', () async {
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async {
        final page = int.parse(request.cursor);
        return _page(
          request.cursor,
          [
            _item(page, tags: const ['a', 'b']),
          ],
          nextCursor: '${page + 1}',
          rawPageIdentity: page <= 8 ? 'raw-$page' : 'raw-8',
        );
      },
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.search('a b c');
    expect(
      container
          .read(onlineGalleryNotifierProvider)
          .currentCache
          .queryScanPaused,
      isTrue,
    );

    await notifier.loadMore();
    final state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors, [
      for (var page = 1; page <= 9; page++) '$page',
    ]);
    expect(state.currentCache.endedByDuplicatePage, isTrue);
    expect(state.hasMore, isFalse);
  });

  test('advancing cursors with the same raw page terminate the scan', () async {
    final repeated = _item(1, tags: const ['a', 'b']);
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async => _page(request.cursor, [
        repeated,
      ], nextCursor: request.cursor == '1' ? '2' : '3'),
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .search('a b c');

    final state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors, ['1', '2']);
    expect(state.posts, isEmpty);
    expect(state.currentCache.endedByDuplicatePage, isTrue);
    expect(state.hasMore, isFalse);
  });

  test(
    'different raw pages are not collapsed after adapter filtering',
    () async {
      final repeatedVisible = _item(1, tags: const ['a', 'b']);
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          if (request.cursor == '3') {
            return _page(
              request.cursor,
              [
                _item(3, tags: const ['a', 'b', 'c']),
              ],
              nextCursor: null,
              rawPageIdentity: 'raw-3',
            );
          }
          return _page(
            request.cursor,
            [repeatedVisible],
            nextCursor: request.cursor == '1' ? '2' : '3',
            rawPageIdentity: 'raw-${request.cursor}',
          );
        },
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);

      await container
          .read(onlineGalleryNotifierProvider.notifier)
          .search('a b c');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchCursors, ['1', '2', '3']);
      expect(state.posts.single.id, 3);
      expect(state.currentCache.endedByDuplicatePage, isFalse);
    },
  );

  test(
    'incomplete list tags are completed by detail before matching',
    () async {
      final incomplete = _item(8, tags: const ['a'], tagsComplete: false);
      final complete = _item(8, tags: const ['a', 'b', 'c']);
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async =>
            _page(request.cursor, [incomplete], nextCursor: null),
        onDetail: (item, _) async =>
            GalleryDetail(item: complete, media: [complete.cover]),
      );
      final container = _container(danbooru: adapter);
      addTearDown(container.dispose);

      await container
          .read(onlineGalleryNotifierProvider.notifier)
          .search('a b c');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.detailRequests, 1);
      expect(state.posts.map((item) => item.id), [8]);
      expect(state.notice, isNull);
    },
  );

  test(
    'source changes let active tag detail completion finish stale',
    () async {
      final pendingDetail = Completer<GalleryDetail>();
      CancelToken? detailCancelToken;
      final incomplete = _item(8, tags: const ['a'], tagsComplete: false);
      final danbooru = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async =>
            _page(request.cursor, [incomplete], nextCursor: null),
        onDetail: (item, cancelToken) {
          detailCancelToken = cancelToken;
          return pendingDetail.future;
        },
      );
      final safebooru = _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(
            22,
            source: GallerySourceId.safebooru,
            tags: const ['a', 'b', 'c'],
          ),
        ], nextCursor: null),
      );
      final container = _container(danbooru: danbooru, safebooru: safebooru);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      final staleSearch = notifier.search('a b c');
      await _waitUntil(() => danbooru.detailRequests > 0);
      await notifier.setSource(GallerySourceId.safebooru);

      expect(detailCancelToken?.isCancelled, isFalse);
      pendingDetail.complete(
        GalleryDetail(item: incomplete, media: [incomplete.cover]),
      );
      await staleSearch;
      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.sourceId, GallerySourceId.safebooru);
      expect(state.posts.single.id, 22);
    },
  );

  test('AI TAG keeps source-native terms and skips Danbooru aliases', () async {
    var metadataLoads = 0;
    final danbooru = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async =>
          _page(request.cursor, const [], nextCursor: null),
    );
    final aiTag = _FakeGalleryAdapter(
      GallerySourceId.aiTag,
      onSearch: (request, _) async => _page(
        request.cursor,
        request.query.isEmpty
            ? const []
            : [
                _item(
                  30,
                  source: GallerySourceId.aiTag,
                  tags: const ['kitty'],
                  tagsComplete: false,
                ),
              ],
        nextCursor: null,
      ),
      onDetail: (item, _) async {
        final complete = item.copyWith(
          searchTerms: const ['kitty', 'Alice', 'portrait'],
          tagsComplete: true,
        );
        return GalleryDetail(item: complete, media: [complete.cover]);
      },
    );
    final container = _container(
      danbooru: danbooru,
      aiTag: aiTag,
      metadataLoader: (terms) async {
        metadataLoads++;
        return const {};
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    await notifier.search('alice');

    expect(metadataLoads, 0);
    expect(aiTag.searchQueries.last, 'alice');
    expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 30);
  });

  test('unsupported metatags fail before issuing a source request', () async {
    final danbooru = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async =>
          _page(request.cursor, const [], nextCursor: null),
    );
    final aiTag = _FakeGalleryAdapter(
      GallerySourceId.aiTag,
      onSearch: (request, _) async =>
          _page(request.cursor, const [], nextCursor: null),
    );
    final container = _container(danbooru: danbooru, aiTag: aiTag);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    final aiRequests = aiTag.searchQueries.length;
    await notifier.search('rating:g');
    var state = container.read(onlineGalleryNotifierProvider);
    expect(aiTag.searchQueries, hasLength(aiRequests));
    expect(state.errorCode, OnlineGalleryErrorCode.unsupportedMetatag);

    await notifier.setSource(GallerySourceId.danbooru);
    await notifier.switchToPopular();
    final rankingRequests = danbooru.searchQueries.length;
    await notifier.searchPopular(query: 'order:score', prompt: '');
    state = container.read(onlineGalleryNotifierProvider);
    expect(danbooru.searchQueries, hasLength(rankingRequests));
    expect(state.errorCode, OnlineGalleryErrorCode.unsupportedMetatag);
  });

  test(
    'Gelbooru accepts sort but rejects Danbooru-only order syntax',
    () async {
      final gelbooru = _FakeGalleryAdapter(
        GallerySourceId.gelbooru,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
      );
      final container = _container(
        danbooru: _emptyAdapter(GallerySourceId.danbooru),
        gelbooru: gelbooru,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.gelbooru);
      await notifier.search('a b c d e f sort:score:desc');
      expect(gelbooru.searchQueries.last, contains('sort:score:desc'));
      expect(container.read(onlineGalleryNotifierProvider).errorCode, isNull);

      final requestCount = gelbooru.searchQueries.length;
      await notifier.search('order:score');
      expect(gelbooru.searchQueries, hasLength(requestCount));
      expect(
        container.read(onlineGalleryNotifierProvider).errorCode,
        OnlineGalleryErrorCode.unsupportedMetatag,
      );
    },
  );

  test(
    'account changes invalidate source caches and reload active results',
    () async {
      var requestCount = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          requestCount++;
          return _page(request.cursor, [_item(requestCount)], nextCursor: null);
        },
      );
      final container = _container(
        danbooru: adapter,
        danbooruAuthBuilder: _MutableDanbooruAuth.new,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      final auth =
          container.read(danbooruAuthProvider.notifier) as _MutableDanbooruAuth;
      auth.authenticate(name: 'alice', level: 30);
      await _waitUntil(() => adapter.searchCursors.length >= 2);

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.danbooruAuthScope, 'alice:30:authenticated');
      expect(state.posts.single.id, 2);
      expect(
        state.caches.keys.where((key) => key.startsWith('search:danbooru:')),
        everyElement(contains('auth:alice:30:authenticated')),
      );
    },
  );

  test('account changes cancel an in-flight source request', () async {
    var requestCount = 0;
    CancelToken? firstToken;
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, cancelToken) async {
        requestCount++;
        if (requestCount == 1) {
          final token = cancelToken!;
          firstToken = token;
          await token.whenCancel;
          throw token.cancelError!;
        }
        return _page(request.cursor, [_item(2)], nextCursor: null);
      },
    );
    final container = _container(
      danbooru: adapter,
      danbooruAuthBuilder: _MutableDanbooruAuth.new,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    final firstLoad = notifier.loadPosts();
    await _waitUntil(() => firstToken != null);
    final auth =
        container.read(danbooruAuthProvider.notifier) as _MutableDanbooruAuth;
    auth.authenticate(name: 'alice', level: 30);
    await _waitUntil(() => requestCount >= 2);
    await firstLoad;

    expect(firstToken!.isCancelled, isTrue);
    expect(container.read(onlineGalleryNotifierProvider).posts.single.id, 2);
  });

  test(
    'authentication scopes isolate search but not unified favorites keys',
    () {
      const state = OnlineGalleryState(
        danbooruAuthScope: 'alice:20:authenticated',
        gelbooruAuthScope: '100:valid',
      );
      expect(state.currentCacheKey, contains('auth:alice:20:authenticated'));
      expect(
        state
            .copyWith(danbooruAuthScope: 'bob:30:authenticated')
            .currentCacheKey,
        isNot(state.currentCacheKey),
      );

      final unifiedFavorites = state.copyWith(
        viewMode: GalleryViewMode.favorites,
      );
      expect(
        unifiedFavorites.currentCacheKey,
        startsWith('favorites:danbooru|'),
      );
      expect(
        unifiedFavorites
            .copyWith(danbooruAuthScope: 'bob:30:authenticated')
            .currentCacheKey,
        unifiedFavorites.currentCacheKey,
      );
    },
  );

  test(
    'account changes during random mode cannot restore the old normal cache',
    () async {
      var requestCount = 0;
      final adapter = _FakeGalleryAdapter(
        GallerySourceId.danbooru,
        onSearch: (request, _) async {
          requestCount++;
          return _page(request.cursor, [_item(requestCount)], nextCursor: null);
        },
      );
      final container = _container(
        danbooru: adapter,
        danbooruAuthBuilder: _MutableDanbooruAuth.new,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.loadPosts();
      await notifier.setRandomEnabled(true);
      final auth =
          container.read(danbooruAuthProvider.notifier) as _MutableDanbooruAuth;
      auth.authenticate(name: 'alice', level: 30);
      await _waitUntil(() => requestCount >= 3);
      await notifier.setRandomEnabled(false);

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.randomEnabled, isFalse);
      expect(state.danbooruAuthScope, 'alice:30:authenticated');
      expect(state.posts.single.id, 4);
      expect(
        state.caches.keys.where((key) => key.startsWith('search:danbooru:')),
        everyElement(contains('auth:alice:30:authenticated')),
      );
    },
  );

  test('incomplete positive AI TAG terms avoid eager detail fan-out', () async {
    final aiTag = _FakeGalleryAdapter(
      GallerySourceId.aiTag,
      onSearch: (request, _) async => _page(request.cursor, [
        _item(
          1,
          source: GallerySourceId.aiTag,
          searchTerms: const ['blue'],
          tagsComplete: false,
        ),
      ], nextCursor: null),
    );
    final container = _container(
      danbooru: _emptyAdapter(GallerySourceId.danbooru),
      aiTag: aiTag,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    await notifier.search('blue');

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.single.id, 1);
    expect(aiTag.detailRequests, 0);
  });

  test(
    'incomplete AI TAG detail can prove a positive match without all media',
    () async {
      final aiTag = _FakeGalleryAdapter(
        GallerySourceId.aiTag,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(
            2,
            source: GallerySourceId.aiTag,
            tags: const [],
            tagsComplete: false,
          ),
        ], nextCursor: null),
        onDetail: (item, _) async => GalleryDetail(
          item: _item(
            2,
            source: GallerySourceId.aiTag,
            searchTerms: const ['blue'],
            tagsComplete: false,
          ),
          media: [item.cover],
        ),
      );
      final container = _container(
        danbooru: _emptyAdapter(GallerySourceId.danbooru),
        aiTag: aiTag,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.search('blue');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.single.id, 2);
      expect(state.currentCache.queryDetailFailureCount, 0);
      expect(aiTag.detailRequests, 1);
    },
  );

  test(
    'incomplete AI TAG detail cannot guess that a negative tag is absent',
    () async {
      final aiTag = _FakeGalleryAdapter(
        GallerySourceId.aiTag,
        onSearch: (request, _) async => _page(request.cursor, [
          _item(
            3,
            source: GallerySourceId.aiTag,
            searchTerms: const ['blue'],
            tagsComplete: false,
          ),
        ], nextCursor: null),
        onDetail: (item, _) async => GalleryDetail(
          item: _item(
            3,
            source: GallerySourceId.aiTag,
            searchTerms: const ['blue'],
            tagsComplete: false,
          ),
          media: [item.cover],
        ),
      );
      final container = _container(
        danbooru: _emptyAdapter(GallerySourceId.danbooru),
        aiTag: aiTag,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.search('blue -red');

      final state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts, isEmpty);
      expect(state.currentCache.queryDetailFailureCount, 1);
      expect(aiTag.detailRequests, 1);
    },
  );

  test('normalized tag cache does not outlive changed source tags', () async {
    var revised = false;
    final safebooru = _FakeGalleryAdapter(
      GallerySourceId.safebooru,
      onSearch: (request, _) async => _page(request.cursor, [
        _item(
          1,
          source: GallerySourceId.safebooru,
          tags: revised
              ? const ['cat', 'bird', 'fox']
              : const ['cat', 'dog', 'fox'],
        ),
      ], nextCursor: null),
    );
    final container = _container(
      danbooru: _emptyAdapter(GallerySourceId.danbooru),
      safebooru: safebooru,
    );
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.safebooru);
    await notifier.search('cat dog fox');
    expect(container.read(onlineGalleryNotifierProvider).posts, hasLength(1));

    revised = true;
    await notifier.refresh();
    expect(container.read(onlineGalleryNotifierProvider).posts, isEmpty);
  });

  test('a seventh tag fails before issuing an upstream request', () async {
    final adapter = _FakeGalleryAdapter(
      GallerySourceId.danbooru,
      onSearch: (request, _) async =>
          _page(request.cursor, const [], nextCursor: null),
    );
    final container = _container(danbooru: adapter);
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .search('a b c d e f g');

    final state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.searchCursors, isEmpty);
    expect(state.errorCode, OnlineGalleryErrorCode.tooManySearchTags);
  });

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

      await notifier.loadMore();
      await notifier.loadMore();
      expect(pageTwoAttempts, 1);

      await notifier.retryAppend();
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2]);
      expect(state.currentCache.appendErrorCode, isNull);
    },
  );

  test(
    'refresh advances detail scope and keeps cancelled queued details retryable',
    () async {
      final activeItems = List.generate(
        4,
        (index) => _item(91 + index, source: GallerySourceId.aiTag),
      );
      final activeGates = {
        for (final item in activeItems) item.id: Completer<GalleryDetail>(),
      };
      final queuedItem = _item(99, source: GallerySourceId.aiTag);
      final aiTag = _FakeGalleryAdapter(
        GallerySourceId.aiTag,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
        onDetail: (item, _) =>
            activeGates[item.id]?.future ??
            Future.value(GalleryDetail(item: item, media: [item.cover])),
      );
      final container = _container(
        danbooru: _emptyAdapter(GallerySourceId.danbooru),
        aiTag: aiTag,
      );
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);
      final initialScope = notifier.detailRequestScopeRevision;
      final active = [
        for (final item in activeItems)
          notifier.loadDetail(item, priority: GalleryDetailPriority.visible),
      ];
      final queued = notifier.loadDetail(
        queuedItem,
        priority: GalleryDetailPriority.visible,
      );
      final queuedCancellation = expectLater(
        queued,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      await notifier.refresh();
      await queuedCancellation;
      expect(notifier.detailRequestScopeRevision, initialScope + 1);
      expect(aiTag.detailRequests, 4);

      final afterRefresh = notifier.loadDetail(
        queuedItem,
        priority: GalleryDetailPriority.visible,
      );
      for (final item in activeItems) {
        activeGates[item.id]!.complete(
          GalleryDetail(item: item, media: [item.cover]),
        );
      }
      await Future.wait(active);
      expect((await afterRefresh).item.stableKey, queuedItem.stableKey);
      expect(aiTag.detailRequests, 5);
    },
  );
}

_FakeGalleryAdapter _emptyAdapter(GallerySourceId sourceId) =>
    _FakeGalleryAdapter(
      sourceId,
      onSearch: (request, _) async =>
          _page(request.cursor, const [], nextCursor: null),
    );

ProviderContainer _container({
  required _FakeGalleryAdapter danbooru,
  _FakeGalleryAdapter? safebooru,
  _FakeGalleryAdapter? gelbooru,
  _FakeGalleryAdapter? aiTag,
  GalleryTagMetadataLoader? metadataLoader,
  DanbooruAuth Function()? danbooruAuthBuilder,
}) {
  final safe =
      safebooru ??
      _FakeGalleryAdapter(
        GallerySourceId.safebooru,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
      );
  final gelbooruAdapter =
      gelbooru ??
      _FakeGalleryAdapter(
        GallerySourceId.gelbooru,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
      );
  final aiTagAdapter =
      aiTag ??
      _FakeGalleryAdapter(
        GallerySourceId.aiTag,
        onSearch: (request, _) async =>
            _page(request.cursor, const [], nextCursor: null),
      );
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
      if (danbooruAuthBuilder != null)
        danbooruAuthProvider.overrideWith(danbooruAuthBuilder),
      onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
        metadataLoader ?? (terms) async => const {},
      ),
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        GallerySourceId.danbooru: danbooru,
        GallerySourceId.safebooru: safe,
        GallerySourceId.gelbooru: gelbooruAdapter,
        GallerySourceId.aiTag: aiTagAdapter,
      }),
    ],
  );
}

class _MutableDanbooruAuth extends DanbooruAuth {
  @override
  DanbooruAuthState build() => const DanbooruAuthState();

  @override
  Future<void> ensureInitialized() async {}

  void authenticate({required String name, required int level}) {
    state = DanbooruAuthState(
      credentials: DanbooruCredentials(username: name, apiKey: 'test-key'),
      user: DanbooruUser(id: 1, name: name, level: level),
      lastVerifiedAt: DateTime.now(),
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

GalleryPage _page(
  String cursor,
  List<GalleryItem> items, {
  required String? nextCursor,
  int? rawItemCount,
  String? rawPageIdentity,
}) {
  return GalleryPage(
    items: items,
    cursor: cursor,
    nextCursor: nextCursor,
    hasMore: nextCursor != null,
    rawItemCount: rawItemCount ?? items.length,
    rawPageIdentity: rawPageIdentity,
  );
}

GalleryItem _item(
  int id, {
  GallerySourceId source = GallerySourceId.danbooru,
  List<String> tags = const ['1girl'],
  List<String> searchTerms = const [],
  bool tagsComplete = true,
}) {
  return GalleryItem(
    id: id,
    sourceId: source,
    createdAt: '2026-08-09',
    uploaderId: 1,
    width: 768,
    height: 1024,
    rating: 'g',
    tags: tags,
    searchTerms: searchTerms,
    tagsComplete: tagsComplete,
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

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected asynchronous condition was not reached');
}

class _FakeGalleryAdapter implements GallerySourceAdapter {
  _FakeGalleryAdapter(this.sourceId, {required this.onSearch, this.onDetail});

  @override
  final GallerySourceId sourceId;
  final Future<GalleryPage> Function(
    GallerySearchRequest request,
    CancelToken? cancelToken,
  )
  onSearch;
  final Future<GalleryDetail> Function(
    GalleryItem item,
    CancelToken? cancelToken,
  )?
  onDetail;
  final List<String> searchCursors = [];
  final List<int> searchPageSizes = [];
  final List<String> searchQueries = [];
  int detailRequests = 0;

  @override
  Random get randomGenerator => Random(1);

  @override
  GallerySourceCapabilities get capabilities =>
      gallerySourceCapabilities[sourceId]!;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) {
    searchCursors.add(request.cursor);
    searchPageSizes.add(request.pageSize);
    searchQueries.add(request.query);
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
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) {
    return search(
      GallerySearchRequest(cursor: '1', pageSize: request.pageSize),
      cancelToken: cancelToken,
    );
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailRequests++;
    final handler = onDetail;
    if (handler != null) return handler(item, cancelToken);
    return GalleryDetail(item: item, media: [item.cover]);
  }
}
