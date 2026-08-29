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

  test('browse contract defines bounded tags and random sample limit', () {
    final browse = tool('browse_online_gallery');
    final properties = browse.parameters['properties'] as Map;

    expect(browse.description, contains('at most 6 ordinary tags'));
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
