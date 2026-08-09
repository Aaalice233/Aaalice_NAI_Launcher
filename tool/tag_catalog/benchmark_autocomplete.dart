import 'dart:io';

import 'package:nai_launcher/core/autocomplete/completion_models.dart';
import 'package:nai_launcher/core/autocomplete/completion_ranker.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> arguments) async {
  final catalogPath = arguments.isEmpty
      ? 'assets/databases/tag_catalog.db'
      : arguments.first;
  final cooccurrencePath = arguments.length < 2
      ? 'assets/databases/cooccurrence.db'
      : arguments[1];
  final catalog = File(catalogPath);
  if (!catalog.existsSync()) {
    stderr.writeln('Catalog not found: $catalogPath');
    exitCode = 2;
    return;
  }

  final database = sqlite3.open(catalog.absolute.path, mode: OpenMode.readOnly);
  const queries = [
    '1g',
    'long_h',
    'blue_e',
    'hakurei',
    'solo',
    'looking_at',
    'upper_body',
    'outdoors',
  ];
  const iterations = 40;
  final elapsedMicros = <int>[];
  var returned = 0;

  for (final token in queries) {
    final query = CompletionQuery(
      fullText: token,
      cursorPosition: token.length,
      token: token,
      replacementRange: TextReplacementRange(start: 0, end: token.length),
      existingTags: const {},
      limit: 20,
      locale: 'en-US',
    );
    _queryCatalog(database, query);
    for (var iteration = 0; iteration < iterations; iteration++) {
      final stopwatch = Stopwatch()..start();
      final candidates = _queryCatalog(database, query);
      stopwatch.stop();
      elapsedMicros.add(stopwatch.elapsedMicroseconds);
      returned += candidates.length;
    }
  }

  const exhaustiveQueries = ['blue_archive', 'se'];
  final exhaustiveTimes = <int>[];
  var exhaustiveRows = 0;
  for (final token in exhaustiveQueries) {
    final query = CompletionQuery(
      fullText: token,
      cursorPosition: token.length,
      token: token,
      replacementRange: TextReplacementRange(start: 0, end: token.length),
      existingTags: const {},
      limit: CompletionResultLimits.all,
      locale: 'en-US',
    );
    for (var iteration = 0; iteration < 10; iteration++) {
      final stopwatch = Stopwatch()..start();
      final candidates = _queryCatalog(database, query);
      stopwatch.stop();
      exhaustiveTimes.add(stopwatch.elapsedMicroseconds);
      exhaustiveRows += candidates.length;
    }
  }

  final cooccurrence = File(cooccurrencePath);
  final relatedTimes = <int>[];
  var relatedRows = 0;
  if (cooccurrence.existsSync()) {
    final relatedDatabase = sqlite3.open(
      cooccurrence.absolute.path,
      mode: OpenMode.readOnly,
    );
    try {
      for (final tag in const [
        'blue_archive',
        'solo',
        '1girl',
        'sensei_(blue_archive)',
      ]) {
        _queryCooccurrence(relatedDatabase, tag);
        for (var iteration = 0; iteration < 10; iteration++) {
          final stopwatch = Stopwatch()..start();
          final results = _queryCooccurrence(relatedDatabase, tag);
          stopwatch.stop();
          relatedTimes.add(stopwatch.elapsedMicroseconds);
          relatedRows += results.length;
        }
      }
    } finally {
      relatedDatabase.dispose();
    }
  }

  final sample = <CompletionCandidate>[
    const CompletionCandidate(
      canonicalTag: 'long_hair',
      category: TagCategory.general,
      postCount: 5000000,
      matchKind: CompletionMatchKind.englishPrefix,
      sources: {CompletionSourceKind.base},
    ),
    const CompletionCandidate(
      canonicalTag: 'long_hair',
      category: TagCategory.general,
      postCount: 5000100,
      translation: '长发',
      matchKind: CompletionMatchKind.chineseExact,
      sources: {CompletionSourceKind.zhDictionary},
    ),
    const CompletionCandidate(
      canonicalTag: 'long_skirt',
      category: TagCategory.general,
      postCount: 200000,
      matchKind: CompletionMatchKind.englishPrefix,
      sources: {CompletionSourceKind.danbooruApi},
    ),
  ];
  const mergeQuery = CompletionQuery(
    fullText: 'long',
    cursorPosition: 4,
    token: 'long',
    replacementRange: TextReplacementRange(start: 0, end: 4),
    existingTags: {},
    limit: 20,
    locale: 'zh-CN',
  );
  final mergeTimes = <int>[];
  for (var iteration = 0; iteration < 10000; iteration++) {
    final stopwatch = Stopwatch()..start();
    CompletionRanker.mergeAndSort(sample, query: mergeQuery);
    stopwatch.stop();
    mergeTimes.add(stopwatch.elapsedMicroseconds);
  }

  stdout.writeln('catalog=$catalogPath');
  stdout.writeln(
    'queries=${queries.length * iterations} averageRowsScanned='
    '${(returned / (queries.length * iterations)).toStringAsFixed(1)}',
  );
  stdout.writeln(
    'catalogLatency p50=${_percentile(elapsedMicros, 0.50)}us '
    'p95=${_percentile(elapsedMicros, 0.95)}us '
    'max=${elapsedMicros.reduce((a, b) => a > b ? a : b)}us',
  );
  stdout.writeln(
    'exhaustiveLatency p50=${_percentile(exhaustiveTimes, 0.50)}us '
    'p95=${_percentile(exhaustiveTimes, 0.95)}us '
    'averageRows=${(exhaustiveRows / exhaustiveTimes.length).toStringAsFixed(1)}',
  );
  if (relatedTimes.isNotEmpty) {
    stdout.writeln(
      'relatedLatency p50=${_percentile(relatedTimes, 0.50)}us '
      'p95=${_percentile(relatedTimes, 0.95)}us '
      'averageRows=${(relatedRows / relatedTimes.length).toStringAsFixed(1)}',
    );
  }
  stdout.writeln(
    'mergeLatency p50=${_percentile(mergeTimes, 0.50)}us '
    'p95=${_percentile(mergeTimes, 0.95)}us',
  );
  stdout.writeln(
    'rss=${(ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(1)}MiB',
  );

  database.dispose();
}

ResultSet _queryCatalog(Database database, CompletionQuery query) {
  final expression = query.token
      .replaceAll('_', ' ')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .map((token) => '"${token.replaceAll('"', '""')}"*')
      .join(' ');
  return database.select(
    '''
    SELECT f.term, f.kind, t.name, t.category, t.post_count
    FROM tag_search f
    JOIN tags t ON t.id = f.tag_id
    WHERE tag_search MATCH ?
    ORDER BY bm25(tag_search), t.post_count DESC, t.name ASC
    LIMIT ?
    ''',
    [expression, query.limit * 5],
  );
}

ResultSet _queryCooccurrence(Database database, String tag) {
  return database.select(
    '''
    SELECT related_tag, count
    FROM (
      SELECT tag2 AS related_tag, count
      FROM cooccurrences
      WHERE tag1 = ? AND count >= 1
      UNION ALL
      SELECT tag1 AS related_tag, count
      FROM cooccurrences
      WHERE tag2 = ? AND count >= 1
    )
    ORDER BY count DESC, related_tag ASC
    LIMIT 25000
    ''',
    [tag, tag],
  );
}

int _percentile(List<int> values, double percentile) {
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}
