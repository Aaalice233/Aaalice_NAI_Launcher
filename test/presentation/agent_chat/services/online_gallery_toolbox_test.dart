import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;
  late List<AgentTool> tools;

  setUp(() {
    container = ProviderContainer();
    tools = OnlineGalleryToolbox(container.read(_refProvider)).tools();
  });

  tearDown(() => container.dispose());

  AgentTool tool(String name) => tools.singleWhere((tool) => tool.name == name);

  test('browse contract defines bounded tags and danbooru default', () {
    final browse = tool('browse_online_gallery');
    final properties = browse.parameters['properties'] as Map;
    final required = browse.parameters['required'] as List;

    expect(browse.description, contains('at most 6 ordinary tags'));
    expect(browse.description, contains('source is omitted'));
    expect(required, isNot(contains('source')));
    expect(properties['source']['description'], contains('danbooru'));
    expect(browse.description, contains('random=true, limit=N'));
    expect(browse.description, contains('display_images'));
    expect(properties['query']['description'], contains('at most 6'));
    expect(properties['random']['description'], contains('random_feeds'));
    expect(properties['limit']['description'], contains('sample size'));
    expect(properties['limit']['minimum'], 1);
  });

  test(
    'browse rejects more than six ordinary tags before loading gallery',
    () async {
      final result = await tool('browse_online_gallery').execute('too-many', {
        'source': 'danbooru',
        'mode': 'search',
        'query': 'one two three four five six seven',
      });

      expect(result.isError, isTrue);
      expect(result.details, containsPair('code', 'too_many_query_tags'));
    },
  );

  test('source list explains tier limits and residual filtering', () async {
    final result = await tool(
      'list_online_gallery_sources',
    ).execute('list', {});
    final sources = result.details['sources'] as List;
    final danbooru = sources.cast<Map>().singleWhere(
      (source) => source['source'] == 'danbooru',
    );
    final tagSearch = danbooru['tag_search'] as Map;

    expect(tagSearch['strategy'], 'accountTierSeedResidual');
    expect(tagSearch['max_query_tags'], 6);
    expect(tagSearch['server_limits'], {
      'anonymous': 2,
      'authenticated': 2,
      'gold': 6,
      'max_query_tags_from_account_level': 31,
    });
    expect(tagSearch['residual_filtering'], contains('client'));
  });

  test('display_images remains the only explicit display contract', () {
    expect(
      tools.map((tool) => tool.name),
      isNot(contains('display_online_gallery')),
    );
    expect(
      tool('browse_online_gallery').description,
      contains('never displays'),
    );
  });

  test('browse loads results while the gallery page is hidden', () async {
    final adapter = _ToolGalleryAdapter();
    final toolContainer = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
          (_) async => const {},
        ),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.danbooru
                ? adapter
                : _EmptyGalleryAdapter(source),
        }),
      ],
    );
    addTearDown(toolContainer.dispose);
    final notifier = toolContainer.read(onlineGalleryNotifierProvider.notifier);
    notifier.setBackgroundNetworkPaused(true);
    final browse = OnlineGalleryToolbox(
      toolContainer.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');

    final result = await browse.execute('hidden-gallery', {
      'source': 'danbooru',
      'mode': 'search',
      'query': 'blue_archive',
      'limit': 5,
    });

    expect(result.isError, isFalse);
    expect((result.details['items'] as List), hasLength(1));
    expect(adapter.queries, ['blue_archive']);
  });

  test(
    'screenshot AI TAG parameters complete with one configured load',
    () async {
      final aiTag = _ScriptedGalleryAdapter(
        GallerySourceId.aiTag,
        (request, _) async => _page(request, [
          _item(GallerySourceId.aiTag, 101, const ['ibuki', 'blue', 'archive']),
        ]),
      );
      final danbooru = _ScriptedGalleryAdapter(
        GallerySourceId.danbooru,
        (request, _) async => _page(request, const []),
      );
      final harness = _createHarness({
        GallerySourceId.aiTag: aiTag,
        GallerySourceId.danbooru: danbooru,
      });
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('screenshot', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'ibuki blue archive',
        'ratings': ['s'],
        'limit': 6,
      });

      expect(result.isError, isFalse);
      expect(result.details['source'], 'ai_tag');
      expect(result.details['requested_limit'], 6);
      expect(result.details['items'], hasLength(1));
      expect(aiTag.requests, hasLength(1));
      expect(aiTag.requests.single.query, 'archive blue ibuki');
      expect(
        harness.container.read(onlineGalleryNotifierProvider).searchQuery,
        'ibuki blue archive',
      );
      expect(danbooru.requests, isEmpty);
    },
  );

  test('omitted source uses danbooru adapter', () async {
    final danbooru = _ScriptedGalleryAdapter(
      GallerySourceId.danbooru,
      (request, _) async => _page(request, const []),
    );
    final aiTag = _ScriptedGalleryAdapter(
      GallerySourceId.aiTag,
      (request, _) async => _page(request, const []),
    );
    final harness = _createHarness({
      GallerySourceId.danbooru: danbooru,
      GallerySourceId.aiTag: aiTag,
    });
    addTearDown(harness.container.dispose);

    final result = await harness.browse.execute('default-source', {
      'mode': 'search',
      'query': 'ibuki',
    });

    expect(result.isError, isFalse);
    expect(result.details['source'], 'danbooru');
    expect(danbooru.requests, hasLength(1));
    expect(aiTag.requests, isEmpty);
  });

  test(
    'explicit source selects its adapter and empty results complete',
    () async {
      final gelbooru = _ScriptedGalleryAdapter(
        GallerySourceId.gelbooru,
        (request, _) async => _page(request, const []),
      );
      final danbooru = _ScriptedGalleryAdapter(
        GallerySourceId.danbooru,
        (request, _) async => _page(request, const []),
      );
      final harness = _createHarness({
        GallerySourceId.gelbooru: gelbooru,
        GallerySourceId.danbooru: danbooru,
      });
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('explicit-source', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'nothing',
      });

      expect(result.isError, isFalse);
      expect(result.details['source'], 'gelbooru');
      expect(result.details['items'], isEmpty);
      expect(gelbooru.requests, hasLength(1));
      expect(danbooru.requests, isEmpty);
    },
  );

  test('network and parse errors complete with diagnostic result', () async {
    for (final code in [
      GallerySourceErrorCode.network,
      GallerySourceErrorCode.malformedResponse,
    ]) {
      final adapter = _ScriptedGalleryAdapter(
        GallerySourceId.aiTag,
        (_, __) => throw GallerySourceException(
          code,
          source: GallerySourceId.aiTag,
          message: 'diagnostic ${code.name}',
        ),
      );
      final harness = _createHarness({GallerySourceId.aiTag: adapter});
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('error-${code.name}', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'ibuki',
      });

      expect(result.isError, isTrue);
      expect(result.details['code'], code.name);
    }
  });

  test('stop cancels network, exits loading, and permits a new call', () async {
    final adapter = _CancellableGalleryAdapter();
    final harness = _createHarness({GallerySourceId.aiTag: adapter});
    addTearDown(harness.container.dispose);
    final firstAbort = AbortController();

    final first = harness.browse.execute('cancel-first', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'ibuki blue archive',
    }, firstAbort.signal);
    await adapter.firstStarted.future;
    firstAbort.abort('user stopped');

    await expectLater(first, throwsA(anything));
    expect(adapter.cancelledRequests, 1);
    expect(
      harness.container.read(onlineGalleryNotifierProvider).isLoading,
      isFalse,
    );

    final second = await harness.browse.execute('after-stop', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'second',
    });
    expect(second.isError, isFalse);
    expect((second.details['items'] as List).single['work_id'], '202');

    adapter.completeLateFirst();
    await Future<void>.delayed(Duration.zero);
    final state = harness.container.read(onlineGalleryNotifierProvider);
    expect(state.posts.single.id, 202);
  });

  test(
    'duplicate append page terminates and other source remains usable',
    () async {
      final item = _item(GallerySourceId.gelbooru, 303, const ['ibuki']);
      final adapter = _ScriptedGalleryAdapter(
        GallerySourceId.gelbooru,
        (request, _) async => GalleryPage(
          items: [item],
          cursor: request.cursor,
          nextCursor: '${int.parse(request.cursor) + 1}',
          hasMore: true,
          total: 10,
          rawItemCount: 1,
        ),
      );
      final harness = _createHarness({GallerySourceId.gelbooru: adapter});
      addTearDown(harness.container.dispose);

      final first = await harness.browse.execute('duplicate-first', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'ibuki',
      });
      final second = await harness.browse.execute('duplicate-next', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'ibuki',
        'load_more': true,
      });

      expect(first.isError, isFalse);
      expect(second.isError, isFalse);
      expect(second.details['has_more'], isFalse);
      expect(adapter.requests, hasLength(2));
    },
  );
}

