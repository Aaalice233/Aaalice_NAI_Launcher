import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
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
