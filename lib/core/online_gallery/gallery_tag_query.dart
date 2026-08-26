import 'dart:math' as math;

const int maxGallerySearchTags = 6;

class GalleryTagQueryLimitException implements Exception {
  const GalleryTagQueryLimitException(this.actual);

  final int actual;
}

class GalleryTagMetatagUnsupportedException implements Exception {
  const GalleryTagMetatagUnsupportedException({
    required this.sourceKey,
    required this.feedKey,
  });

  final String sourceKey;
  final String feedKey;
}

enum GalleryTagClauseKind { positive, negative, metatag }

class GalleryTagClause {
  const GalleryTagClause({
    required this.raw,
    required this.value,
    required this.kind,
  });

  final String raw;
  final String value;
  final GalleryTagClauseKind kind;

  bool get isOrdinary => kind != GalleryTagClauseKind.metatag;
  bool get isNegative => kind == GalleryTagClauseKind.negative;

  GalleryTagClause canonicalized(String canonical) =>
      GalleryTagClause(raw: raw, value: canonical, kind: kind);

  String get searchToken => isNegative ? '-$value' : value;

  String? get metatagPrefix {
    if (kind != GalleryTagClauseKind.metatag) return null;
    final token = value.startsWith('-') ? value.substring(1) : value;
    final colon = token.indexOf(':');
    return colon > 0 ? token.substring(0, colon) : null;
  }
}

class GalleryTagQuery {
  const GalleryTagQuery({required this.raw, required this.clauses});

  final String raw;
  final List<GalleryTagClause> clauses;

  List<GalleryTagClause> get ordinaryClauses =>
      clauses.where((clause) => clause.isOrdinary).toList(growable: false);
  List<GalleryTagClause> get positiveClauses => clauses
      .where((clause) => clause.kind == GalleryTagClauseKind.positive)
      .toList(growable: false);
  List<GalleryTagClause> get negativeClauses => clauses
      .where((clause) => clause.kind == GalleryTagClauseKind.negative)
      .toList(growable: false);
  List<GalleryTagClause> get metatags => clauses
      .where((clause) => clause.kind == GalleryTagClauseKind.metatag)
      .toList(growable: false);
  int get ordinaryTagCount => ordinaryClauses.length;
  bool get isValid => ordinaryTagCount <= maxGallerySearchTags;
  bool get isEmpty => clauses.isEmpty;

  GalleryTagQuery canonicalized(Map<String, String> canonicalByInput) {
    final canonicalClauses = <GalleryTagClause>[];
    final seen = <String>{};
    for (final clause in clauses) {
      final canonical = clause.isOrdinary
          ? clause.canonicalized(canonicalByInput[clause.value] ?? clause.value)
          : clause;
      if (seen.add('${canonical.kind.name}:${canonical.value}')) {
        canonicalClauses.add(canonical);
      }
    }
    return GalleryTagQuery(
      raw: raw,
      clauses: List.unmodifiable(canonicalClauses),
    );
  }
}

const Set<String> danbooruGalleryMetatagPrefixes = {
  'age',
  'approver',
  'arttags',
  'chartags',
  'child',
  'commenter',
  'commentary',
  'copytags',
  'date',
  'downvote',
  'duration',
  'embedded',
  'fav',
  'favcount',
  'filesize',
  'filetype',
  'gentags',
  'has',
  'height',
  'id',
  'is',
  'limit',
  'md5',
  'metatags',
  'mpixels',
  'noter',
  'noteupdater',
  'order',
  'parent',
  'pixiv',
  'pool',
  'random',
  'rating',
  'ratio',
  'score',
  'search',
  'source',
  'status',
  'tagcount',
  'uploader',
  'upvote',
  'user',
  'width',
};

const Set<String> gelbooruGalleryMetatagPrefixes = {
  'id',
  'md5',
  'parent',
  'rating',
  'score',
  'sort',
  'source',
  'user',
  'width',
  'height',
};

abstract final class GalleryTagQueryParser {
  // A colon by itself remains legal in ordinary tags (for example,
  // artist:name). Known source syntaxes are classified before the selected
  // source validates its exact supported subset.
  static const Set<String> _metatagPrefixes = {
    ...danbooruGalleryMetatagPrefixes,
    'sort',
  };

