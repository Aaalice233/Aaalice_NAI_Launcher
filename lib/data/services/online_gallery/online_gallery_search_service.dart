import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/autocomplete/tag_catalog_repository.dart';
import '../../../core/online_gallery/gallery_tag_query.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/online_gallery/gallery_item.dart';
import '../../models/online_gallery/gallery_source.dart';

typedef OnlineGalleryTagMetadataLoader =
    Future<Map<String, TagCatalogRecord>> Function(Iterable<String> terms);
typedef OnlineGalleryDetailLoader =
    Future<GalleryDetail> Function(GalleryItem item, CancelToken cancelToken);

class OnlineGallerySearchService {
  final LinkedHashMap<String, Set<String>> _normalizedTagSets =
      LinkedHashMap<String, Set<String>>();
  final LinkedHashMap<String, GalleryTagQueryPlan> _plans =
      LinkedHashMap<String, GalleryTagQueryPlan>();

  void clear() {
    _normalizedTagSets.clear();
    _plans.clear();
  }

  void clearSource(GallerySourceId sourceId) {
    _plans.removeWhere((key, _) => key.startsWith('${sourceId.key}|'));
    _normalizedTagSets.removeWhere(
      (key, _) => key.startsWith('${sourceId.key}:'),
    );
  }

  Future<GalleryTagQueryPlan> buildPlan({
    required GallerySourceId sourceId,
    required GalleryFeedKind feedKind,
    required int serverTagLimit,
    required bool fuzzySearchEnabled,
    required String rawQuery,
    required OnlineGalleryTagMetadataLoader metadataLoader,
  }) async {
    final cacheKey = [
      sourceId.key,
      feedKind.name,
      serverTagLimit,
      fuzzySearchEnabled,
      rawQuery.trim(),
    ].join('|');
    final cached = _plans.remove(cacheKey);
    if (cached != null) {
      _plans[cacheKey] = cached;
      return cached;
    }

    var query = GalleryTagQueryParser.parse(rawQuery);
    if (!query.isValid) {
      throw GalleryTagQueryLimitException(query.ordinaryTagCount);
    }
    final tagCapabilities = gallerySourceCapabilities[sourceId]!.tagSearch;
    final supportedMetatags = tagCapabilities.metatagPrefixes(feedKind);
    if (query.metatags.any(
      (clause) => !supportedMetatags.contains(clause.metatagPrefix),
    )) {
      throw GalleryTagMetatagUnsupportedException(
        sourceKey: sourceId.key,
        feedKey: feedKind.name,
      );
    }
    final supportsNegativePushdown = tagCapabilities.supportsNegativePushdown;
    if (query.ordinaryClauses.isEmpty) {
      return GalleryTagQueryPlanner.plan(
        query,
        serverTagLimit: serverTagLimit,
        allowNegativePushdown: supportsNegativePushdown,
      );
    }

    Map<String, TagCatalogRecord> records = const {};
    final usesDanbooruAliases =
        sourceId == GallerySourceId.danbooru ||
        sourceId == GallerySourceId.safebooru;
    if (usesDanbooruAliases) {
      final terms = query.ordinaryClauses.map((clause) => clause.value);
      try {
        records = await metadataLoader(terms);
      } catch (error) {
        AppLogger.w(
          'Tag metadata unavailable; using source-native query terms: $error',
          'OnlineGallery',
        );
      }
      query = query.canonicalized({
        for (final entry in records.entries)
          entry.key: entry.value.canonicalTag,
      });
    }
    final counts = <String, int>{
      for (final record in records.values)
        record.canonicalTag: record.postCount,
    };
    if (fuzzySearchEnabled &&
        gallerySourceCapabilities[sourceId]!.supportsFuzzySearch) {
      query = GalleryTagQuery(
        raw: query.raw,
        clauses: [
          for (final clause in query.clauses)
            clause.kind == GalleryTagClauseKind.positive &&
                    !clause.value.contains('*') &&
                    !clause.value.contains(':')
                ? clause.canonicalized('*${clause.value}*')
                : clause,
        ],
      );
      counts.addAll({
        for (final entry in counts.entries) '*${entry.key}*': entry.value,
      });
    }
    final plan = GalleryTagQueryPlanner.plan(
      query,
      serverTagLimit: serverTagLimit,
      postCounts: counts,
      allowNegativePushdown: supportsNegativePushdown,
    );
    _plans[cacheKey] = plan;
    while (_plans.length > 24) {
      _plans.remove(_plans.keys.first);
    }
    return plan;
  }

