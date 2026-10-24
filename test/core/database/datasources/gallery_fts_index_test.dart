import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/database/datasources/gallery_fts_index.dart';
import 'package:nai_launcher/core/database/datasources/gallery_schema.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late _RecordingGateway gateway;
  late GalleryImageRepository images;
  late GalleryMetadataRepository metadata;

  setUpAll(() async {
    sqfliteFfiInit();
    await AppLogger.initialize(isTestEnvironment: true);
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    gateway = _RecordingGateway(db);
    final context = GalleryStoreContext();
    final ftsIndex = GalleryFtsIndex(gateway: gateway);
    await GallerySchema(
      gateway: gateway,
      context: context,
      ftsIndex: ftsIndex,
    ).initialize();
    images = SqliteGalleryImageRepository(gateway: gateway, context: context);
    metadata = SqliteGalleryMetadataRepository(
      gateway: gateway,
      context: context,
      images: images,
      ftsIndex: ftsIndex,
    );
  });

  tearDown(() => db.close());

  Future<int> addImage(String name) => images.upsertImage(
    filePath: 'G:/gallery/$name.png',
    fileName: '$name.png',
    fileSize: 1,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  Future<List<int>> match(String expression) async {
    final rows = await db.rawQuery(
      'SELECT rowid FROM ${GalleryTables.ftsIndex} '
      'WHERE ${GalleryTables.ftsIndex} MATCH ? ORDER BY rowid',
      [expression],
    );
    return [for (final row in rows) row['rowid']! as int];
  }

  Future<int> ftsRowCount() async {
    final rows = await db.rawQuery(
      'SELECT count(*) AS n FROM ${GalleryTables.ftsIndex}',
    );
    return rows.single['n']! as int;
  }

  test('索引表只以 rowid 作为图片键，没有可被逐行比对的 id 列', () async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${GalleryTables.ftsIndex})',
    );

    expect([for (final column in columns) column['name']], ['prompt_text']);
  });

  test('覆盖已有图片的索引行时，任何语句都不扫描整张索引表', () async {
    final first = await addImage('first');
    final second = await addImage('second');
    final third = await addImage('third');
    await metadata.batchUpsertMetadata([
      MapEntry(first, const NaiImageMetadata(prompt: 'amber lantern')),
      MapEntry(second, const NaiImageMetadata(prompt: 'cobalt harbor')),
      MapEntry(third, const NaiImageMetadata(prompt: 'violet orchard')),
    ]);
    gateway.statements.clear();

    await metadata.upsertMetadata(
      first,
      const NaiImageMetadata(prompt: 'scarlet meadow'),
    );
    await metadata.batchUpsertMetadata([
      MapEntry(second, const NaiImageMetadata(prompt: 'emerald canyon')),
    ]);

    final ftsStatements = [
      for (final statement in gateway.statements)
        if (statement.sql.contains(GalleryTables.ftsIndex)) statement,
    ];
    expect(ftsStatements, isNotEmpty);
    for (final statement in ftsStatements) {
      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN ${statement.sql}',
        statement.arguments,
      );
      for (final step in plan) {
        final detail = step['detail']! as String;
        if (!detail.contains(GalleryTables.ftsIndex)) continue;
        // FTS5 的 idxStr 为空即没有可用约束，只能逐行扫描
        expect(
          detail,
          matches(RegExp(r'VIRTUAL TABLE INDEX \d+:\S')),
          reason: statement.sql,
        );
      }
    }

    expect(await ftsRowCount(), 3);
    expect(await match('amber'), isEmpty);
    expect(await match('cobalt'), isEmpty);
    expect(await match('scarlet'), [first]);
    expect(await match('emerald'), [second]);
    expect(await match('violet'), [third]);
  });

  test('同一张图重复写入只保留最新一行，索引与元数据一致', () async {
    final imageId = await addImage('repeat');

    for (final prompt in ['dawn', 'noon', 'dusk']) {
      await metadata.upsertMetadata(imageId, NaiImageMetadata(prompt: prompt));
    }

    expect(await ftsRowCount(), 1);
    expect(await match('dawn OR noon'), isEmpty);
    expect(await match('dusk'), [imageId]);
    final record = await db.rawQuery(
      'SELECT full_prompt_text FROM ${GalleryTables.metadata} '
      'WHERE image_id = ?',
      [imageId],
    );
    expect(record.single['full_prompt_text'], 'dusk');
  });
}

typedef _Statement = ({String sql, List<Object?> arguments});

/// 直接在同一连接上执行，并记下发出的每条语句。
class _RecordingGateway implements GalleryDatabaseGateway {
  _RecordingGateway(this.db);

  final Database db;
  final statements = <_Statement>[];

  @override
  Future<T> execute<T>(
    String operationName,
    Future<T> Function(Database db) operation, {
    Duration? timeout,
    int? maxRetries,
  }) => operation(_RecordingDatabase(db, statements));
}

abstract class _RecordingExecutor implements DatabaseExecutor {
  _RecordingExecutor(this._inner, this._statements);

  final DatabaseExecutor _inner;
  final List<_Statement> _statements;

  void _record(String sql, List<Object?>? arguments) =>
      _statements.add((sql: sql, arguments: arguments ?? const []));

  @override
  Database get database => _inner.database;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    return _inner.execute(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    return _inner.rawInsert(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _record('INSERT INTO $table', null);
    return _inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _record('UPDATE $table WHERE $where', whereArgs);
    return _inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    _record(sql, arguments);
    return _inner.rawQuery(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    return _inner.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    return _inner.rawDelete(sql, arguments);
  }

  @override
  Batch batch() => _RecordingBatch(_inner.batch(), _record);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not recorded');
}

class _RecordingDatabase extends _RecordingExecutor implements Database {
  _RecordingDatabase(Database super.inner, super.statements);
}

class _RecordingBatch implements Batch {
  _RecordingBatch(this._inner, this._record);

  final Batch _inner;
  final void Function(String sql, List<Object?>? arguments) _record;

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    _inner.rawInsert(sql, arguments);
  }

  @override
  void execute(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    _inner.execute(sql, arguments);
  }

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _record('INSERT INTO $table', null);
    _inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    _inner.rawUpdate(sql, arguments);
  }

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _record(sql, arguments);
    _inner.rawDelete(sql, arguments);
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) => _inner.commit(
    exclusive: exclusive,
    noResult: noResult,
    continueOnError: continueOnError,
  );

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) =>
      _inner.apply(noResult: noResult, continueOnError: continueOnError);

  @override
  int get length => _inner.length;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not recorded');
}