({ProviderContainer container, AgentTool browse}) _createHarness(
  Map<GallerySourceId, GallerySourceAdapter> overrides,
) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
      onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
        (_) async => const {},
      ),
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        for (final source in GallerySourceId.values)
          source: overrides[source] ?? _EmptyGalleryAdapter(source),
      }),
    ],
  );
  final browse = OnlineGalleryToolbox(
    container.read(_refProvider),
  ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
  return (container: container, browse: browse);
}

GalleryPage _page(GallerySearchRequest request, List<GalleryItem> items) =>
    GalleryPage(
      items: items,
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      total: items.length,
      rawItemCount: items.length,
    );

GalleryItem _item(GallerySourceId source, int id, List<String> tags) =>
    GalleryItem(
      id: id,
      sourceId: source,
      createdAt: '2026-08-30',
      uploaderId: 1,
      width: 768,
      height: 1024,
      rating: 'g',
      tags: tags,
      tagsComplete: true,
      cover: GalleryMedia(
        id: '$id',
        previewUrl: 'https://example.test/$id-preview.webp',
        displayUrl: 'https://example.test/$id.webp',
        downloadUrl: 'https://example.test/$id.webp',
        width: 768,
        height: 1024,
        extension: 'webp',
      ),
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

class _ToolGalleryAdapter extends GallerySourceAdapter {
  final List<String> queries = [];

  @override
  GallerySourceId get sourceId => GallerySourceId.danbooru;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    queries.add(request.query);
    final item = GalleryItem(
      id: 1,
      sourceId: sourceId,
      createdAt: '2026-08-30',
      uploaderId: 1,
      width: 768,
      height: 1024,
      rating: 'g',
      tags: const ['blue_archive'],
      cover: const GalleryMedia(
        id: '1',
        previewUrl: 'https://example.test/preview.webp',
        displayUrl: 'https://example.test/image.webp',
        downloadUrl: 'https://example.test/image.webp',
        width: 768,
        height: 1024,
        extension: 'webp',
      ),
    );
    return GalleryPage(
      items: [item],
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      rawItemCount: 1,
    );
  }
}

