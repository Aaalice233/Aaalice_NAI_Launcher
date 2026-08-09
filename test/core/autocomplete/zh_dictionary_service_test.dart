import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

void main() {
  late Directory temp;
  late ZhDictionaryService service;

  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('zh_dictionary_test_');
    service = ZhDictionaryService();
  });

  tearDown(() async {
    service.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('validates the upstream tags schema and quick_check', () async {
    final file = _createDictionary('${temp.path}/valid.sqlite', rows: 1000);

    expect(await service.validateDatabaseFile(file.path), 1000);
  });

  test('rejects a corrupt SQLite file', () async {
    final file = File('${temp.path}/corrupt.sqlite');
    await file.writeAsString('not a sqlite database');

    expect(() => service.validateDatabaseFile(file.path), throwsStateError);
  });

  test(
    'rejects a dictionary with an incompatible schema or too few rows',
    () async {
      final wrongSchema = File(p.join(temp.path, 'wrong.sqlite'));
      final db = native.sqlite3.open(wrongSchema.path);
      db.execute('CREATE TABLE tags(name TEXT, cn_name TEXT)');
      db.dispose();
      final tooSmall = _createDictionary('${temp.path}/small.sqlite', rows: 10);

      expect(
        () => service.validateDatabaseFile(wrongSchema.path),
        throwsStateError,
      );
      expect(
        () => service.validateDatabaseFile(tooSmall.path),
        throwsStateError,
      );
    },
  );
}

File _createDictionary(String path, {required int rows}) {
  final db = native.sqlite3.open(path);
  db.execute('''
    CREATE TABLE tags(
      name TEXT PRIMARY KEY,
      category INTEGER,
      cn_name TEXT,
      post_count INTEGER
    )
  ''');
  final statement = db.prepare(
    'INSERT INTO tags(name, category, cn_name, post_count) VALUES (?, ?, ?, ?)',
  );
  db.execute('BEGIN');
  for (var index = 0; index < rows; index++) {
    statement.execute(['tag_$index', 0, '标签$index', rows - index]);
  }
  db.execute('COMMIT');
  statement.dispose();
  db.dispose();
  return File(path);
}
