import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  final sourceLock =
      jsonDecode(await File('tool/tag_catalog/source_lock.json').readAsString())
          as Map<String, dynamic>;
  final manifest =
      jsonDecode(await File('assets/databases/manifest.json').readAsString())
          as Map<String, dynamic>;
  final entries = manifest['databases'] as Map<String, dynamic>;
  for (final entry in entries.entries) {
    final file = File('assets/databases/${entry.key}');
    if (!await file.exists() || await file.length() < 1024) {
      throw StateError('Missing database or LFS pointer: ${file.path}');
    }
    final header = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    if (!ascii.decode(header).startsWith('SQLite format 3')) {
      throw StateError('Invalid SQLite header: ${file.path}');
    }
    final expected = (entry.value as Map)['sha256'] as String;
    final actual = await sha256.bind(file.openRead()).first;
    if ('$actual' != expected) {
      throw StateError('SHA256 mismatch for ${file.path}');
    }
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      final check = db.select('PRAGMA quick_check').first.values.first;
      if (check != 'ok') {
        throw StateError('quick_check failed for ${file.path}');
      }
      if (entry.key == 'tag_catalog.db') {
        for (final table in ['metadata', 'tags', 'aliases', 'tag_search']) {
          if (db.select("SELECT 1 FROM sqlite_master WHERE name = ?", [
            table,
          ]).isEmpty) {
            throw StateError('Missing $table in ${file.path}');
          }
        }
        final metadata = {
          for (final row in db.select('SELECT key, value FROM metadata'))
            row['key'] as String: row['value'] as String,
        };
        final expectedTags = (sourceLock['expectedTagCount'] as num).toInt();
        final expectedAliases = (sourceLock['expectedAliasCount'] as num)
            .toInt();
        final actualTags =
            db.select('SELECT COUNT(*) AS count FROM tags').single['count']
                as int;
        final actualAliases =
            db.select('SELECT COUNT(*) AS count FROM aliases').single['count']
                as int;
        if (actualTags != expectedTags || actualAliases != expectedAliases) {
          throw StateError(
            'Incomplete merged catalog: tags=$actualTags/$expectedTags '
            'aliases=$actualAliases/$expectedAliases',
          );
        }
        if (metadata['source_scope'] != 'danbooru_e621_full') {
          throw StateError('Tag catalog is not the complete merged source');
        }
        final expectedCategories = (sourceLock['includedCategories'] as List)
            .map((value) => (value as num).toInt())
            .toSet();
        final actualCategories = db
            .select('SELECT DISTINCT category FROM tags')
            .map((row) => row['category'] as int)
            .toSet();
        if (actualCategories.length != expectedCategories.length ||
            !actualCategories.containsAll(expectedCategories)) {
          throw StateError(
            'Tag category mismatch: expected=$expectedCategories '
            'actual=$actualCategories',
          );
        }
      } else if (entry.key == 'cooccurrence.db') {
        final columns = db
            .select('PRAGMA table_info(cooccurrences)')
            .map((row) => row['name'] as String)
            .toSet();
        if (!columns.containsAll({'tag1', 'tag2', 'count'})) {
          throw StateError('Invalid cooccurrences columns: $columns');
        }
      }
    } finally {
      db.dispose();
    }
    stdout.writeln('Verified ${file.path}');
  }
  if (await File('assets/databases/translation.db').exists()) {
    throw StateError('Legacy translation.db must not be packaged');
  }
}