  static GalleryTagQuery parse(String input) {
    final clauses = <GalleryTagClause>[];
    final seen = <String>{};
    for (final rawToken in input.trim().split(RegExp(r'[,，\s]+'))) {
      final token = rawToken.trim();
      if (token.isEmpty) continue;
      final negative = token.startsWith('-') && token.length > 1;
      final body = negative ? token.substring(1) : token;
      final normalized = normalizeGalleryTag(body);
      if (normalized.isEmpty) continue;
      final colon = normalized.indexOf(':');
      final isMetatag =
          colon > 0 &&
          _metatagPrefixes.contains(normalized.substring(0, colon));
      final kind = isMetatag
          ? GalleryTagClauseKind.metatag
          : negative
          ? GalleryTagClauseKind.negative
          : GalleryTagClauseKind.positive;
      final value = isMetatag && negative ? '-$normalized' : normalized;
      final identity = '${kind.name}:$value';
      if (!seen.add(identity)) continue;
      clauses.add(GalleryTagClause(raw: token, value: value, kind: kind));
    }
    return GalleryTagQuery(raw: input, clauses: List.unmodifiable(clauses));
  }
}

String normalizeGalleryTag(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

Set<String> normalizeGalleryTagSet(Iterable<String> tags) {
  final normalized = <String>{};
  for (final tag in tags) {
    final value = normalizeGalleryTag(tag);
    if (value.isNotEmpty) normalized.add(value);
  }
  return normalized;
}

class GalleryTagQueryPlan {
  GalleryTagQueryPlan({
    required this.query,
    required this.serverTagLimit,
    required List<GalleryTagClause> pushdown,
  }) : pushdown = List.unmodifiable(pushdown),
       residual = List.unmodifiable(
         query.ordinaryClauses.where((clause) => !pushdown.contains(clause)),
       ),
       _wildcardPatterns = Map.unmodifiable({
         for (final clause in query.ordinaryClauses)
           if (clause.value.contains('*'))
             clause.value: RegExp(
               '^${RegExp.escape(clause.value).replaceAll(r'\*', '.*')}\$',
               caseSensitive: false,
             ),
       });

  final GalleryTagQuery query;
  final int serverTagLimit;
  final List<GalleryTagClause> pushdown;
  final List<GalleryTagClause> residual;
  final Map<String, RegExp> _wildcardPatterns;

  List<GalleryTagClause> get seedClauses => pushdown;
  List<GalleryTagClause> get residualClauses => residual;

  bool get requiresLocalFiltering => residual.isNotEmpty;
  String get serverQuery => [
    ...pushdown.map((clause) => clause.searchToken),
    ...query.metatags.map((clause) => clause.searchToken),
  ].join(' ');

  bool matchesTags(Iterable<String> candidateTags) =>
      matchesNormalizedTags(normalizeGalleryTagSet(candidateTags));

  bool matchesNormalizedTags(Set<String> tags) {
    if (!matchesPositiveClauses(tags)) return false;
    return !matchesAnyNegativeClause(tags);
  }

  bool matchesPositiveClauses(Set<String> tags) => query.ordinaryClauses
      .where((clause) => !clause.isNegative)
      .every((clause) => _matchesClause(tags, clause.value));

  bool matchesAnyNegativeClause(Set<String> tags) => query.ordinaryClauses
      .where((clause) => clause.isNegative)
      .any((clause) => _matchesClause(tags, clause.value));

  bool get hasNegativeClauses =>
      query.ordinaryClauses.any((clause) => clause.isNegative);

  bool _matchesClause(Set<String> tags, String query) {
    final pattern = _wildcardPatterns[query];
    if (pattern == null) return tags.contains(query);
    return tags.any(pattern.hasMatch);
  }
}

abstract final class GalleryTagQueryPlanner {
  static GalleryTagQueryPlan plan(
    GalleryTagQuery query, {
    required int serverTagLimit,
    Map<String, int> postCounts = const {},
    bool allowNegativePushdown = true,
  }) {
    final ordinary = [
      for (final clause in query.ordinaryClauses)
        if (allowNegativePushdown || !clause.isNegative) clause,
    ];
    ordinary.sort((left, right) {
      if (left.isNegative != right.isNegative) {
        return left.isNegative ? 1 : -1;
      }
      final leftCount = postCounts[left.value] ?? 1 << 62;
      final rightCount = postCounts[right.value] ?? 1 << 62;
      final countOrder = leftCount.compareTo(rightCount);
      if (countOrder != 0) return countOrder;
      return left.value.compareTo(right.value);
    });
    final limit = math.max(0, math.min(serverTagLimit, ordinary.length));
    return GalleryTagQueryPlan(
      query: query,
      serverTagLimit: serverTagLimit,
      pushdown: ordinary.take(limit).toList(growable: false),
    );
  }
}
