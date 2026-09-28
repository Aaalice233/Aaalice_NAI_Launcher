import '../database/datasources/cooccurrence_data_source.dart';
import 'completion_models.dart';
import 'tag_catalog_repository.dart';

typedef CooccurrenceDataSourceLoader =
    Future<CooccurrenceDataSource> Function();

/// Offline related-tag source backed by the optional compact data pack.
///
/// The pack stores intersection counts. Catalog post counts are joined at
/// query time so ranking can use the same Jaccard metric as Danbooru's related
/// tag endpoint without duplicating the complete tag catalog in another database.
class CooccurrenceCompletionSource implements CompletionSource {
  CooccurrenceCompletionSource(
    CooccurrenceDataSource dataSource, {
    required TagCatalogRepository catalog,
  }) : this.withLoader(() async => dataSource, catalog: catalog);

  CooccurrenceCompletionSource.withLoader(
    this._loadDataSource, {
    required TagCatalogRepository catalog,
  }) : _catalog = catalog;

  final CooccurrenceDataSourceLoader _loadDataSource;
  final TagCatalogRepository _catalog;

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    final relatedTag = query.relatedTag?.trim().toLowerCase();
    if (relatedTag == null || relatedTag.isEmpty || query.token.isNotEmpty) {
      return const [];
    }

    final requestedLimit = CompletionResultLimits.isAll(query.limit)
        ? CompletionResultLimits.maxRelatedTags
        : query.limit.clamp(1, CompletionResultLimits.maxRelatedTags);
    final dataSource = await _loadDataSource();
    final rows = await dataSource.getRelatedTags(
      relatedTag,
      limit: requestedLimit,
    );
    if (rows.isEmpty) return const [];

    final records = await _catalog.recordsByCanonicalTag([
      relatedTag,
      ...rows.map((row) => row.tag),
    ]);
    final sourcePostCount = records[relatedTag]?.postCount;
    final candidates = <CompletionCandidate>[];
    for (final row in rows) {
      final canonicalTag = row.tag.trim().toLowerCase();
      if (canonicalTag.isEmpty ||
          canonicalTag == relatedTag ||
          query.existingTags.contains(canonicalTag)) {
        continue;
      }
      final record = records[canonicalTag];
      final score = row.cooccurrenceScore > 0
          ? row.cooccurrenceScore.clamp(0.0, 1.0)
          : _jaccard(
              intersection: row.count,
              sourcePostCount: sourcePostCount,
              targetPostCount: record?.postCount,
            );
      candidates.add(
        CompletionCandidate(
          canonicalTag: canonicalTag,
          category: record?.category ?? TagCategory.general,
          postCount: record?.postCount ?? 0,
          matchKind: CompletionMatchKind.related,
          sources: const {CompletionSourceKind.cooccurrence},
          relatedScore: score,
          cooccurrenceCount: row.count,
        ),
      );
    }

    candidates.sort((left, right) {
      final similarity = (right.relatedScore ?? 0).compareTo(
        left.relatedScore ?? 0,
      );
      if (similarity != 0) return similarity;
      final occurrences = (right.cooccurrenceCount ?? 0).compareTo(
        left.cooccurrenceCount ?? 0,
      );
      if (occurrences != 0) return occurrences;
      final popularity = right.postCount.compareTo(left.postCount);
      if (popularity != 0) return popularity;
      return left.canonicalTag.compareTo(right.canonicalTag);
    });
    return candidates;
  }

  static double? _jaccard({
    required int intersection,
    required int? sourcePostCount,
    required int? targetPostCount,
  }) {
    if (intersection <= 0 ||
        sourcePostCount == null ||
        sourcePostCount <= 0 ||
        targetPostCount == null ||
        targetPostCount <= 0) {
      return null;
    }
    final union = sourcePostCount + targetPostCount - intersection;
    if (union <= 0) return null;
    return (intersection / union).clamp(0.0, 1.0);
  }
}
