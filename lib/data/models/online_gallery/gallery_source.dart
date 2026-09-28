import 'package:nai_launcher/core/online_gallery/gallery_tag_query.dart';

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

enum GalleryTagSearchStrategy {
  accountTierSeedResidual,
  fixedSeedResidual,
  native,
  localPredicate,
}

class GalleryTagSearchCapabilities {
  const GalleryTagSearchCapabilities({
    required this.strategy,
    required this.anonymousLimit,
    this.authenticatedLimit,
    this.goldLimit,
    this.unlimitedFromLevel,
    this.listTagsComplete = true,
    this.supportsNegativePushdown = true,
    this.searchMetatagPrefixes = const {},
    this.rankingMetatagPrefixes = const {},
    this.rankingAppliesOrdinaryQuery = false,
    this.validatesPushdownLocally = false,
  });

  final GalleryTagSearchStrategy strategy;
  final int anonymousLimit;
  final int? authenticatedLimit;
  final int? goldLimit;
  final int? unlimitedFromLevel;
  final bool listTagsComplete;
  final bool supportsNegativePushdown;
  final Set<String> searchMetatagPrefixes;
  final Set<String> rankingMetatagPrefixes;
  final bool rankingAppliesOrdinaryQuery;
  final bool validatesPushdownLocally;

  Set<String> metatagPrefixes(GalleryFeedKind feed) => switch (feed) {
    GalleryFeedKind.search => searchMetatagPrefixes,
    GalleryFeedKind.ranking => rankingMetatagPrefixes,
    GalleryFeedKind.favorites => const {},
  };

  bool appliesOrdinaryQuery(GalleryFeedKind feed) => switch (feed) {
    GalleryFeedKind.search => true,
    GalleryFeedKind.ranking => rankingAppliesOrdinaryQuery,
    GalleryFeedKind.favorites => false,
  };

  int serverLimit({required bool authenticated, int? accountLevel}) {
    final level = accountLevel;
    if (level != null &&
        unlimitedFromLevel != null &&
        level >= unlimitedFromLevel!) {
      return 6;
    }
    if (level != null && level >= 30 && goldLimit != null) {
      return goldLimit!;
    }
    if (authenticated && authenticatedLimit != null) {
      return authenticatedLimit!;
    }
    return anonymousLimit;
  }
}

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
    this.tagSearch = const GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.native,
      anonymousLimit: 6,
    ),
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
  final GalleryTagSearchCapabilities tagSearch;

  bool get supportsRanking => rankingKinds.isNotEmpty;

  bool supportsRandomFeed(GalleryFeedKind feed) => randomFeeds.contains(feed);
}

/// Search capability evidence (verified 2026-08-25):
/// - Danbooru tiers: https://danbooru.donmai.us/wiki_pages/help:users
/// - Safebooru anonymous API limit response:
///   https://safebooru.donmai.us/posts.json?limit=1&tags=1girl+solo+smile
/// - Gelbooru API contract: https://gelbooru.com/index.php?page=wiki&s=view&id=18780
///   and a live six-tag HTML query:
///   https://gelbooru.com/index.php?page=post&s=list&tags=1girl+solo+smile+long_hair+looking_at_viewer+blue_eyes
/// - AI TAG live config/search contracts: https://aitag.win/api/config and
///   https://aitag.win/api/ai_works_search?page=1&page_size=60&q=1girl
/// - QuickTagCloud fixed codex format:
///   https://github.com/AgIzT/NovelAI-Tag
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
    tagSearch: GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.accountTierSeedResidual,
      anonymousLimit: 2,
      authenticatedLimit: 2,
      goldLimit: 6,
      unlimitedFromLevel: 31,
      searchMetatagPrefixes: danbooruGalleryMetatagPrefixes,
    ),
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
    tagSearch: GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.fixedSeedResidual,
      anonymousLimit: 2,
      searchMetatagPrefixes: danbooruGalleryMetatagPrefixes,
    ),
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
    tagSearch: GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.native,
      anonymousLimit: 6,
      authenticatedLimit: 6,
      searchMetatagPrefixes: gelbooruGalleryMetatagPrefixes,
    ),
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
    tagSearch: GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.fixedSeedResidual,
      anonymousLimit: 6,
      listTagsComplete: false,
      supportsNegativePushdown: false,
      rankingAppliesOrdinaryQuery: true,
      validatesPushdownLocally: true,
    ),
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
    tagSearch: GalleryTagSearchCapabilities(
      strategy: GalleryTagSearchStrategy.localPredicate,
      anonymousLimit: 6,
    ),
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
