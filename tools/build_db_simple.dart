import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

// SQLite has a limit of 999 variables per query
// tags: 4 columns -> batch size 200 (800 params)
// translations: 4 columns -> batch size 200 (800 params)
// cooccurrences: 5 columns -> batch size 150 (750 params)
const int _tagBatchSize = 200;
const int _cooccurrenceBatchSize = 150;

void main() async {
  print('Starting database build...');

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Build translation db
  await buildTranslationDb();

  // Build cooccurrence db
  await buildCooccurrenceDb();

  print('Done!');
}

Future<void> buildTranslationDb() async {
  print('Building translation database...');

  const hfCsvPath = 'assets/translations/hf_danbooru_tags.csv';
  final outputDir = Directory('assets/databases');
  final dbPath = p.absolute(p.join(outputDir.path, 'translation.db'));

  if (!await File(hfCsvPath).exists()) {
    print('ERROR: CSV not found: $hfCsvPath');
    return;
  }

  await outputDir.create(recursive: true);

  // Delete existing database
  final oldDb = File(dbPath);
  if (await oldDb.exists()) {
    await oldDb.delete();
    print('Deleted old database');
  }

  // Load all translation sources
  final allTranslations = <String, Set<String>>{};

  // 1. Load danbooru_zh.csv (tag,translation)
  await _loadSimpleCsv('assets/translations/danbooru_zh.csv', allTranslations);

  // 2. Load danbooru.csv (tag,translation)
  await _loadSimpleCsv('assets/translations/danbooru.csv', allTranslations);

  // 3. Load wai_characters.csv (translation,tag) - note: reversed order
  await _loadReversedCsv(
      'assets/translations/wai_characters.csv', allTranslations);

  // 4. Load github_chening233.csv (danbooru_text,url,tag,translation)
  await _loadGithubCsv(
      'assets/translations/github_chening233.csv', allTranslations);

  // 5. Extract from hf_danbooru_tags.csv aliases
  await _loadFromAliases(hfCsvPath, allTranslations);

  print('Total tags with translations: ${allTranslations.length}');
  var totalTrans = 0;
  for (final entry in allTranslations.entries) {
    totalTrans += entry.value.length;
  }
  print('Total translations: $totalTrans');

  final dbFactory = databaseFactoryFfi;

  final db = await dbFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        print('Creating tables...');
        await db.execute('''
          CREATE TABLE tags (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            type INTEGER NOT NULL DEFAULT 0,
            count INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE translations (
            id INTEGER PRIMARY KEY,
            tag_id INTEGER NOT NULL,
            language TEXT NOT NULL,
            translation TEXT NOT NULL,
            FOREIGN KEY (tag_id) REFERENCES tags(id)
          )
        ''');
        await db.execute('CREATE INDEX idx_tags_name ON tags(name)');
        await db.execute(
            'CREATE INDEX idx_translations_tag_id ON translations(tag_id)');
        await db.execute(
            'CREATE INDEX idx_translations_language ON translations(language)');
        print('Tables created');
      },
    ),
  );

  final lines = await File(hfCsvPath).readAsLines();
  print('Total lines in hf_danbooru_tags.csv: ${lines.length}');

  var currentTagId = 1;
  var processed = 0;
  var transCount = 0;

  await db.transaction((txn) async {
    final tagBatch = <Map<String, dynamic>>[];
    final translationBatch = <Map<String, dynamic>>[];
    var translationId = 1;

    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = _parseCsvLine(line);
      if (parts.length < 4) continue;

      final name = parts[0];
      final type = int.tryParse(parts[1]) ?? 0;
      final count = int.tryParse(parts[2]) ?? 0;

      // Add tag
      tagBatch.add({
        'id': currentTagId,
        'name': name,
        'type': type,
        'count': count,
      });

      // Add all translations for this tag
      final translations = allTranslations[name] ?? <String>{};
      for (final trans in translations) {
        if (trans.isNotEmpty) {
          translationBatch.add({
            'id': translationId++,
            'tag_id': currentTagId,
            'language': 'zh',
            'translation': trans,
          });
          transCount++;
        }
      }

      currentTagId++;
      processed++;

      if (tagBatch.length >= _tagBatchSize) {
        await _insertBatch(txn, 'tags', tagBatch);
        tagBatch.clear();
      }
      if (translationBatch.length >= _tagBatchSize) {
        await _insertBatch(txn, 'translations', translationBatch);
        translationBatch.clear();
      }

      if (processed % 5000 == 0) {
        print('Processed $processed tags...');
      }
    }

    // Insert remaining
    if (tagBatch.isNotEmpty) {
      await _insertBatch(txn, 'tags', tagBatch);
    }
    if (translationBatch.isNotEmpty) {
      await _insertBatch(txn, 'translations', translationBatch);
    }
  });

  await db.close();

  // Verify file was created
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    final size = await dbFile.length();
    print(
        'Translation database built: $processed tags, $transCount translations (${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
  } else {
    print('ERROR: Database file not found at $dbPath');
  }
}

