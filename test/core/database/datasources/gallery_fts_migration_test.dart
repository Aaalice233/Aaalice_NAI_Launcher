import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/connection_pool_holder.dart';
import 'package:nai_launcher/core/database/datasources/gallery_tables.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../helpers/gallery_database_sandbox.dart';

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_fts_migration_');

  Future<T> withConnection<T>(Future<T> Function(Database db) action) async {
    final pool = ConnectionPoolHolder.instance;
    final db = await pool.acquire();
    try {
      return await action(db);
    } finally {
      await pool.release(db);
    }
  }

  Future<int> addImage(String name, String prompt) async {
    final imageId = await sandbox.dataSource.upsertImage(
      filePath: 'G:/gallery/$name.png',
      fileName: '$name.png',
      fileSize: 1,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
    );
    await sandbox.dataSource.upsertMetadata(
      imageId,
      NaiImageMetadata(prompt: prompt),
    );
    return imageId;
  }

  /// 换成旧版布局：image_id 是 UNINDEXED 列，rowid 与图片 id 无关。
  Future<void> downgradeToLegacyIndex(
    List<({int rowid, int imageId, String text})> rows,
  ) => withConnection((db) async {
    await db.execute('DROP TABLE ${GalleryTables.ftsIndex}');
    await db.execute('''
      CREATE VIRTUAL TABLE ${GalleryTables.legacyFtsIndex} USING fts5(
        image_id UNINDEXED,
        prompt_text,
        tokenize = 'porter'
      )
    ''');
    for (final row in rows) {
      await db.rawInsert(
        'INSERT INTO ${GalleryTables.legacyFtsIndex} '
        '(rowid, image_id, prompt_text) VALUES (?, ?, ?)',
        [row.rowid, row.imageId, row.text],
      );
    }
  });

  Future<void> relaunch() async {
    await sandbox.dataSource.dispose();
    await sandbox.dataSource.initialize();
    await sandbox.dataSource.whenFtsIndexSettled();
  }

  Future<Set<String>> tableNames() => withConnection((db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return {for (final row in rows) row['name']! as String};
  });

  Future<Map<int, String>> indexedTexts() => withConnection((db) async {
    final rows = await db.rawQuery(
      'SELECT rowid, prompt_text FROM ${GalleryTables.ftsIndex}',
    );
    return {
      for (final row in rows) row['rowid']! as int: row['prompt_text']! as String,
    };
  });

  test('迁移前后 MATCH 查询的结果与排序一致', () async {
    // 各行词数不同，bm25 不会并列，排序可以逐项比较
    const prompts = [
      '1girl red dress',
      '1girl blue dress standing outdoors',
      'landscape mountain lake at sunset',
      '1girl dresses red ribbon smile looking at viewer',
      'cat sleeping',
      'red blue green abstract shapes on a white background canvas',
    ];
    final imageIds = <int>[];
    for (final (index, prompt) in prompts.indexed) {
      imageIds.add(await addImage('image$index', prompt));
    }
    final legacyRows = await indexedTexts();
    await downgradeToLegacyIndex([
      for (final imageId in imageIds)
        (rowid: 10000 - imageId, imageId: imageId, text: legacyRows[imageId]!),
    ]);

    const queries = {
      '1girl': '"1girl"*',
      'dress': '"dress"*',
      'dresses': '"dresses"*',
      'red, blue': '"red"* OR "blue"*',
      'nothing matches': '"nothing"* OR "matches"*',
    };
    final legacyResults = <String, List<int>>{};
    await withConnection((db) async {
      for (final MapEntry(key: query, value: expression) in queries.entries) {
        final rows = await db.rawQuery(
          'SELECT image_id FROM ${GalleryTables.legacyFtsIndex} '
          'WHERE ${GalleryTables.legacyFtsIndex} MATCH ? '
          'ORDER BY rank LIMIT 100',
          [expression],
        );
        legacyResults[query] = [for (final row in rows) row['image_id']! as int];
      }
    });
    expect(legacyResults['dresses'], isNotEmpty);
    expect(legacyResults['nothing matches'], isEmpty);

    await relaunch();

    for (final query in queries.keys) {
      expect(
        await sandbox.dataSource.searchFullText(query),
        legacyResults[query],
        reason: query,
      );
    }
    final tables = await tableNames();
    expect(tables, isNot(contains(GalleryTables.legacyFtsIndex)));
    expect(tables, isNot(contains(GalleryTables.ftsRebuild)));
  });

  test('迁移按元数据重建：重复行、孤儿行和漏写的行都被纠正', () async {
    final alpha = await addImage('alpha', 'alpha current');
    final beta = await addImage('beta', 'beta current');
    final hidden = await addImage('hidden', 'hidden gamma');
    await sandbox.dataSource.batchMarkAsDeleted(['G:/gallery/hidden.png']);
    await downgradeToLegacyIndex([
      (rowid: 5, imageId: alpha, text: 'alpha stale'),
      (rowid: 9, imageId: alpha, text: 'alpha current'),
      (rowid: 7, imageId: 999, text: 'orphan ghost'),
      (rowid: 3, imageId: beta, text: 'beta current'),
    ]);

    await relaunch();

    // 软删除图片的元数据仍保留，索引随元数据保留，恢复时直接可搜，查询层按 is_deleted 过滤
    expect(await indexedTexts(), {
      alpha: 'alpha current',
      beta: 'beta current',
      hidden: 'hidden gamma',
    });
    expect(await sandbox.dataSource.searchFullText('stale'), isEmpty);
    expect(await sandbox.dataSource.searchFullText('ghost'), isEmpty);
    expect(await sandbox.dataSource.searchFullText('alpha'), [alpha]);
  });

  test('降级期间旧版本只写了旧表，再升级时新表的陈旧行被元数据覆盖', () async {
    final imageId = await addImage('cycle', 'fresh prompt');
    await withConnection((db) async {
      await db.rawInsert(
        'INSERT OR REPLACE INTO ${GalleryTables.ftsIndex} '
        '(rowid, prompt_text) VALUES (?, ?)',
        [imageId, 'stale prompt'],
      );
      await db.execute('''
        CREATE VIRTUAL TABLE ${GalleryTables.legacyFtsIndex} USING fts5(
          image_id UNINDEXED,
          prompt_text,
          tokenize = 'porter'
        )
      ''');
    });

    await relaunch();

    expect(await indexedTexts(), {imageId: 'fresh prompt'});
  });

  test('回填中断后下次启动从游标续跑，不重复已回填的部分', () async {
    final ids = [
      for (final name in ['one', 'two', 'three', 'four'])
        await addImage(name, '$name prompt'),
    ];
    await withConnection((db) async {
      await db.execute('DELETE FROM ${GalleryTables.ftsIndex}');
      await db.execute('''
        CREATE TABLE ${GalleryTables.ftsRebuild} (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          next_image_id INTEGER NOT NULL
        )
      ''');
      await db.rawInsert(
        'INSERT INTO ${GalleryTables.ftsRebuild} (id, next_image_id) '
        'VALUES (0, ?)',
        [ids[1]],
      );
    });

    await relaunch();

    expect((await indexedTexts()).keys, unorderedEquals([ids[2], ids[3]]));
    expect(await tableNames(), isNot(contains(GalleryTables.ftsRebuild)));
  });

  test('回填进行中写入的新元数据不会被回填成旧值', () async {
    final imageId = await addImage('live', 'old words');
    final legacyRows = await indexedTexts();
    await downgradeToLegacyIndex([
      (rowid: 42, imageId: imageId, text: legacyRows[imageId]!),
    ]);

    await sandbox.dataSource.dispose();
    await sandbox.dataSource.initialize();
    await sandbox.dataSource.upsertMetadata(
      imageId,
      const NaiImageMetadata(prompt: 'new words'),
    );
    await sandbox.dataSource.whenFtsIndexSettled();

    expect(await indexedTexts(), {imageId: 'new words'});
  });
}
