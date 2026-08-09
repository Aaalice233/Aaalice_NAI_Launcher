import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/asset_database_manager.dart';
import 'completion_models.dart';

class TagCatalogRecord {
  const TagCatalogRecord({
    required this.canonicalTag,
    required this.category,
    required this.postCount,
  });

  final String canonicalTag;
  final TagCategory category;
  final int postCount;
}

class TagCatalogRepository implements CompletionSource {
  TagCatalogRepository({Database? database}) : _database = database;

  Database? _database;
  Future<Database>? _opening;

  Future<void> initialize() async {
    if (_database != null) return;
    final opening = _opening ??= AssetDatabaseManager.instance
        .openTagCatalogDatabase();
    try {
      _database = await opening;
    } finally {
      if (identical(_opening, opening)) _opening = null;
    }
  }

  @override
  Future<List<CompletionCandidate>> search(CompletionQuery query) async {
    final normalized = query.token.trim().toLowerCase();
    if (normalized.isEmpty || query.isChinese) return const [];
    await initialize();

    final expression = _ftsExpression(normalized);
    if (expression.isEmpty) return const [];
    final requestedLimit =
        normalized.length == 1 && CompletionResultLimits.isAll(query.limit)
        ? CompletionResultLimits.oneCharacter
        : query.limit;
    final rows = await _database!.rawQuery(
      '''
      SELECT f.term, f.kind, t.id, t.name, t.category, t.post_count
      FROM tag_search f
      JOIN tags t ON t.id = f.tag_id
      WHERE tag_search MATCH ?
      ORDER BY bm25(tag_search), t.post_count DESC, t.name ASC
      LIMIT ?
      ''',
      [expression, (requestedLimit * 5).clamp(20, 500000)],
    );

    final byId = <int, Map<String, Object?>>{};
    for (final row in rows) {
      final id = row['id'] as int;
      final current = byId[id];
      if (current == null ||
          _rowMatchPriority(row, normalized) <
              _rowMatchPriority(current, normalized)) {
        byId[id] = row;
      }
    }
    if (byId.isEmpty) return const [];

    final aliasesById = await _loadAliases(byId.keys.toList());
    final candidates = byId.values
        .map((row) {
          final category = TagCategory.fromCatalog(row['category'] as int);
          if (category == null) return null;
          final term = row['term'] as String;
          final kind = row['kind'] as int;
          final matchKind = _matchKind(term, kind, normalized);
          return CompletionCandidate(
            canonicalTag: row['name'] as String,
            category: category,
            postCount: row['post_count'] as int,
            aliases: aliasesById[row['id'] as int] ?? const [],
            matchedAlias: kind == 1 ? term : null,
            matchKind: matchKind,
            sources: const {CompletionSourceKind.base},
          );
        })
        .whereType<CompletionCandidate>()
        .toList();
    candidates.sort((a, b) {
      final match = a.matchKind.index.compareTo(b.matchKind.index);
      if (match != 0) return match;
      final count = b.postCount.compareTo(a.postCount);
      if (count != 0) return count;
      return a.canonicalTag.compareTo(b.canonicalTag);
    });
    return candidates.take(requestedLimit).toList(growable: false);
  }

  Future<Map<int, List<String>>> _loadAliases(List<int> ids) async {
    if (ids.isEmpty) return const {};
    final result = <int, List<String>>{};
    // SQLite builds use different host-parameter limits. Fixed-size batches
    // keep exhaustive searches portable while avoiding one query per row.
    for (var offset = 0; offset < ids.length; offset += 400) {
      final chunk = ids.skip(offset).take(400).toList(growable: false);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _database!.rawQuery(
        'SELECT tag_id, alias FROM aliases WHERE tag_id IN ($placeholders) ORDER BY alias',
        chunk,
      );
      for (final row in rows) {
        result
            .putIfAbsent(row['tag_id'] as int, () => <String>[])
            .add(row['alias'] as String);
      }
    }
    return result;
  }

  Future<int?> postCount(String canonicalTag) async {
    final records = await recordsByCanonicalTag([canonicalTag]);
    return records[canonicalTag.trim().toLowerCase()]?.postCount;
  }

  Future<Map<String, TagCatalogRecord>> recordsByCanonicalTag(
    Iterable<String> canonicalTags,
  ) async {
    final names = canonicalTags
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (names.isEmpty) return const {};
    await initialize();

    final result = <String, TagCatalogRecord>{};
    for (var offset = 0; offset < names.length; offset += 400) {
      final chunk = names.skip(offset).take(400).toList(growable: false);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _database!.rawQuery(
        'SELECT name, category, post_count FROM tags '
        'WHERE name IN ($placeholders)',
        chunk,
      );
      for (final row in rows) {
        final category = TagCategory.fromCatalog(
          (row['category'] as num).toInt(),
        );
        if (category == null) continue;
        final name = row['name'] as String;
        result[name] = TagCatalogRecord(
          canonicalTag: name,
          category: category,
          postCount: (row['post_count'] as num).toInt(),
        );
      }
    }
    return result;
  }

  Future<Map<String, String>> metadata() async {
    await initialize();
    final rows = await _database!.rawQuery('SELECT key, value FROM metadata');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<Map<TagCategory, int>> categoryCounts() async {
    await initialize();
    final rows = await _database!.rawQuery(
      'SELECT category, COUNT(*) AS count FROM tags GROUP BY category',
    );
    final counts = <TagCategory, int>{};
    for (final row in rows) {
      final category = TagCategory.fromCatalog(row['category'] as int);
      if (category == null) continue;
      final count = row['count'] as int;
      counts.update(
        category,
        (current) => current + count,
        ifAbsent: () => count,
      );
    }
    return counts;
  }

  Future<void> dispose() async {
    await _opening;
    await _database?.close();
    _database = null;
  }

  static String _ftsExpression(String value) {
    final normalized = value.replaceAll('_', ' ');
    final tokens = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList();
    return tokens.map((token) => '"${token.replaceAll('"', '""')}"*').join(' ');
  }

  static CompletionMatchKind _matchKind(String term, int kind, String query) {
    final normalizedTerm = term.toLowerCase();
    if (kind == 0) {
      return normalizedTerm == query
          ? CompletionMatchKind.englishExact
          : normalizedTerm.startsWith(query)
          ? CompletionMatchKind.englishPrefix
          : CompletionMatchKind.fullText;
    }
    return normalizedTerm == query
        ? CompletionMatchKind.aliasExact
        : normalizedTerm.startsWith(query)
        ? CompletionMatchKind.aliasPrefix
        : CompletionMatchKind.fullText;
  }

  static int _rowMatchPriority(Map<String, Object?> row, String query) {
    return _matchKind(row['term'] as String, row['kind'] as int, query).index;
  }
}
