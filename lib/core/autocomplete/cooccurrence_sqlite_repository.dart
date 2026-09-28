import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../services/verified_resumable_downloader.dart';
import '../utils/app_logger.dart';
import 'cooccurrence_manifest_codec.dart';

class CooccurrenceSqliteRepository {
  CooccurrenceSqliteRepository(this._databaseFactory);

  final DatabaseFactory _databaseFactory;
  Database? _database;
  bool _switching = false;
  Completer<void>? _switchGate;
  int _activeQueries = 0;
  Completer<void>? _queriesDrained;
  bool _closed = false;

  bool get isReady => _database != null && !_closed;

  Future<Database> validateAndOpen(
    File file,
    CooccurrenceDataPackManifest manifest,
  ) async {
    if (!await file.exists() || await file.length() != manifest.databaseSize) {
      throw const FormatException('Installed database size mismatch');
    }
    final hash = await VerifiedResumableDownloader.calculateSha256(file);
    if (!VerifiedResumableDownloader.equalsSha256(
      hash,
      manifest.databaseSha256,
    )) {
      throw FormatException(
        'Installed database SHA256 mismatch: '
        'expected=${manifest.databaseSha256} actual=$hash',
      );
    }
    final header = await file
        .openRead(0, 16)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    if (ascii.decode(header.takeBytes(), allowInvalid: true) !=
        'SQLite format 3\u0000') {
      throw const FormatException('Installed file is not SQLite');
    }
    final database = await _databaseFactory.openDatabase(
      file.path,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    try {
      final quickCheck = await database.rawQuery('PRAGMA quick_check');
      if (quickCheck.isEmpty || quickCheck.first.values.first != 'ok') {
        throw FormatException('SQLite quick_check failed: $quickCheck');
      }
      await _requireColumns(database, 'metadata', {'key', 'value'});
      await _requireColumns(database, 'tags', {'id', 'name'});
      await _requireColumns(database, 'edges', {
        'source_tag_id',
        'target_tag_id',
        'count',
      });
      final metadata = {
        for (final row in await database.query('metadata'))
          '${row['key']}': '${row['value']}',
      };
      final expected = <String, String>{
        'schema_version': '${manifest.schemaVersion}',
        'data_version': manifest.dataVersion,
        'source_revision': manifest.sourceRevision,
        'source_url': manifest.sourceUrl,
        'source_sha256': manifest.sourceSha256,
        'source_pair_count': '${manifest.sourcePairCount}',
        'self_relation_count': '${manifest.selfRelationCount}',
        'tag_count': '${manifest.tagCount}',
        'directed_edge_count': '${manifest.directedEdgeCount}',
      };
      for (final entry in expected.entries) {
        if (metadata[entry.key] != entry.value) {
          throw FormatException(
            'Metadata mismatch for ${entry.key}: '
            'expected=${entry.value} actual=${metadata[entry.key]}',
          );
        }
      }
      final tagCount = (await database.rawQuery(
        'SELECT COUNT(*) AS count FROM tags',
      )).single['count'];
      final edgeCount = (await database.rawQuery(
        'SELECT COUNT(*) AS count FROM edges',
      )).single['count'];
      if (tagCount != manifest.tagCount ||
          edgeCount != manifest.directedEdgeCount) {
        throw FormatException(
          'Database record count mismatch: tags=$tagCount edges=$edgeCount',
        );
      }
      return database;
    } catch (_) {
      await database.close();
      rethrow;
    }
  }

  Future<void> replaceWith(Database database) =>
      switchDatabase(() async => database);

  Future<void> switchDatabase(Future<Database?> Function() replacement) async {
    await _beginSwitch();
    try {
      await _closeCurrent();
      _database = await replacement();
    } finally {
      _endSwitch();
    }
  }

  Future<List<Map<String, Object?>>> queryRelatedTags(
    String tag, {
    required int limit,
    required int minCount,
  }) => _query(
    const [],
    (database) => database.rawQuery(
      '''
    SELECT target.name AS related_tag, edge.count AS count
    FROM tags source
    JOIN edges edge ON edge.source_tag_id = source.id
    JOIN tags target ON target.id = edge.target_tag_id
    WHERE source.name = ? COLLATE NOCASE AND edge.count >= ?
    ORDER BY edge.count DESC, edge.target_tag_id ASC
    LIMIT ?
    ''',
      [tag, minCount, limit],
    ),
  );

  Future<int> queryPairCount() => _query(0, (database) async {
    final rows = await database.rawQuery(
      "SELECT value FROM metadata WHERE key = 'source_pair_count'",
    );
    return rows.isEmpty ? 0 : int.tryParse('${rows.single['value']}') ?? 0;
  });

  Future<int> queryRelatedTagCount(String tag) => _query(0, (database) async {
    final rows = await database.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      WHERE source.name = ? COLLATE NOCASE
      ''',
      [tag],
    );
    return (rows.single['count'] as num?)?.toInt() ?? 0;
  });

  Future<int> queryPairCooccurrence(String first, String second) =>
      _query(0, (database) async {
        final rows = await database.rawQuery(
          '''
          SELECT edge.count AS count
          FROM tags source
          JOIN edges edge ON edge.source_tag_id = source.id
          JOIN tags target ON target.id = edge.target_tag_id
          WHERE source.name = ? COLLATE NOCASE
            AND target.name = ? COLLATE NOCASE
          LIMIT 1
          ''',
          [first, second],
        );
        return rows.isEmpty ? 0 : (rows.single['count'] as num?)?.toInt() ?? 0;
      });

  Future<int> querySummedCooccurrence(String tag) =>
      _query(0, (database) async {
        final rows = await database.rawQuery(
          '''
      SELECT COALESCE(SUM(edge.count), 0) AS total
      FROM tags source
      JOIN edges edge ON edge.source_tag_id = source.id
      WHERE source.name = ? COLLATE NOCASE
      ''',
          [tag],
        );
        return (rows.single['total'] as num?)?.toInt() ?? 0;
      });

  Future<T> _query<T>(
    T fallback,
    Future<T> Function(Database) operation,
  ) async {
    while (_switching) {
      await _switchGate!.future;
    }
    final database = _database;
    if (database == null || _closed) return fallback;
    _activeQueries++;
    try {
      return await operation(database);
    } catch (error, stack) {
      AppLogger.e(
        'Co-occurrence query failed; using online-only results',
        error,
        stack,
        'CooccurrencePack',
      );
      return fallback;
    } finally {
      _activeQueries--;
      if (_activeQueries == 0 && _queriesDrained != null) {
        _queriesDrained!.complete();
        _queriesDrained = null;
      }
    }
  }

  Future<void> _beginSwitch() async {
    while (_switching) {
      await _switchGate!.future;
    }
    _switching = true;
    _switchGate = Completer<void>();
    if (_activeQueries > 0) {
      _queriesDrained = Completer<void>();
      await _queriesDrained!.future;
    }
  }

  void _endSwitch() {
    _switching = false;
    _switchGate?.complete();
    _switchGate = null;
  }

  Future<void> _closeCurrent() async {
    final database = _database;
    _database = null;
    if (database != null) await database.close();
  }

  Future<void> close() async {
    if (_closed) return;
    await switchDatabase(() async => null);
    _closed = true;
  }

  static Future<void> _requireColumns(
    Database database,
    String table,
    Set<String> required,
  ) async {
    final rows = await database.rawQuery('PRAGMA table_info($table)');
    final columns = rows.map((row) => '${row['name']}').toSet();
    if (!columns.containsAll(required)) {
      throw FormatException('Table $table is missing columns: $required');
    }
  }
}
