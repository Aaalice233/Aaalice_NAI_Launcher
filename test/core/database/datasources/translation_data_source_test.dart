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
}