/// Load simple CSV: tag,translation
Future<void> _loadSimpleCsv(
    String path, Map<String, Set<String>> result) async {
  final file = File(path);
  if (!await file.exists()) {
    print('Warning: $path not found');
    return;
  }

  final lines = await file.readAsLines();
  var count = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final idx = line.indexOf(',');
    if (idx > 0) {
      final tag = line.substring(0, idx).trim().toLowerCase();
      final trans = line.substring(idx + 1).trim();
      if (tag.isNotEmpty && trans.isNotEmpty && trans != 'None') {
        result.putIfAbsent(tag, () => <String>{}).add(trans);
        count++;
      }
    }
  }
  print('Loaded $count translations from $path');
}

/// Load reversed CSV: translation,tag
Future<void> _loadReversedCsv(
    String path, Map<String, Set<String>> result) async {
  final file = File(path);
  if (!await file.exists()) {
    print('Warning: $path not found');
    return;
  }

  final lines = await file.readAsLines();
  var count = 0;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final idx = line.indexOf(',');
    if (idx > 0) {
      final trans = line.substring(0, idx).trim();
      final tag = line.substring(idx + 1).trim().toLowerCase();
      if (tag.isNotEmpty && trans.isNotEmpty) {
        result.putIfAbsent(tag, () => <String>{}).add(trans);
        count++;
      }
    }
  }
  print('Loaded $count translations from $path');
}

/// Load GitHub CSV: danbooru_text,danbooru_url,tag,translation
Future<void> _loadGithubCsv(
    String path, Map<String, Set<String>> result) async {
  final file = File(path);
  if (!await file.exists()) {
    print('Warning: $path not found');
    return;
  }

  final lines = await file.readAsLines();
  var count = 0;

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final parts = _parseCsvLine(line);
    if (parts.length >= 4) {
      final tag = parts[2].trim().toLowerCase();
      final transList = parts[3].trim();

      if (tag.isNotEmpty && transList.isNotEmpty && transList != 'None') {
        // Split by comma and add each translation
        final translations = transList
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty);
        for (final trans in translations) {
          // Only add if contains Chinese characters
          if (_containsChinese(trans)) {
            result.putIfAbsent(tag, () => <String>{}).add(trans);
            count++;
          }
        }
      }
    }
  }
  print('Loaded $count translations from $path');
}

/// Extract Chinese translations from hf_danbooru_tags.csv aliases
Future<void> _loadFromAliases(
    String path, Map<String, Set<String>> result) async {
  final file = File(path);
  if (!await file.exists()) return;

  final lines = await file.readAsLines();
  var count = 0;

  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final parts = _parseCsvLine(line);
    if (parts.length >= 4) {
      final tag = parts[0].trim().toLowerCase();
      final aliases = parts[3];

      final translations = _extractChineseTranslations(aliases);
      for (final trans in translations) {
        result.putIfAbsent(tag, () => <String>{}).add(trans);
        count++;
      }
    }
  }
  print('Extracted $count translations from aliases in $path');
}

Future<void> buildCooccurrenceDb() async {
  print('Building cooccurrence database...');

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
      // CSV count is float (e.g., "3816210.0"), parse as double then convert to int
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

  // Verify file was created
  final dbFile = File(dbPath);
  if (await dbFile.exists()) {
    final size = await dbFile.length();
    print(
        'Cooccurrence database built: $processed records (${(size / 1024 / 1024).toStringAsFixed(2)} MB)');
  } else {
    print('ERROR: Database file not found at $dbPath');
  }
}

Future<void> _insertBatch(
    Transaction txn, String table, List<Map<String, dynamic>> rows) async {
  if (rows.isEmpty) return;

  final columns = rows.first.keys.toList();
  final rowPlaceholders = List.filled(columns.length, '?').join(', ');
  final placeholders =
      List.generate(rows.length, (_) => '($rowPlaceholders)').join(', ');

  final values = rows.expand((r) => r.values).toList();

  await txn.execute(
    'INSERT INTO $table (${columns.join(', ')}) VALUES $placeholders',
    values,
  );
}

List<String> _parseCsvLine(String line) {
  final parts = <String>[];
  var inQuotes = false;
  var current = StringBuffer();

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char == ',' && !inQuotes) {
      parts.add(current.toString());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  parts.add(current.toString());
  return parts;
}

List<String> _extractChineseTranslations(String aliases) {
  final translations = <String>{}; // Use Set to avoid duplicates

  // Split by comma
  final parts = aliases.split(',');
  for (final part in parts) {
    final trimmed = part.trim();
    // Keep Chinese translations (non-ASCII)
    if (trimmed.isNotEmpty && _containsChinese(trimmed)) {
      translations.add(trimmed);
    }
  }

  return translations.toList();
}

bool _containsChinese(String s) {
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    // CJK Unified Ideographs: 4E00-9FFF
    // CJK Extension A: 3400-4DBF
    if ((code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
