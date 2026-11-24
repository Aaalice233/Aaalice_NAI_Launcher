import '../../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../../data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../providers/online_gallery_state.dart';

/// What the gallery shows, keyed like browse_online_gallery parameters.
Map<String, dynamic> onlineGalleryViewJson(OnlineGalleryState state) {
  final source = state.activeSourceId;
  final feed = state.activeFeedKind;
  final capabilities = source.capabilities;
  final isAiTag = source == GallerySourceId.aiTag;
  return {
    'source': source.key,
    'mode': feed.name,
    ...switch (feed) {
      GalleryFeedKind.search => {
        'query': state.searchQuery,
        if (capabilities.supportsPromptQuery) 'prompt': state.promptQuery,
        if (isAiTag) 'ai_tag_time_range': state.aiTagTimeRange,
        if (capabilities.supportsDateRange) ...{
          'date_start': _dateJson(state.dateRangeStart),
          'date_end': _dateJson(state.dateRangeEnd),
        },
      },
      GalleryFeedKind.ranking => {
        'query': state.popularQuery,
        if (capabilities.supportsPromptQuery)
          'prompt': state.popularPromptQuery,
        if (isAiTag)
          'ai_tag_period': state.aiTagPopularPeriod
        else ...{
          'ranking_scale': state.popularScale.name,
          'ranking_date': _dateJson(state.popularDate),
        },
      },
      GalleryFeedKind.favorites => {'query': state.favoriteSearchQuery},
    },
    'ratings': state.selectedRatings.toList()..sort(),
    'fuzzy': state.fuzzySearchEnabled,
    'random': state.randomEnabled,
    if (isAiTag && feed != GalleryFeedKind.favorites)
      'artist_hunt': state.artistHuntEnabled,
    if (source == GallerySourceId.quickTagCloud)
      'quick_tag_cloud': quickTagCloudFiltersJson(state),
  };
}

Map<String, dynamic> quickTagCloudFiltersJson(OnlineGalleryState state) {
  final filters = QuickTagCloudGalleryQuery.tryParseStableKey(
    state.quickTagCloudFilterKey,
  )!;
  return {
    'codex': filters.codexId,
    'category_path': filters.categoryPath,
    'update_filter': filters.updateFilterId,
    'scope': filters.scope.name,
    'media_filter': filters.mediaFilter.name,
  };
}

String? _dateJson(DateTime? date) =>
    date == null ? null : formatGalleryDate(date);
