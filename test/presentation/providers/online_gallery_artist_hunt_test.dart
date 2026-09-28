import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normal AI TAG feed keeps one card per work', () async {
    final adapter = _ArtistHuntAdapter(
      candidates: [_item(1), _item(1), _item(2)],
      details: const {},
    );
    final container = _container(adapter);
    addTearDown(container.dispose);

    await container
        .read(onlineGalleryNotifierProvider.notifier)
        .setSource(GallerySourceId.aiTag);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.stableKey), ['ai_tag:1', 'ai_tag:2']);
  });

  test(
    'filters false positives and keeps one representative image per work',
    () async {
      final adapter = _ArtistHuntAdapter(
        candidates: [_item(1), _item(2)],
        details: {
          1: _detail(1, const [
            'artist: alpha',
            'scenery, 1.2::artist: beta::',
          ]),
          2: _detail(2, const ['by famous artist, artist collaboration']),
        },
      );
      final container = _container(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.aiTag);
      notifier.saveScrollOffset(42);
      await notifier.setArtistHuntEnabled(true);

      var state = container.read(onlineGalleryNotifierProvider);
      expect(adapter.searchPrompts, ['', 'artist:']);
      expect(state.posts, hasLength(1));
      expect(state.posts.single.stableKey, 'ai_tag:1');
      expect(state.posts.single.cover.prompt, 'artist: alpha');
      expect(state.posts.single.artistChain!.formattedText, 'artist:alpha');
      expect(adapter.detailCalls, {1: 1, 2: 1});

      notifier.saveScrollOffset(84);
      await notifier.setArtistHuntEnabled(false);
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts.map((item) => item.id), [1, 2]);
      expect(state.scrollOffset, 42);

      await notifier.setArtistHuntEnabled(true);
      state = container.read(onlineGalleryNotifierProvider);
      expect(state.posts, hasLength(1));
      expect(state.scrollOffset, 84);
      expect(adapter.searchPrompts, ['', 'artist:']);
    },
  );

  test('deduplicates works by normalized Prompt and artist chain', () async {
    final adapter = _ArtistHuntAdapter(
      candidates: [_item(1), _item(2), _item(3)],
      details: {
        1: _detail(1, const [
          '1girl, artist: Alpha',
          '  1GIRL , ARTIST : alpha  ',
          'landscape, artist:alpha',
        ]),
        2: _detail(2, const ['1girl, artist:alpha']),
        3: _detail(3, const ['1girl, {artist:alpha}']),
      },
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    await notifier.setArtistHuntEnabled(true);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.stableKey), ['ai_tag:1', 'ai_tag:3']);
    expect(state.currentCache.artistHuntCandidateCount, 3);
    expect(state.currentCache.artistHuntResolvedCount, 3);
  });

  test('limits detail concurrency and publishes completed batches', () async {
    final candidates = [for (var id = 1; id <= 6; id++) _item(id)];
    final adapter = _ArtistHuntAdapter(
      candidates: candidates,
      details: {
        for (var id = 1; id <= 6; id++) id: _detail(id, ['artist: artist_$id']),
      },
      detailDelay: const Duration(milliseconds: 15),
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    final observedLengths = <int>[];
    final subscription = container.listen(
      onlineGalleryNotifierProvider.select((state) => state.posts.length),
      (_, next) => observedLengths.add(next),
    );
    addTearDown(subscription.close);

    await notifier.setArtistHuntEnabled(true);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(adapter.maxActiveDetails, lessThanOrEqualTo(4));
    expect(observedLengths, contains(4));
    expect(state.posts, hasLength(6));
    expect(state.currentCache.artistHuntResolvedCount, 6);
    expect(state.currentCache.artistHuntFailureCount, 0);
  });

  test('keeps partial results visible and retries failed details', () async {
    final adapter = _ArtistHuntAdapter(
      candidates: [_item(1), _item(2)],
      details: {
        1: _detail(1, const ['artist: alpha']),
        2: _detail(2, const ['artist: beta']),
      },
      failingIds: {2},
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    await notifier.setArtistHuntEnabled(true);

    var state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.single.id, 1);
    expect(state.currentCache.artistHuntFailureCount, 1);
    expect(state.hasError, isFalse);

    adapter.failingIds.clear();
    await notifier.refresh();
    state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts.map((item) => item.id), [1, 2]);
    expect(state.currentCache.artistHuntFailureCount, 0);
    expect(adapter.detailCalls[1], 1, reason: 'successful detail stays cached');
    expect(adapter.detailCalls[2], 2, reason: 'failed detail is fetched again');
  });

  test(
    'random mode keeps the artist constraint and work-level output',
    () async {
      final adapter = _ArtistHuntAdapter(
        candidates: [_item(1), _item(2)],
        details: {
          1: _detail(1, const ['artist: alpha', 'plain scenery']),
          2: _detail(2, const [' ARTIST : ALPHA ']),
        },
      );
      final container = _container(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.setArtistHuntEnabled(true);
      await notifier.setRandomEnabled(true);

      final request =
          adapter.randomRequests.single as GalleryRandomSearchRequest;
      final state = container.read(onlineGalleryNotifierProvider);
      expect(request.prompt, 'artist:');
      expect(state.randomEnabled, isTrue);
      expect(state.posts.single.stableKey, 'ai_tag:1');
      expect(state.posts.single.artistChain!.formattedText, 'artist:alpha');
    },
  );

  test('reports an explicit error when every candidate detail fails', () async {
    final adapter = _ArtistHuntAdapter(
      candidates: [_item(1), _item(2)],
      details: const {},
      failingIds: {1, 2},
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    await notifier.setArtistHuntEnabled(true);

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.posts, isEmpty);
    expect(state.hasError, isTrue);
    expect(state.errorCode, OnlineGalleryErrorCode.artistHuntDetailFailed);
  });

  test('late detail results cannot enter a disabled hunt cache', () async {
    final pending = Completer<GalleryDetail>();
    final adapter = _ArtistHuntAdapter(
      candidates: [_item(1)],
      details: const {},
      pendingDetails: {1: pending},
    );
    final container = _container(adapter);
    addTearDown(container.dispose);
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);

    await notifier.setSource(GallerySourceId.aiTag);
    final huntLoad = notifier.setArtistHuntEnabled(true);
    await Future<void>.delayed(Duration.zero);
    await notifier.setArtistHuntEnabled(false);
    pending.complete(_detail(1, const ['artist: too_late']));
    await huntLoad;

    final state = container.read(onlineGalleryNotifierProvider);
    expect(state.artistHuntEnabled, isFalse);
    expect(state.posts.single.stableKey, 'ai_tag:1');
  });

  test(
    'popular and page jumps use the same implicit artist constraint',
    () async {
      final adapter = _ArtistHuntAdapter(
        candidates: [_item(1)],
        details: {
          1: _detail(1, const ['artist: alpha']),
        },
      );
      final container = _container(adapter);
      addTearDown(container.dispose);
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);

      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.setArtistHuntEnabled(true);
      await notifier.switchToPopular();
      await notifier.setPopularSource(GallerySourceId.aiTag);
      await notifier.goToPage(5);

      expect(adapter.rankingPrompts, ['artist:', 'artist:']);
      expect(adapter.rankingCursors, ['1', '5']);
    },
  );
}

