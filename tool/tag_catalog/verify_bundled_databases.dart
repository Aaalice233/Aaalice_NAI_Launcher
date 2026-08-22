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
  await _verifyCooccurrenceClientManifest();
  final entries = manifest['databases'] as Map<String, dynamic>;
  if (entries.keys.toSet().difference({'tag_catalog.db'}).isNotEmpty ||
      !entries.containsKey('tag_catalog.db')) {
    throw StateError('Only tag_catalog.db may be bundled: ${entries.keys}');
  }
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
      }
    } finally {
      db.dispose();
    }
    stdout.writeln('Verified ${file.path}');
  }
  for (final forbidden in [
    'assets/databases/translation.db',
    'assets/databases/cooccurrence.db',
  ]) {
    if (await File(forbidden).exists()) {
      throw StateError('$forbidden must not be packaged');
    }
  }
  final legacyTranslations = Directory('assets/translations');
  if (await legacyTranslations.exists() &&
      await legacyTranslations.list().any((entity) => entity is File)) {
    throw StateError('Build-only CSV files must not live in Flutter assets');
  }
}

Future<void> _verifyCooccurrenceClientManifest() async {
  final file = File('assets/data/cooccurrence_data_pack_manifest.json');
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final lock =
      jsonDecode(
            await File(
              'tool/database/cooccurrence_source_lock.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  final lockedRelease = Map<String, dynamic>.from(lock['release'] as Map);
  final lockedSource = Map<String, dynamic>.from(lock['source'] as Map);
  final lockedOutput = Map<String, dynamic>.from(lock['output'] as Map);
  final release = Map<String, dynamic>.from(manifest['release'] as Map);
  final archive = Map<String, dynamic>.from(manifest['archive'] as Map);
  final database = Map<String, dynamic>.from(manifest['database'] as Map);
  final counts = Map<String, dynamic>.from(manifest['counts'] as Map);
  final uri = Uri.parse(release['url'] as String);
  final releaseTag = release['tag'] as String;
  final archiveName = archive['name'] as String;
  final hashPattern = RegExp(r'^[0-9a-f]{64}$');
  final expectedPath =
      '/Aaalice233/Aaalice_NAI_Launcher/releases/download/'
      '$releaseTag/$archiveName';
  if (manifest['manifestVersion'] != 1 ||
      uri.scheme != 'https' ||
      uri.host != 'github.com' ||
      uri.path != expectedPath ||
      release['prerelease'] != true ||
      release['makeLatest'] != false ||
      !releaseTag.startsWith('autocomplete-data-cooccurrence-') ||
      archiveName != 'cooccurrence-v2.db.gz' ||
      !hashPattern.hasMatch(archive['sha256'] as String) ||
      !hashPattern.hasMatch(database['sha256'] as String) ||
      (archive['size'] as num).toInt() <= 0 ||
      (database['size'] as num).toInt() <= 0 ||
      (database['size'] as num).toInt() > 160 * 1024 * 1024 ||
      (archive['size'] as num).toInt() > 80 * 1024 * 1024 ||
      (manifest['schemaVersion'] as num).toInt() != 2 ||
      manifest['dataVersion'] != lock['dataVersion'] ||
      release['tag'] != lockedRelease['tag'] ||
      release['url'] != lockedRelease['url'] ||
      archive['sha256'] != lockedOutput['archiveSha256'] ||
      archive['size'] != lockedOutput['archiveSize'] ||
      database['sha256'] != lockedOutput['databaseSha256'] ||
      database['size'] != lockedOutput['databaseSize'] ||
      counts['sourcePairCount'] != lockedOutput['pairCount'] ||
      counts['selfRelationCount'] != lockedOutput['selfRelationCount'] ||
      counts['directedEdgeCount'] != lockedOutput['directedEdgeCount'] ||
      counts['tagCount'] != lockedOutput['tagCount']) {
    throw StateError('Invalid or unlocked co-occurrence client manifest');
  }
  final provenance = Map<String, dynamic>.from(manifest['provenance'] as Map);
  if (provenance['sourceRevision'] != lockedSource['revision'] ||
      provenance['sourceUrl'] != lockedSource['url'] ||
      provenance['sourceSha256'] != lockedSource['sha256'] ||
      provenance['sourceRecordCount'] != lockedSource['recordCount']) {
    throw StateError('Co-occurrence client provenance is not source-locked');
  }
  stdout.writeln('Verified ${file.path}');
}
