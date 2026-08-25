enum GallerySourceId {
  danbooru('danbooru', 'Danbooru'),
  safebooru('safebooru', 'Safebooru'),
  gelbooru('gelbooru', 'Gelbooru'),
  aiTag('ai_tag', 'AI TAG'),
  quickTagCloud('quick_tag_cloud', 'QuickTagCloud');

  const GallerySourceId(this.key, this.label);

  final String key;
  final String label;

  static GallerySourceId fromKey(String value) {
    return GallerySourceId.values.firstWhere(
      (source) => source.key == value,
      orElse: () => GallerySourceId.danbooru,
    );
  }
}

enum GalleryRankingKind { day, week, month, aiTagMonthly }

enum GalleryFeedKind { search, ranking, favorites }

enum GalleryRemoteFavoritesCapability { none, readOnly, readWrite }

enum GalleryRemoteBlacklistCapability { none, readWrite }

class GallerySourceCapabilities {
  const GallerySourceCapabilities({
    required this.supportsSearch,
    required this.supportsFuzzySearch,
    required this.supportsDateRange,
    required this.supportsRatings,
    required this.supportsGeneralQuery,
    required this.supportsPromptQuery,
    required this.rankingKinds,
    required this.supportsFavorites,
    required this.supportsWritableFavorites,
    this.supportsLocalFavorites = true,
    this.remoteFavorites = GalleryRemoteFavoritesCapability.none,
    this.remoteBlacklist = GalleryRemoteBlacklistCapability.none,
    this.supportsCategorizedTags = false,
    required this.supportsDetails,
    required this.supportsMultipleMedia,
    required this.randomFeeds,
  });

  final bool supportsSearch;
  final bool supportsFuzzySearch;
  final bool supportsDateRange;
  final bool supportsRatings;
  final bool supportsGeneralQuery;
  final bool supportsPromptQuery;
  final Set<GalleryRankingKind> rankingKinds;
  final bool supportsFavorites;
  final bool supportsWritableFavorites;
  final bool supportsLocalFavorites;
  final GalleryRemoteFavoritesCapability remoteFavorites;
  final GalleryRemoteBlacklistCapability remoteBlacklist;
  final bool supportsCategorizedTags;
  final bool supportsDetails;
  final bool supportsMultipleMedia;
  final Set<GalleryFeedKind> randomFeeds;

  bool get supportsRanking => rankingKinds.isNotEmpty;

  bool supportsRandomFeed(GalleryFeedKind feed) => randomFeeds.contains(feed);
}

const Map<GallerySourceId, GallerySourceCapabilities>
gallerySourceCapabilities = {
  GallerySourceId.danbooru: GallerySourceCapabilities(
    supportsSearch: true,
    supportsFuzzySearch: true,
    supportsDateRange: true,
    supportsRatings: true,
    supportsGeneralQuery: false,
    supportsPromptQuery: false,
    rankingKinds: {
      GalleryRankingKind.day,
      GalleryRankingKind.week,
      GalleryRankingKind.month,
    },
    supportsFavorites: true,
    supportsWritableFavorites: true,
    remoteFavorites: GalleryRemoteFavoritesCapability.readWrite,
    remoteBlacklist: GalleryRemoteBlacklistCapability.readWrite,
    supportsCategorizedTags: true,
    supportsDetails: true,
    supportsMultipleMedia: false,
    randomFeeds: {
      GalleryFeedKind.search,
      GalleryFeedKind.ranking,
      GalleryFeedKind.favorites,
    },
  ),
  GallerySourceId.safebooru: GallerySourceCapabilities(
    supportsSearch: true,
    supportsFuzzySearch: true,
    supportsDateRange: true,
    supportsRatings: false,
    supportsGeneralQuery: false,
    supportsPromptQuery: false,
    rankingKinds: {
      GalleryRankingKind.day,
      GalleryRankingKind.week,
      GalleryRankingKind.month,
    },
    supportsFavorites: false,
    supportsWritableFavorites: false,
    supportsCategorizedTags: true,
    supportsDetails: true,
    supportsMultipleMedia: false,
    randomFeeds: {GalleryFeedKind.search, GalleryFeedKind.ranking},
  ),
  GallerySourceId.gelbooru: GallerySourceCapabilities(
    supportsSearch: true,
    supportsFuzzySearch: true,
    supportsDateRange: true,
    supportsRatings: true,
    supportsGeneralQuery: false,
    supportsPromptQuery: false,
    rankingKinds: {},
    supportsFavorites: true,
    supportsWritableFavorites: false,
    remoteFavorites: GalleryRemoteFavoritesCapability.readOnly,
    supportsDetails: true,
    supportsMultipleMedia: false,
    randomFeeds: {GalleryFeedKind.search, GalleryFeedKind.favorites},
  ),
  GallerySourceId.aiTag: GallerySourceCapabilities(
    supportsSearch: true,
    supportsFuzzySearch: false,
    supportsDateRange: false,
    supportsRatings: false,
    supportsGeneralQuery: true,
    supportsPromptQuery: true,
    rankingKinds: {GalleryRankingKind.aiTagMonthly},
    supportsFavorites: false,
    supportsWritableFavorites: false,
    supportsDetails: true,
    supportsMultipleMedia: true,
    randomFeeds: {GalleryFeedKind.search, GalleryFeedKind.ranking},
  ),
  GallerySourceId.quickTagCloud: GallerySourceCapabilities(
    supportsSearch: true,
    supportsFuzzySearch: false,
    supportsDateRange: false,
    supportsRatings: true,
    supportsGeneralQuery: true,
    supportsPromptQuery: false,
    rankingKinds: {},
    supportsFavorites: true,
    supportsWritableFavorites: false,
    supportsLocalFavorites: true,
    supportsDetails: true,
    supportsMultipleMedia: true,
    randomFeeds: {GalleryFeedKind.search, GalleryFeedKind.favorites},
  ),
};

extension GallerySourceIdX on GallerySourceId {
  String stableItemKey(Object workId) => '$key:$workId';

  String get baseUrl => switch (this) {
    GallerySourceId.danbooru => 'https://danbooru.donmai.us',
    GallerySourceId.safebooru => 'https://safebooru.donmai.us',
    GallerySourceId.gelbooru => 'https://gelbooru.com',
    GallerySourceId.aiTag => 'https://aitag.win',
    GallerySourceId.quickTagCloud => 'https://novelai.quicktagcloud.com',
  };

  String itemPageUrl(Object workId) => switch (this) {
    GallerySourceId.danbooru ||
    GallerySourceId.safebooru => '$baseUrl/posts/$workId',
    GallerySourceId.gelbooru =>
      '$baseUrl/index.php?page=post&s=view&id=$workId',
    GallerySourceId.aiTag => '$baseUrl/i/$workId',
    // QuickTagCloud does not expose a stable per-entry web route.
    GallerySourceId.quickTagCloud => baseUrl,
  };
}