ProviderContainer _container(_ArtistHuntAdapter aiTag) {
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        for (final source in GallerySourceId.values)
          source: source == GallerySourceId.aiTag
              ? aiTag
              : _EmptyAdapter(source),
      }),
    ],
  );
}

GalleryItem _item(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.aiTag,
  cover: GalleryMedia(
    id: '$id:cover',
    previewUrl: 'https://example.test/$id-cover.webp',
    displayUrl: 'https://example.test/$id-cover.webp',
    downloadUrl: 'https://example.test/$id-cover.webp',
  ),
);

GalleryDetail _detail(int id, List<String> prompts) {
  final item = _item(id);
  final media = [
    for (var index = 0; index < prompts.length; index++)
      GalleryMedia(
        id: '$id:$index',
        previewUrl: 'https://example.test/$id-$index-preview.webp',
        displayUrl: 'https://example.test/$id-$index.webp',
        downloadUrl: 'https://example.test/$id-$index.webp',
        prompt: prompts[index],
      ),
  ];
  return GalleryDetail(item: item, media: media);
}

GalleryPage _page(List<GalleryItem> items, String cursor) => GalleryPage(
  items: items,
  cursor: cursor,
  nextCursor: null,
  hasMore: false,
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

class _ArtistHuntAdapter implements GallerySourceAdapter {
  _ArtistHuntAdapter({
    required this.candidates,
    required this.details,
    this.detailDelay = Duration.zero,
    Set<int>? failingIds,
    Map<int, Completer<GalleryDetail>>? pendingDetails,
  }) : failingIds = failingIds ?? <int>{},
       pendingDetails = pendingDetails ?? <int, Completer<GalleryDetail>>{};

  final List<GalleryItem> candidates;
  final Map<int, GalleryDetail> details;
  final Duration detailDelay;
  final Set<int> failingIds;
  final Map<int, Completer<GalleryDetail>> pendingDetails;
  final List<String?> searchPrompts = [];
  final List<String> searchCursors = [];
  final List<String?> rankingPrompts = [];
  final List<String> rankingCursors = [];
  final List<GalleryRandomRequest> randomRequests = [];
  final Map<int, int> detailCalls = {};
  int activeDetails = 0;
  int maxActiveDetails = 0;

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

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
    searchPrompts.add(request.prompt);
    searchCursors.add(request.cursor);
    return _page(candidates, request.cursor);
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async {
    rankingPrompts.add(request.prompt);
    rankingCursors.add(request.cursor);
    return _page(candidates, request.cursor);
  }

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async {
    randomRequests.add(request);
    return _page(candidates, 'random');
  }

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailCalls.update(item.id, (value) => value + 1, ifAbsent: () => 1);
    activeDetails++;
    if (activeDetails > maxActiveDetails) maxActiveDetails = activeDetails;
    try {
      final pending = pendingDetails[item.id];
      if (pending != null) return await pending.future;
      if (detailDelay > Duration.zero) await Future<void>.delayed(detailDelay);
      if (failingIds.contains(item.id)) throw StateError('detail ${item.id}');
      return details[item.id]!;
    } finally {
      activeDetails--;
    }
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
  }) async => _page(const [], request.cursor);

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const [], request.cursor);

  @override
  Future<GalleryPage> random(
    GalleryRandomRequest request, {
    CancelToken? cancelToken,
  }) async => _page(const [], 'random');

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async => GalleryDetail(item: item, media: [item.cover]);
}
