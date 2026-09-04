import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const catalogSchemaVersion = 3;
const supportedSourceCategories = {0, 1, 3, 4, 5, 7, 8, 9, 10, 11, 12, 14, 15};
const translationModes = {'missing': 0, 'override': 1};

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
  final expectedHash = lock['sha256'] as String;
  if (actualHash.toString() != expectedHash) {
    throw StateError(
      'Source SHA256 mismatch: expected=$expectedHash actual=$actualHash',
    );
  }

  final translationLock = Map<String, dynamic>.from(
    lock['translations'] as Map,
  );
  final translationInput = File(options.translationInputPath);
  if (!await translationInput.exists()) {
    throw StateError('Missing translation source: ${translationInput.path}');
  }
  final translationHash = await sha256.bind(translationInput.openRead()).first;
  if ('$translationHash' != translationLock['sha256']) {
    throw StateError(
      'Translation source SHA256 mismatch: '
      'expected=${translationLock['sha256']} actual=$translationHash',
    );
  }
  final translations = await _readTranslations(
    translationInput,
    translationLock,
  );
  final dataVersion = lock['dataVersion'] as String;
  final expectedDataVersion = sha256
      .convert(utf8.encode('$expectedHash:$translationHash'))
      .toString()
      .substring(0, 12);
  if (dataVersion != expectedDataVersion) {
    throw StateError(
      'Catalog dataVersion mismatch: '
      'expected=$expectedDataVersion actual=$dataVersion',
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
    final insertTranslation = db.prepare(
      'INSERT INTO zh_translations(tag, zh_cn, mode) VALUES (?, ?, ?)',
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
            !supportedSourceCategories.contains(category) ||
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
      final expectedTagCount = (lock['expectedTagCount'] as num?)?.toInt();
      final expectedAliasCount = (lock['expectedAliasCount'] as num?)?.toInt();
      if (expectedTagCount != null && imported != expectedTagCount) {
        throw StateError(
          'Imported tag count mismatch: expected=$expectedTagCount actual=$imported',
        );
      }
      if (expectedAliasCount != null && aliases != expectedAliasCount) {
        throw StateError(
          'Imported alias count mismatch: expected=$expectedAliasCount actual=$aliases',
        );
      }
      for (final translation in translations) {
        insertTranslation.execute([
          translation.tag,
          translation.zhCn,
          translationModes[translation.mode],
        ]);
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
      insertTranslation.dispose();
    }

    final metadata = <String, String>{
      'schema_version': '$catalogSchemaVersion',
      'data_version': dataVersion,
      'source_url': '${lock['url']}',
      'source_format': 'tag_name,category,post_count,aliases',
      'source_scope': 'danbooru_e621_full',
      'source_sha256': actualHash.toString(),
      'source_commit': '${lock['commit']}',
      'translation_source_sha256': '$translationHash',
      'translation_ffdkj_baseline_blob_sha':
          '${translationLock['ffdkjBaselineBlobSha']}',
      'tag_count': '$imported',
      'alias_count': '$aliases',
      'translation_count': '${translations.length}',
      'translation_override_count':
          '${translations.where((entry) => entry.mode == 'override').length}',
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
  final previousEntry = databases['tag_catalog.db'] as Map<String, dynamic>?;
  final outputSize = await output.length();
  final nextEntry = <String, dynamic>{
    'schemaVersion': catalogSchemaVersion,
    'dataVersion': dataVersion,
    'sha256': outputHash.toString(),
    'size': outputSize,
  };
  if (previousEntry?['dataVersion'] == dataVersion &&
      previousEntry?['sha256'] == outputHash.toString() &&
      previousEntry?['size'] == outputSize &&
      previousEntry?['release'] != null) {
    nextEntry['release'] = previousEntry!['release'];
  }
  databases['tag_catalog.db'] = nextEntry;
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
      category INTEGER NOT NULL CHECK(category IN (0, 1, 3, 4, 5, 7, 8, 9, 10, 11, 12, 14, 15)),
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
    CREATE TABLE zh_translations(
      tag TEXT PRIMARY KEY COLLATE NOCASE,
      zh_cn TEXT NOT NULL CHECK(TRIM(zh_cn) <> ''),
      mode INTEGER NOT NULL CHECK(mode IN (0, 1))
    ) WITHOUT ROWID;
  ''');
}

Future<List<_TranslationEntry>> _readTranslations(
  File input,
  Map<String, dynamic> lock,
) async {
  final document = jsonDecode(await input.readAsString());
  if (document is! Map<String, dynamic> || document['schemaVersion'] != 1) {
    throw StateError('Unsupported translation source schema');
  }
  final baseline = document['ffdkjBaseline'];
  if (baseline is! Map || baseline['blobSha'] != lock['ffdkjBaselineBlobSha']) {
    throw StateError('Translation ffdkj baseline does not match source lock');
  }
  final rawEntries = document['entries'];
  if (rawEntries is! List) {
    throw StateError('Translation source entries must be a list');
  }
  final entries = <_TranslationEntry>[];
  final seen = <String>{};
  for (final raw in rawEntries) {
    if (raw is! Map) throw StateError('Invalid translation source entry');
    final tag = '${raw['tag'] ?? ''}'.trim();
    final zhCn = '${raw['zhCn'] ?? ''}'.trim();
    final mode = '${raw['mode'] ?? ''}'.trim();
    if (tag != tag.toLowerCase() ||
        tag.contains(RegExp(r'[\s,\u0000-\u001f]')) ||
        !_isValidTag(tag) ||
        zhCn.isEmpty ||
        zhCn.contains(RegExp(r'[/／]')) ||
        !translationModes.containsKey(mode) ||
        !seen.add(tag)) {
      throw StateError('Invalid translation source entry for tag "$tag"');
    }
    entries.add(_TranslationEntry(tag: tag, zhCn: zhCn, mode: mode));
  }
  final expectedCount = (lock['expectedCount'] as num).toInt();
  final expectedOverrides = (lock['expectedOverrideCount'] as num).toInt();
  final actualOverrides = entries
      .where((entry) => entry.mode == 'override')
      .length;
  final expectedOverrideTags = (lock['overrideTags'] as List)
      .map((value) => '$value')
      .toSet();
  final actualOverrideTags = entries
      .where((entry) => entry.mode == 'override')
      .map((entry) => entry.tag)
      .toSet();
  if (entries.length != expectedCount || actualOverrides != expectedOverrides) {
    throw StateError(
      'Translation count mismatch: '
      'entries=${entries.length}/$expectedCount '
      'overrides=$actualOverrides/$expectedOverrides',
    );
  }
  if (actualOverrideTags.length != expectedOverrideTags.length ||
      !actualOverrideTags.containsAll(expectedOverrideTags)) {
    throw StateError(
      'Translation override tags mismatch: '
      'actual=$actualOverrideTags expected=$expectedOverrideTags',
    );
  }
  final requiredEntries = Map<String, dynamic>.from(
    lock['requiredEntries'] as Map? ?? const {},
  );
  final translationsByTag = {
    for (final entry in entries) entry.tag: entry.zhCn,
  };
  for (final required in requiredEntries.entries) {
    if (translationsByTag[required.key] != required.value) {
      throw StateError(
        'Required translation mismatch: '
        'tag=${required.key} expected=${required.value} '
        'actual=${translationsByTag[required.key]}',
      );
    }
  }
  return entries;
}

class _TranslationEntry {
  const _TranslationEntry({
    required this.tag,
    required this.zhCn,
    required this.mode,
  });

  final String tag;
  final String zhCn;
  final String mode;
}

bool _isValidTag(String value) =>
    value.length <= 255 && !value.contains(RegExp(r'[\u0000-\u001f,]'));

String _searchKey(String value) =>
    value.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

class _Options {
  const _Options({
    required this.inputPath,
    required this.translationInputPath,
    required this.outputPath,
    required this.lockPath,
    required this.manifestPath,
  });

  final String inputPath;
  final String translationInputPath;
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
      translationInputPath: value(
        'translation-input',
        'tool/tag_catalog/zh_translations.json',
      ),
      outputPath: value('output', 'assets/databases/tag_catalog.db'),
      lockPath: value('lock', 'tool/tag_catalog/source_lock.json'),
      manifestPath: value('manifest', 'assets/databases/manifest.json'),
    );
  }
}
