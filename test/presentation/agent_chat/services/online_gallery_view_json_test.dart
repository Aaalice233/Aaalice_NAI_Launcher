import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_view_json.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_state.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  test('AI TAG search shows prompt, time range and artist hunt', () {
    final view = onlineGalleryViewJson(
      const OnlineGalleryState(
        sourceId: GallerySourceId.aiTag,
        searchQuery: 'insect',
        promptQuery: '2girls',
        aiTagTimeRange: 'week',
        artistHuntEnabled: true,
        selectedRatings: {'s', 'g'},
      ),
    );

    expect(view, {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'insect',
      'prompt': '2girls',
      'ai_tag_time_range': 'week',
      'ratings': ['g', 's'],
      'fuzzy': false,
      'random': false,
      'artist_hunt': true,
    });
  });

  test('tag search shows its date range and no prompt', () {
    final view = onlineGalleryViewJson(
      OnlineGalleryState(
        searchQuery: 'ibuki',
        promptQuery: 'left over from another source',
        fuzzySearchEnabled: true,
        dateRangeStart: DateTime(2026, 1, 5),
      ),
    );

    expect(view, {
      'source': 'danbooru',
      'mode': 'search',
      'query': 'ibuki',
      'date_start': '2026-01-05',
      'date_end': null,
      'ratings': ['e', 'g', 'q', 's'],
      'fuzzy': true,
      'random': false,
    });
  });

  test('ranking uses the browse mode name and the source ranking filters', () {
    final danbooru = onlineGalleryViewJson(
      OnlineGalleryState(
        viewMode: GalleryViewMode.popular,
        popularQuery: 'ibuki',
        popularScale: PopularScale.week,
        popularDate: DateTime(2026, 11, 2),
      ),
    );
    final aiTag = onlineGalleryViewJson(
      const OnlineGalleryState(
        viewMode: GalleryViewMode.popular,
        popularSourceId: GallerySourceId.aiTag,
        popularPromptQuery: '2girls',
        aiTagPopularPeriod: '2026-10',
      ),
    );

    expect(danbooru['mode'], 'ranking');
    expect(danbooru['query'], 'ibuki');
    expect(danbooru['ranking_scale'], 'week');
    expect(danbooru['ranking_date'], '2026-11-02');
    expect(danbooru.keys, isNot(contains('ai_tag_period')));
    expect(aiTag['mode'], 'ranking');
    expect(aiTag['prompt'], '2girls');
    expect(aiTag['ai_tag_period'], '2026-10');
    expect(aiTag.keys, isNot(contains('ranking_scale')));
  });

  test('favorites show only their own search text', () {
    final view = onlineGalleryViewJson(
      const OnlineGalleryState(
        viewMode: GalleryViewMode.favorites,
        searchQuery: 'search tab query',
        promptQuery: 'search tab prompt',
        favoriteSearchQuery: 'saved',
      ),
    );

    expect(view, {
      'source': 'danbooru',
      'mode': 'favorites',
      'query': 'saved',
      'ratings': ['e', 'g', 'q', 's'],
      'fuzzy': false,
      'random': false,
    });
  });

  test('QuickTagCloud shows the codex and category being browsed', () {
    final view = onlineGalleryViewJson(
      OnlineGalleryState(
        sourceId: GallerySourceId.quickTagCloud,
        quickTagCloudFilterKey: const QuickTagCloudGalleryQuery(
          codexId: 'other',
          categoryPath: ['clothing', 'kimono'],
          scope: QuickTagCloudBrowseScope.latest,
          mediaFilter: QuickTagCloudMediaFilter.withImages,
        ).stableKey,
      ),
    );

    expect(view['quick_tag_cloud'], {
      'codex': 'other',
      'category_path': ['clothing', 'kimono'],
      'update_filter': '',
      'scope': 'latest',
      'media_filter': 'withImages',
    });
  });

  test('every key is a browse parameter or a page-only filter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final browse = OnlineGalleryToolbox(
      container.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
    final properties = browse.parameters['properties'] as Map;
    const pageOnly = {
      'date_start',
      'date_end',
      'artist_hunt',
      'quick_tag_cloud',
    };
    final states = [
      for (final viewMode in GalleryViewMode.values)
        for (final source in GallerySourceId.values)
          OnlineGalleryState(
            viewMode: viewMode,
            sourceId: source,
            popularSourceId: source,
            favoritesSourceId: source,
          ),
    ];

    for (final state in states) {
      final view = onlineGalleryViewJson(state);
      expect(
        properties.keys,
        containsAll(view.keys.toSet().difference(pageOnly)),
      );
      expect(properties['mode']['enum'], contains(view['mode']));
      expect(properties['source']['enum'], contains(view['source']));
    }
  });
}