  Future<({List<GalleryItem> items, int detailFailures, int filterMicros})>
  filterByPlan({
    required List<GalleryItem> candidates,
    required GalleryTagQueryPlan plan,
    required GalleryTagSearchCapabilities capabilities,
    required GalleryFeedKind feedKind,
    required CancelToken cancelToken,
    required OnlineGalleryDetailLoader detailLoader,
  }) async {
    final feedAppliedQuery = capabilities.appliesOrdinaryQuery(feedKind);
    final needsLocalValidation =
        plan.query.ordinaryClauses.isNotEmpty &&
        (!feedAppliedQuery ||
            plan.requiresLocalFiltering ||
            capabilities.validatesPushdownLocally);
    if (!needsLocalValidation || candidates.isEmpty) {
      return (items: candidates, detailFailures: 0, filterMicros: 0);
    }
    final stopwatch = Stopwatch()..start();
    final matched = <GalleryItem>[];
    var detailFailures = 0;
    const detailConcurrency = 6;
    for (var start = 0; start < candidates.length; start += detailConcurrency) {
      if (cancelToken.isCancelled) break;
      final chunk = candidates.skip(start).take(detailConcurrency).toList();
      final resolved = await Future.wait([
        for (final candidate in chunk)
          _resolveTags(
            candidate,
            plan: plan,
            cancelToken: cancelToken,
            detailLoader: detailLoader,
          ),
      ]);
      if (cancelToken.isCancelled) break;
      for (var index = 0; index < chunk.length; index++) {
        final outcome = resolved[index];
        if (outcome == null) {
          detailFailures++;
          continue;
        }
        if (plan.matchesNormalizedTags(outcome.tags)) matched.add(outcome.item);
      }
      if (start > 0) await Future<void>.delayed(Duration.zero);
    }
    stopwatch.stop();
    return (
      items: List<GalleryItem>.unmodifiable(matched),
      detailFailures: detailFailures,
      filterMicros: stopwatch.elapsedMicroseconds,
    );
  }

  Future<({GalleryItem item, Set<String> tags})?> _resolveTags(
    GalleryItem item, {
    required GalleryTagQueryPlan plan,
    required CancelToken cancelToken,
    required OnlineGalleryDetailLoader detailLoader,
  }) async {
    var resolvedItem = item;
    var searchTerms = <String>{...item.tags, ...item.searchTerms};
    var normalized = normalizeGalleryTagSet(searchTerms);
    if (item.tagsComplete) {
      return (item: item, tags: _cacheNormalizedTagSet(item, normalized));
    }
    if (plan.matchesAnyNegativeClause(normalized) ||
        (!plan.hasNegativeClauses && plan.matchesPositiveClauses(normalized))) {
      return (item: item, tags: Set<String>.unmodifiable(normalized));
    }

    try {
      resolvedItem = (await detailLoader(item, cancelToken)).item;
      searchTerms = <String>{...resolvedItem.tags, ...resolvedItem.searchTerms};
      normalized = normalizeGalleryTagSet(searchTerms);
    } catch (error) {
      if (error is DioException && CancelToken.isCancel(error)) rethrow;
      return null;
    }
    if (searchTerms.isEmpty) return null;
    if (!resolvedItem.tagsComplete &&
        !plan.matchesAnyNegativeClause(normalized) &&
        (plan.hasNegativeClauses || !plan.matchesPositiveClauses(normalized))) {
      return null;
    }
    return (
      item: resolvedItem,
      tags: _cacheNormalizedTagSet(resolvedItem, normalized),
    );
  }

  Set<String> _cacheNormalizedTagSet(GalleryItem item, Set<String> normalized) {
    final sourceFingerprint = jsonEncode([item.tags, item.searchTerms]);
    final cacheKey = '${item.detailStableKey}|$sourceFingerprint';
    final cached = _normalizedTagSets.remove(cacheKey);
    if (cached != null) {
      _normalizedTagSets[cacheKey] = cached;
      return cached;
    }
    final immutable = Set<String>.unmodifiable(normalized);
    _normalizedTagSets[cacheKey] = immutable;
    while (_normalizedTagSets.length > 5000) {
      _normalizedTagSets.remove(_normalizedTagSets.keys.first);
    }
    return immutable;
  }
}