class _ScriptedGalleryAdapter extends GallerySourceAdapter {
  _ScriptedGalleryAdapter(this.sourceId, this.handler);

  @override
  final GallerySourceId sourceId;
  final FutureOr<GalleryPage> Function(
    GallerySearchRequest request,
    CancelToken? cancelToken,
  )
  handler;
  final List<GallerySearchRequest> requests = [];

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    return handler(request, cancelToken);
  }
}

class _CancellableGalleryAdapter extends GallerySourceAdapter {
  final firstStarted = Completer<void>();
  final Completer<GalleryPage> _lateFirst = Completer<GalleryPage>();
  int calls = 0;
  int cancelledRequests = 0;

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    if (calls > 1) {
      return _page(request, [
        _item(sourceId, 202, const ['second']),
      ]);
    }
    firstStarted.complete();
    return Future.any([
      _lateFirst.future,
      cancelToken!.whenCancel.then<GalleryPage>((error) {
        cancelledRequests++;
        throw error;
      }),
    ]);
  }

  void completeLateFirst() {
    _lateFirst.complete(
      _page(const GallerySearchRequest(cursor: '1', pageSize: 60), [
        _item(sourceId, 201, const ['ibuki', 'blue', 'archive']),
      ]),
    );
  }
}

class _EmptyGalleryAdapter extends GallerySourceAdapter {
  _EmptyGalleryAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: const [],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    rawItemCount: 0,
  );
}
