import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

const int _cooccurrenceBatchSize = 150;

void main() async {
  print('Building cooccurrence database...');
  
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  const csvPath = 'assets/translations/hf_danbooru_cooccurrence.csv';
  final outputDir = Directory('assets/databases');
  final dbPath = p.absolute(p.join(outputDir.path, 'cooccurrence.db'));
  
  if (!await File(csvPath).exists()) {
    print('ERROR: CSV not found: $csvPath');
    return;
  }
  
  await outputDir.create(recursive: true);
  
  // Delete existing database
  final oldDb = File(dbPath);
  if (await oldDb.exists()) {
    await oldDb.delete();
    print('Deleted old database');
  }
  
  final db = await databaseFactoryFfi.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        print('Creating tables...');
        await db.execute('''
          CREATE TABLE cooccurrences (
            id INTEGER PRIMARY KEY,
            tag1 TEXT NOT NULL,
            tag2 TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            cooccurrence_score REAL NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('CREATE INDEX idx_tag1 ON cooccurrences(tag1)');
        await db.execute('CREATE INDEX idx_tag2 ON cooccurrences(tag2)');
        await db.execute('CREATE INDEX idx_count ON cooccurrences(count)');
        print('Tables created');
      },
    ),
  );
  
  final lines = await File(csvPath).readAsLines();
  print('Total lines: ${lines.length}');
  
  var currentId = 1;
  var processed = 0;
  
  await db.transaction((txn) async {
    final batch = <Map<String, dynamic>>[];
    
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final parts = line.split(',');
      if (parts.length < 3) continue;
      
      final tag1 = parts[0];
      final tag2 = parts[1];
      final count = (double.tryParse(parts[2]) ?? 0).toInt();
      
      batch.add({
        'id': currentId++,
        'tag1': tag1,
        'tag2': tag2,
        'count': count,
        'cooccurrence_score': 0.0,
      });
      
      processed++;
      
      if (batch.length >= _cooccurrenceBatchSize) {
        await _insertBatch(txn, 'cooccurrences', batch);
        batch.clear();
      }
      
      if (processed % 50000 == 0) {
        print('Processed $processed cooccurrences...');
      }
    }
    
    if (batch.isNotEmpty) {
      await _insertBatch(txn, 'cooccurrences', batch);
    }
  });
  
  await db.close();
  
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    final size = await dbFile.length();
    print('Cooccurrence database built: $processed records (${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
  } else {
    print('ERROR: Database file not found at $dbPath');
  }
}

Future<void> _insertBatch(Transaction txn, String table, List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) return;
  
  final columns = rows.first.keys.toList();
  final rowPlaceholders = List.filled(columns.length, '?').join(', ');
  final placeholders = List.generate(rows.length, (_) => '($rowPlaceholders)').join(', ');
  
  final values = rows.expand((r) => r.values).toList();
  
  await txn.execute(
    'INSERT INTO $table (${columns.join(', ')}) VALUES $placeholders',
    values,
  );
}
