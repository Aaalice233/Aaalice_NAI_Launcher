import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const catalogSchemaVersion = 1;
const allowedCategories = {0, 1, 3, 4, 5};

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final lockFile = File(options.lockPath);
  final lock =
      jsonDecode(await lockFile.readAsString()) as Map<String, dynamic>;
  final input = File(options.inputPath);
  if (!await input.exists()) {
    stderr.writeln('Missing input CSV: ${input.path}');
    exitCode = 2;
    return;
  }

  final actualHash = await sha256.bind(input.openRead()).first;
  final expectedHash = lock['sha256'] as String?;
  if (actualHash.toString() != expectedHash) {
    throw StateError(
      'Source SHA256 mismatch: expected=$expectedHash actual=$actualHash',
    );
  }

  final output = File(options.outputPath);
  await output.parent.create(recursive: true);
  if (await output.exists()) await output.delete();

  final db = sqlite3.open(output.path);
  try {
    _createSchema(db);
    final insertTag = db.prepare(
      'INSERT OR IGNORE INTO tags(name, category, post_count) VALUES (?, ?, ?)',
    );
    final findTag = db.prepare('SELECT id FROM tags WHERE name = ?');
    final insertAlias = db.prepare(
      'INSERT OR IGNORE INTO aliases(tag_id, alias) VALUES (?, ?)',
    );
    final insertSearch = db.prepare(
      'INSERT INTO tag_search(term, search_key, tag_id, kind) VALUES (?, ?, ?, ?)',
    );

    var imported = 0;
    var aliases = 0;
    var skipped = 0;
    db.execute('BEGIN IMMEDIATE');
    try {
      final lines = input
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parsed = const CsvToListConverter(
          shouldParseNumbers: false,
        ).convert(line);
        if (parsed.isEmpty || parsed.first.length < 3) {
          skipped++;
          continue;
        }
        final row = parsed.first;
        final name = '${row[0]}'.trim().toLowerCase();
        final category = int.tryParse('${row[1]}');
        final postCount = int.tryParse('${row[2]}');
        if (name.isEmpty ||
            category == null ||
            postCount == null ||
            !allowedCategories.contains(category) ||
            !_isValidTag(name)) {
          skipped++;
          continue;
        }

        insertTag.execute([name, category, postCount]);
        final idRows = findTag.select([name]);
        if (idRows.isEmpty) {
          skipped++;
          continue;
        }
        final tagId = idRows.first['id'] as int;
        insertSearch.execute([name, _searchKey(name), tagId, 0]);
        imported++;

        if (row.length >= 4) {
          final seen = <String>{name};
          for (final rawAlias in '${row[3]}'.split(',')) {
            final alias = rawAlias.trim().toLowerCase();
            if (alias.isEmpty || !seen.add(alias) || !_isValidTag(alias)) {
              continue;
            }
            insertAlias.execute([tagId, alias]);
            if (db.updatedRows > 0) {
              insertSearch.execute([alias, _searchKey(alias), tagId, 1]);
              aliases++;
            }
          }
        }
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    } finally {
      insertTag.dispose();
      findTag.dispose();
      insertAlias.dispose();
      insertSearch.dispose();
    }

    final importedAt = DateTime.now().toUtc().toIso8601String();
    final metadata = <String, String>{
      'schema_version': '$catalogSchemaVersion',
      'data_version': ('${lock['commit']}').substring(0, 12),
      'source_url': '${lock['url']}',
      'source_format': 'tag_name,category,post_count,aliases',
      'source_sha256': actualHash.toString(),
      'source_commit': '${lock['commit']}',
      'imported_at': importedAt,
      'tag_count': '$imported',
      'alias_count': '$aliases',
    };
    final insertMeta = db.prepare(
      'INSERT INTO metadata(key, value) VALUES (?, ?)',
    );
    try {
      for (final entry in metadata.entries) {
        insertMeta.execute([entry.key, entry.value]);
      }
    } finally {
      insertMeta.dispose();
    }

    db.execute('INSERT INTO tag_search(tag_search) VALUES (\'optimize\')');
    db.execute('ANALYZE');
    final check = db.select('PRAGMA quick_check').first.values.first;
    if (check != 'ok') throw StateError('quick_check failed: $check');
    stdout.writeln(
      'Built ${output.path}: tags=$imported aliases=$aliases skipped=$skipped sha256=$actualHash',
    );
  } finally {
    db.dispose();
  }

  final outputHash = await sha256.bind(output.openRead()).first;
  final manifestFile = File(options.manifestPath);
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final databases = manifest['databases'] as Map<String, dynamic>;
  databases['tag_catalog.db'] = {
    'schemaVersion': catalogSchemaVersion,
    'dataVersion': ('${lock['commit']}').substring(0, 12),
    'sha256': outputHash.toString(),
    'size': await output.length(),
  };
  await manifestFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    encoding: utf8,
  );
}

void _createSchema(Database db) {
  db.execute('''
    PRAGMA journal_mode=DELETE;
    PRAGMA synchronous=OFF;
    CREATE TABLE metadata(
      key TEXT PRIMARY KEY NOT NULL,
      value TEXT NOT NULL
    );
    CREATE TABLE tags(
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      category INTEGER NOT NULL CHECK(category IN (0, 1, 3, 4, 5)),
      post_count INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE aliases(
      id INTEGER PRIMARY KEY,
      tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
      alias TEXT NOT NULL COLLATE NOCASE,
      UNIQUE(tag_id, alias)
    );
    CREATE INDEX idx_tags_category_count ON tags(category, post_count DESC);
    CREATE INDEX idx_aliases_alias ON aliases(alias COLLATE NOCASE);
    CREATE VIRTUAL TABLE tag_search USING fts5(
      term,
      search_key,
      tag_id UNINDEXED,
      kind UNINDEXED,
      tokenize='unicode61 remove_diacritics 2'
    );
  ''');
}

bool _isValidTag(String value) =>
    value.length <= 255 && !value.contains(RegExp(r'[\u0000-\u001f,]'));

String _searchKey(String value) =>
    value.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

class _Options {
  const _Options({
    required this.inputPath,
    required this.outputPath,
    required this.lockPath,
    required this.manifestPath,
  });

  final String inputPath;
  final String outputPath;
  final String lockPath;
  final String manifestPath;

  static _Options parse(List<String> args) {
    String value(String name, String fallback) {
      final prefix = '--$name=';
      final match = args.where((arg) => arg.startsWith(prefix));
      return match.isEmpty ? fallback : match.last.substring(prefix.length);
    }

    return _Options(
      inputPath: value(
        'input',
        'tool/tag_catalog/.cache/danbooru_e621_merged.csv',
      ),
      outputPath: value('output', 'assets/databases/tag_catalog.db'),
      lockPath: value('lock', 'tool/tag_catalog/source_lock.json'),
      manifestPath: value('manifest', 'assets/databases/manifest.json'),
    );
  }
}
