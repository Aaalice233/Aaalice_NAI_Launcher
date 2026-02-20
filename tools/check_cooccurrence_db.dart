import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Check the runtime database
  const dbPath =
      r'C:\Users\Administrator\AppData\Roaming\com.example\nai_launcher\asset_databases\cooccurrence.db';

  print('Opening database: $dbPath');
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true),
  );

  // Check table structure
  print('\n=== Table Structure ===');
  final tableInfo = await db.rawQuery('PRAGMA table_info(cooccurrences)');
  for (final row in tableInfo) {
    print('Column: ${row['name']} (${row['type']})');
  }

  // Check total count
  print('\n=== Total Records ===');
  final countResult =
      await db.rawQuery('SELECT COUNT(*) as cnt FROM cooccurrences');
  print('Total: ${countResult.first['cnt']}');

  // Check sample data
  print('\n=== Sample Data (first 5 rows) ===');
  final sample = await db.rawQuery('SELECT * FROM cooccurrences LIMIT 5');
  for (final row in sample) {
    print('tag1=${row['tag1']}, tag2=${row['tag2']}, count=${row['count']}');
  }

  // Check for 'breasts' tag
  print('\n=== Checking for "breasts" tag ===');
  final breastsCount = await db.rawQuery(
    "SELECT COUNT(*) as cnt FROM cooccurrences WHERE tag1 = 'breasts'",
  );
  print('Records with tag1="breasts": ${breastsCount.first['cnt']}');

  // Check some tag1 values
  print('\n=== Sample tag1 values ===');
  final tag1Sample = await db.rawQuery(
    'SELECT DISTINCT tag1 FROM cooccurrences LIMIT 10',
  );
  for (final row in tag1Sample) {
    print('  ${row['tag1']}');
  }

  // Try the exact query the app uses
  print('\n=== Actual Query Test ===');
  final queryResult = await db.query(
    'cooccurrences',
    columns: ['tag2', 'count', 'cooccurrence_score'],
    where: 'tag1 = ? AND count >= ?',
    whereArgs: ['breasts', 1],
    orderBy: 'count DESC',
    limit: 5,
  );
  print('Query returned ${queryResult.length} rows');
  for (final row in queryResult) {
    print('  tag2=${row['tag2']}, count=${row['count']}');
  }

  await db.close();
  print('\nDone!');
}
