import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/translation_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('中文翻译搜索返回英文标签、分类和计数', () async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    final dataSource = TranslationDataSource(database: database);
    addTearDown(dataSource.dispose);
    await database.execute('''
      CREATE TABLE tags (
        name TEXT PRIMARY KEY,
        category INTEGER NOT NULL,
        cn_name TEXT,
        post_count INTEGER NOT NULL
      )
    ''');
    await database.insert('tags', {
      'name': 'white_hair',
      'category': 0,
      'cn_name': '白发',
      'post_count': 956400,
    });
    await database.insert('tags', {
      'name': 'red_eyes',
      'category': 0,
      'cn_name': '白发红眼',
      'post_count': 1047308,
    });

    final matches = await dataSource.search(
      '白发',
      matchTag: false,
      matchTranslation: true,
    );

    expect(matches.first.tag, 'white_hair');
    expect(matches.first.translation, '白发');
    expect(matches.first.category, 0);
    expect(matches.first.count, 956400);
  });

  test('文件操作等待正在执行的查询，后续查询等文件操作结束再打开', () async {
    sqfliteFfiInit();
    final scratch = await Directory('tool/.tmp').create(recursive: true);
    final temp = await scratch.absolute.createTemp('translation_reader_');
    final source = TranslationDataSource(
      applicationSupportDirectory: () async => temp,
    );
    final file = await source.databaseFile;
    await file.parent.create(recursive: true);
    final db = await databaseFactoryFfi.openDatabase(file.path);
    try {
      await db.execute(
        'CREATE TABLE tags(name TEXT, cn_name TEXT, category INTEGER, post_count INTEGER)',
      );
    } finally {
      await db.close();
    }
    addTearDown(() async {
      await source.dispose();
      await temp.delete(recursive: true);
    });

    final started = Completer<void>();
    final finishRead = Completer<void>();
    final order = <String>[];
    final first = source.read(0, (database) async {
      started.complete();
      await finishRead.future;
      final rows = await database.rawQuery('SELECT 1 AS n');
      order.add('read');
      return rows.single['n'] as int;
    });
    await started.future;
    final change = source.withDatabaseClosed(() async {
      await file.rename('${file.path}.backup');
      order.add('change');
    });
    final next = source.getCount().then((value) {
      order.add('next');
      return value;
    });
    finishRead.complete();
    await Future.wait([
      first.then((value) => expect(value, 1)),
      change,
      next.then((value) => expect(value, 0)),
    ]);
    expect(order, ['read', 'change', 'next']);
  });
}
