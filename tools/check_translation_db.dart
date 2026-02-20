import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const dbPath = r'E:\Aaalice_NAI_Launcher\assets\databases\translation.db';

  print('Opening database: $dbPath');
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true),
  );

  // Check total count
  print('\n=== Total Records ===');
  final countResult =
      await db.rawQuery('SELECT COUNT(*) as cnt FROM translations');
  print('Total translations: ${countResult.first['cnt']}');

  // Check specific tags
  final tagsToCheck = [
    '1girl',
    'solo',
    'long_hair',
    'breasts',
    'looking_at_viewer',
    'smile',
    'open_mouth',
    'shirt',
    'skirt',
    'simple_background',
  ];

  print('\n=== Checking specific tags ===');
  for (final tag in tagsToCheck) {
    // Get tag_id
    final tagResult = await db.rawQuery(
      'SELECT id FROM tags WHERE name = ?',
      [tag],
    );
    if (tagResult.isNotEmpty) {
      final tagId = tagResult.first['id'];
      final translations = await db.rawQuery(
        'SELECT translation FROM translations WHERE tag_id = ? ORDER BY id',
        [tagId],
      );
      print('$tag: ${translations.map((t) => t['translation']).join(', ')}');
    } else {
      print('$tag: NOT FOUND');
    }
  }

  await db.close();
  print('\nDone!');
}
