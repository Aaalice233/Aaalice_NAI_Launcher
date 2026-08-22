import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const _databaseSchemaVersion = 2;
const _manifestSchemaVersion = 1;
const _toolVersion = 2;
const _sqliteHeader = 'SQLite format 3\u0000';
const _defaultLockPath = 'tool/database/cooccurrence_source_lock.json';
const _defaultOutputDirectory = 'tool/.tmp/cooccurrence';
const _defaultClientManifestPath =
    'assets/data/cooccurrence_data_pack_manifest.json';
const _querySamples = <String>['1girl', 'solo', 'long_hair', 'breasts'];

Future<void> main(List<String> arguments) async {
  try {
    await buildCooccurrenceDataPack(arguments);
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('Co-occurrence data pack build failed: $error')
      ..writeln(stackTrace);
    exitCode = 1;
  }
}

/// Builds and verifies the locked co-occurrence data pack.
///
/// Exposed so fixture tests exercise the exact production entry point without
/// spawning a nested Dart process while Flutter owns the package build lock.
Future<void> buildCooccurrenceDataPack(List<String> arguments) =>
    _build(_Options.parse(arguments));

Future<void> _build(_Options options) async {
  final lockFile = File(options.lockPath).absolute;
  if (!await lockFile.exists()) {
    throw StateError('Missing source lock: ${lockFile.path}');
  }
  final lock = _asStringMap(jsonDecode(await lockFile.readAsString()));
  _validateLock(lock);

  final source = _asStringMap(lock['source']);
  final sourceFile = options.inputPath == null
      ? File('${options.outputDirectory}/${source['file']}').absolute
      : File(options.inputPath!).absolute;
  if (options.inputPath == null) {
    await _downloadSource(source, sourceFile);
  }
  await _verifySourceFile(source, sourceFile);

  final outputDirectory = Directory(options.outputDirectory).absolute;
  await outputDirectory.create(recursive: true);
  final databaseFile = File(
    '${outputDirectory.path}/cooccurrence-v$_databaseSchemaVersion.db',
  );
  final archiveFile = File('${databaseFile.path}.gz');
  final manifestFile = File('${outputDirectory.path}/manifest.json');
  final reportFile = File('${outputDirectory.path}/verification-report.json');
  final buildingFile = File('${databaseFile.path}.building');

  for (final file in [buildingFile, archiveFile, manifestFile, reportFile]) {
    if (await file.exists()) await file.delete();
  }

  _BuildStatistics statistics;
  try {
    statistics = await _buildDatabase(
      input: sourceFile,
      output: buildingFile,
      source: source,
      dataVersion: lock['dataVersion'] as String,
    );
    await _replaceFile(buildingFile, databaseFile);
    final verification = await _verifyDatabase(
      databaseFile,
      expectedDataVersion: lock['dataVersion'] as String,
      expectedPairCount: source['recordCount'] as int,
      maxDatabaseSize: _asStringMap(lock['limits'])['databaseSize'] as int,
      reportFile: reportFile,
    );
    await _gzipFile(databaseFile, archiveFile);
    final archiveSize = await archiveFile.length();
    final maximumArchiveSize =
        _asStringMap(lock['limits'])['archiveSize'] as int;
    if (archiveSize > maximumArchiveSize) {
      throw StateError(
        'Compressed data pack is too large: $archiveSize > '
        '$maximumArchiveSize bytes',
      );
    }

    final databaseSha256 = await _sha256Of(databaseFile);
    final archiveSha256 = await _sha256Of(archiveFile);
    final manifest = _createManifest(
      lock: lock,
      source: source,
      statistics: statistics,
      verification: verification,
      databaseFile: databaseFile,
      databaseSha256: databaseSha256,
      archiveFile: archiveFile,
      archiveSha256: archiveSha256,
    );
    await _writeJson(manifestFile, manifest);

    if (options.updateLock) {
      final output = _asStringMap(lock['output']);
      output
        ..['databaseSha256'] = databaseSha256
        ..['databaseSize'] = await databaseFile.length()
        ..['archiveSha256'] = archiveSha256
        ..['archiveSize'] = archiveSize
        ..['tagCount'] = statistics.tagCount
        ..['pairCount'] = statistics.pairCount
        ..['selfRelationCount'] = statistics.selfRelationCount
        ..['directedEdgeCount'] = statistics.directedEdgeCount;
      lock['output'] = output;
      await _writeJson(lockFile, lock);
      await _writeJson(File(options.clientManifestPath), manifest);
    } else {
      _verifyLockedOutput(lock, manifest);
    }

    stdout.writeln(
      'Built ${databaseFile.path}\n'
      '  source pairs: ${statistics.pairCount}\n'
      '  tags: ${statistics.tagCount}\n'
      '  directed edges: ${statistics.directedEdgeCount}\n'
      '  database: ${await databaseFile.length()} bytes ($databaseSha256)\n'
      '  gzip: $archiveSize bytes ($archiveSha256)\n'
      '  verification: ${reportFile.path}',
    );
  } catch (_) {
    if (await buildingFile.exists()) await buildingFile.delete();
    rethrow;
  }
}

void _validateLock(Map<String, dynamic> lock) {
  if (lock['schemaVersion'] != 2) {
    throw StateError('Unsupported source lock schemaVersion');
  }
  if (lock['toolVersion'] != _toolVersion) {
    throw StateError(
      'Source lock toolVersion must be $_toolVersion, got '
      '${lock['toolVersion']}',
    );
  }
  final dataVersion = lock['dataVersion'];
  if (dataVersion is! String || dataVersion.isEmpty) {
    throw StateError('Source lock dataVersion is required');
  }
  final source = _asStringMap(lock['source']);
  final revision = source['revision'];
  final sourceUrl = Uri.tryParse('${source['url']}');
  if (revision is! String || revision.length != 40) {
    throw StateError('Source revision must be a full 40-character commit');
  }
  if (sourceUrl == null ||
      sourceUrl.scheme != 'https' ||
      sourceUrl.host != 'huggingface.co' ||
      !sourceUrl.pathSegments.contains(revision)) {
    throw StateError('Source URL must be pinned to the locked revision');
  }
  _requireSha256(source['sha256'], 'source.sha256');
  for (final key in ['size', 'recordCount']) {
    if (source[key] is! int || (source[key] as int) <= 0) {
      throw StateError('source.$key must be a positive integer');
    }
  }
  final release = _asStringMap(lock['release']);
  final releaseUri = Uri.tryParse('${release['url']}');
  final releaseTag = release['tag'];
  if (releaseUri == null ||
      releaseUri.scheme != 'https' ||
      releaseUri.host != 'github.com' ||
      releaseUri.pathSegments.length != 6 ||
      releaseUri.pathSegments[0] != 'Aaalice233' ||
      releaseUri.pathSegments[1] != 'Aaalice_NAI_Launcher' ||
      releaseUri.pathSegments[2] != 'releases' ||
      releaseUri.pathSegments[3] != 'download' ||
      releaseTag is! String ||
      releaseUri.pathSegments[4] != releaseTag ||
      releaseUri.pathSegments.last != release['asset']) {
    throw StateError('release.url is not an allowed immutable data asset URL');
  }
  final limits = _asStringMap(lock['limits']);
  for (final key in ['databaseSize', 'archiveSize']) {
    if (limits[key] is! int || (limits[key] as int) <= 0) {
      throw StateError('limits.$key must be a positive integer');
    }
  }
}

Future<void> _downloadSource(
  Map<String, dynamic> source,
  File destination,
) async {
  if (await destination.exists()) {
    try {
      await _verifySourceFile(source, destination);
      stdout.writeln('Using verified cached source: ${destination.path}');
      return;
    } on Object {
      await destination.delete();
    }
  }

  await destination.parent.create(recursive: true);
  final temporary = File('${destination.path}.downloading');
  if (await temporary.exists()) await temporary.delete();
  final uri = Uri.parse(source['url'] as String);
  final client = HttpClient()..autoUncompress = false;
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Source download returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final expectedSize = source['size'] as int;
    final contentLength = response.contentLength;
    if (contentLength >= 0 && contentLength != expectedSize) {
      await response.drain<void>();
      throw StateError(
        'Source Content-Length mismatch: expected=$expectedSize '
        'actual=$contentLength',
      );
    }
    final output = temporary.openWrite();
    try {
      await response.pipe(output);
    } catch (_) {
      await output.close();
      rethrow;
    }
    await _verifySourceFile(source, temporary);
    await _replaceFile(temporary, destination);
  } finally {
    client.close(force: true);
    if (await temporary.exists()) await temporary.delete();
  }
}

Future<void> _verifySourceFile(
  Map<String, dynamic> source,
  File sourceFile,
) async {
  if (!await sourceFile.exists()) {
    throw StateError('Missing co-occurrence source: ${sourceFile.path}');
  }
  final expectedSize = source['size'] as int;
  final actualSize = await sourceFile.length();
  if (actualSize != expectedSize) {
    throw StateError(
      'Source size mismatch: expected=$expectedSize actual=$actualSize',
    );
  }
  final expectedSha256 = source['sha256'] as String;
  final actualSha256 = await _sha256Of(sourceFile);
  if (actualSha256 != expectedSha256) {
    throw StateError(
      'Source SHA256 mismatch: expected=$expectedSha256 '
      'actual=$actualSha256',
    );
  }
}

Future<_BuildStatistics> _buildDatabase({
  required File input,
  required File output,
  required Map<String, dynamic> source,
  required String dataVersion,
}) async {
  if (await output.exists()) await output.delete();
  final database = sqlite3.open(output.path);
  final tagIds = <String, int>{};
  var nextTagId = 1;
  var rowNumber = 0;
  var pairCount = 0;
  var selfRelationCount = 0;
  PreparedStatement? insertTag;
  PreparedStatement? insertPair;
  try {
    database.execute('''
      PRAGMA page_size=4096;
      PRAGMA journal_mode=OFF;
      PRAGMA synchronous=OFF;
      PRAGMA temp_store=FILE;
      PRAGMA locking_mode=EXCLUSIVE;
      CREATE TABLE metadata(
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );
      CREATE TABLE tags(
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE
      );
      CREATE TABLE edges(
        source_tag_id INTEGER NOT NULL,
        target_tag_id INTEGER NOT NULL,
        count INTEGER NOT NULL CHECK(count > 0),
        PRIMARY KEY(source_tag_id, count DESC, target_tag_id)
      ) WITHOUT ROWID;
      CREATE TABLE source_pairs(
        tag_a_id INTEGER NOT NULL,
        tag_b_id INTEGER NOT NULL,
        count INTEGER NOT NULL CHECK(count > 0),
        PRIMARY KEY(tag_a_id, tag_b_id)
      ) WITHOUT ROWID;
    ''');
    insertTag = database.prepare('INSERT INTO tags(id, name) VALUES (?, ?)');
    insertPair = database.prepare(
      'INSERT OR IGNORE INTO source_pairs(tag_a_id, tag_b_id, count) '
      'VALUES (?, ?, ?)',
    );

    int idForTag(String tag) {
      final existing = tagIds[tag];
      if (existing != null) return existing;
      final id = nextTagId++;
      insertTag!.execute([id, tag]);
      tagIds[tag] = id;
      return id;
    }

    database.execute('BEGIN IMMEDIATE');
    try {
      final rows = input
          .openRead()
          .transform(const Utf8Decoder())
          .transform(
            const CsvToListConverter(
              eol: '\n',
              shouldParseNumbers: false,
              allowInvalid: false,
            ),
          );
      await for (final dynamic csvRow in rows) {
        rowNumber++;
        final row = List<dynamic>.from(csvRow as List);
        if (rowNumber == 1) {
          if (row.length != 3 ||
              '${row[0]}'.trim() != 'tag_a' ||
              '${row[1]}'.trim() != 'tag_b' ||
              '${row[2]}'.trim() != 'count') {
            throw FormatException(
              'Unexpected CSV header at row 1: ${jsonEncode(row)}',
            );
          }
          continue;
        }
        if (row.length != 3) {
          throw FormatException(
            'CSV row $rowNumber must contain exactly 3 fields, got '
            '${row.length}',
          );
        }
        final tagA = _normalizeTag(row[0], rowNumber, 'tag_a');
        final tagB = _normalizeTag(row[1], rowNumber, 'tag_b');
        final count = _parsePositiveCount(row[2], rowNumber);
        final firstId = idForTag(tagA);
        final secondId = idForTag(tagB);
        final tagAId = math.min(firstId, secondId);
        final tagBId = math.max(firstId, secondId);
        insertPair.execute([tagAId, tagBId, count]);
        if (database.updatedRows != 1) {
          throw FormatException(
            'Duplicate unordered relation at CSV row $rowNumber: '
            '$tagA <-> $tagB',
          );
        }
        pairCount++;
        if (tagAId == tagBId) selfRelationCount++;
        if (pairCount % 100000 == 0) {
          stdout.writeln('Validated $pairCount source relations…');
        }
      }
      if (rowNumber == 0) {
        throw const FormatException('Co-occurrence CSV is empty');
      }
      final expectedPairCount = source['recordCount'] as int;
      if (pairCount != expectedPairCount) {
        throw StateError(
          'Source record count mismatch: expected=$expectedPairCount '
          'actual=$pairCount',
        );
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }

    stdout.writeln('Building directed adjacency table…');
    database.execute('''
      BEGIN IMMEDIATE;
      INSERT INTO edges(source_tag_id, target_tag_id, count)
      SELECT tag_a_id, tag_b_id, count FROM source_pairs
      UNION ALL
      SELECT tag_b_id, tag_a_id, count FROM source_pairs
      WHERE tag_a_id != tag_b_id;
      DROP TABLE source_pairs;
      COMMIT;
    ''');
    final directedEdgeCount = pairCount * 2 - selfRelationCount;
    final actualEdgeCount =
        database.select('SELECT COUNT(*) AS value FROM edges').single['value']
            as int;
    if (actualEdgeCount != directedEdgeCount) {
      throw StateError(
        'Directed edge count mismatch: expected=$directedEdgeCount '
        'actual=$actualEdgeCount',
      );
    }

    final metadata = <String, String>{
      'schema_version': '$_databaseSchemaVersion',
      'data_version': dataVersion,
      'source_dataset': '${source['dataset']}',
      'source_revision': '${source['revision']}',
      'source_url': '${source['url']}',
      'source_sha256': '${source['sha256']}',
      'source_size': '${source['size']}',
      'source_pair_count': '$pairCount',
      'tag_count': '${tagIds.length}',
      'self_relation_count': '$selfRelationCount',
      'directed_edge_count': '$directedEdgeCount',
      'license': 'MIT',
      'license_url':
          'https://github.com/newtextdoc1111/danbooru-tag-csv/blob/'
          '${source['revision']}/LICENSE',
      'builder_version': '$_toolVersion',
    };
    final insertMetadata = database.prepare(
      'INSERT INTO metadata(key, value) VALUES (?, ?)',
    );
    try {
      database.execute('BEGIN IMMEDIATE');
      for (final entry in metadata.entries) {
        insertMetadata.execute([entry.key, entry.value]);
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    } finally {
      insertMetadata.dispose();
    }
    database.execute('VACUUM');

    return _BuildStatistics(
      pairCount: pairCount,
      selfRelationCount: selfRelationCount,
      directedEdgeCount: directedEdgeCount,
      tagCount: tagIds.length,
    );
  } finally {
    insertTag?.dispose();
    insertPair?.dispose();
    database.dispose();
  }
}

Future<_VerificationResult> _verifyDatabase(
  File file, {
  required String expectedDataVersion,
  required int expectedPairCount,
  required int maxDatabaseSize,
  required File reportFile,
}) async {
  final size = await file.length();
  if (size > maxDatabaseSize) {
    throw StateError('Database is too large: $size > $maxDatabaseSize bytes');
  }
  final header = await file.openRead(0, 16).transform(utf8.decoder).join();
  if (header != _sqliteHeader) {
    throw StateError('Output does not have a valid SQLite header');
  }

  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    final quickCheck = database
        .select('PRAGMA quick_check')
        .single
        .values
        .single;
    if (quickCheck != 'ok') {
      throw StateError('PRAGMA quick_check failed: $quickCheck');
    }
    final tables = database
        .select("SELECT name, sql FROM sqlite_master WHERE type='table'")
        .map((row) => '${row['name']}')
        .toSet();
    if (!tables.containsAll(const ['metadata', 'tags', 'edges']) ||
        tables.length != 3) {
      throw StateError('Unexpected co-occurrence schema tables: $tables');
    }
    final metadata = <String, String>{
      for (final row in database.select('SELECT key, value FROM metadata'))
        row['key'] as String: row['value'] as String,
    };
    if (metadata['schema_version'] != '$_databaseSchemaVersion' ||
        metadata['data_version'] != expectedDataVersion ||
        int.tryParse(metadata['source_pair_count'] ?? '') !=
            expectedPairCount) {
      throw StateError('Database metadata does not match the source lock');
    }
    final tagCount =
        database.select('SELECT COUNT(*) AS value FROM tags').single['value']
            as int;
    final edgeCount =
        database.select('SELECT COUNT(*) AS value FROM edges').single['value']
            as int;
    if (tagCount != int.parse(metadata['tag_count']!) ||
        edgeCount != int.parse(metadata['directed_edge_count']!)) {
      throw StateError('Database row counts do not match metadata');
    }

    final queryPlan = database
        .select(
          '''
          EXPLAIN QUERY PLAN
          SELECT target.name, edge.count
          FROM tags AS source
          JOIN edges AS edge ON edge.source_tag_id = source.id
          JOIN tags AS target ON target.id = edge.target_tag_id
          WHERE source.name = ? AND edge.count >= ?
          ORDER BY edge.count DESC, edge.target_tag_id
          LIMIT ?
        ''',
          ['1girl', 1, 100],
        )
        .map((row) => '${row['detail']}')
        .toList(growable: false);
    final normalizedPlan = queryPlan.join('\n').toUpperCase();
    if (!normalizedPlan.contains('SEARCH SOURCE USING') ||
        !normalizedPlan.contains('SEARCH EDGE USING PRIMARY KEY') ||
        normalizedPlan.contains('SCAN EDGE')) {
      throw StateError(
        'Related-tag query does not use the expected indexes:\n'
        '${queryPlan.join('\n')}',
      );
    }

    final benchmarks = <Map<String, Object>>[];
    for (final tag in _querySamples) {
      final exists = database.select(
        'SELECT 1 FROM tags WHERE name = ? LIMIT 1',
        [tag],
      );
      if (exists.isEmpty) continue;
      final hotDurations = <int>[];
      _runRelatedQuery(database, tag, 100);
      for (var iteration = 0; iteration < 20; iteration++) {
        final watch = Stopwatch()..start();
        _runRelatedQuery(database, tag, 100);
        watch.stop();
        hotDurations.add(watch.elapsedMicroseconds);
      }
      hotDurations.sort();
      final fullWatch = Stopwatch()..start();
      final fullRows = _runRelatedQuery(database, tag, null);
      fullWatch.stop();
      final hotP95Milliseconds =
          hotDurations[(hotDurations.length * 0.95).ceil() - 1] / 1000;
      final fullQueryMilliseconds = fullWatch.elapsedMicroseconds / 1000;
      if (hotP95Milliseconds > 50) {
        throw StateError(
          'Top-100 hot-query p95 exceeded 50ms for $tag: '
          '${hotP95Milliseconds.toStringAsFixed(3)}ms',
        );
      }
      if (fullQueryMilliseconds > 200) {
        throw StateError(
          'Full related-tag query exceeded 200ms for $tag: '
          '${fullQueryMilliseconds.toStringAsFixed(3)}ms',
        );
      }
      benchmarks.add({
        'tag': tag,
        'top100HotP95Milliseconds': hotP95Milliseconds,
        'fullQueryMilliseconds': fullQueryMilliseconds,
        'fullRowCount': fullRows,
      });
    }
    final result = _VerificationResult(
      tagCount: tagCount,
      directedEdgeCount: edgeCount,
      queryPlan: queryPlan,
      benchmarks: benchmarks,
    );
    await _writeJson(reportFile, {
      'schemaVersion': _databaseSchemaVersion,
      'databaseSize': size,
      'tagCount': tagCount,
      'sourcePairCount': expectedPairCount,
      'directedEdgeCount': edgeCount,
      'quickCheck': 'ok',
      'queryPlan': queryPlan,
      'benchmarks': benchmarks,
    });
    return result;
  } finally {
    database.dispose();
  }
}

int _runRelatedQuery(Database database, String tag, int? limit) {
  final rows = database.select(
    '''
    SELECT target.name, edge.count
    FROM tags AS source
    JOIN edges AS edge ON edge.source_tag_id = source.id
    JOIN tags AS target ON target.id = edge.target_tag_id
    WHERE source.name = ? AND edge.count >= 1
    ORDER BY edge.count DESC, edge.target_tag_id
    ${limit == null ? '' : 'LIMIT $limit'}
  ''',
    [tag],
  );
  return rows.length;
}

Future<void> _gzipFile(File input, File output) async {
  final temporary = File('${output.path}.compressing');
  if (await temporary.exists()) await temporary.delete();
  final sink = temporary.openWrite();
  try {
    await input
        .openRead()
        .transform(ZLibEncoder(gzip: true, level: 9))
        .pipe(sink);
  } catch (_) {
    await sink.close();
    rethrow;
  }
  await _replaceFile(temporary, output);
}

Map<String, dynamic> _createManifest({
  required Map<String, dynamic> lock,
  required Map<String, dynamic> source,
  required _BuildStatistics statistics,
  required _VerificationResult verification,
  required File databaseFile,
  required String databaseSha256,
  required File archiveFile,
  required String archiveSha256,
}) {
  final release = _asStringMap(lock['release']);
  return {
    'manifestVersion': _manifestSchemaVersion,
    'schemaVersion': _databaseSchemaVersion,
    'dataVersion': lock['dataVersion'],
    'release': {
      'tag': release['tag'],
      'url': release['url'],
      'prerelease': release['prerelease'],
      'makeLatest': release['makeLatest'],
    },
    'archive': {
      'name': release['asset'],
      'size': archiveFile.lengthSync(),
      'sha256': archiveSha256,
    },
    'database': {
      'name': 'cooccurrence-v$_databaseSchemaVersion.db',
      'size': databaseFile.lengthSync(),
      'sha256': databaseSha256,
    },
    'counts': {
      'tagCount': statistics.tagCount,
      'sourcePairCount': statistics.pairCount,
      'selfRelationCount': statistics.selfRelationCount,
      'directedEdgeCount': statistics.directedEdgeCount,
    },
    'provenance': {
      'dataset': source['dataset'],
      'sourceRevision': source['revision'],
      'sourceFile': source['file'],
      'sourceUrl': source['url'],
      'sourceSize': source['size'],
      'sourceSha256': source['sha256'],
      'sourceRecordCount': source['recordCount'],
      'license': 'MIT',
      'licenseUrl':
          'https://github.com/newtextdoc1111/danbooru-tag-csv/blob/'
          '${source['revision']}/LICENSE',
    },
    'verification': {'quickCheck': 'ok', 'queryPlan': verification.queryPlan},
  };
}

void _verifyLockedOutput(
  Map<String, dynamic> lock,
  Map<String, dynamic> manifest,
) {
  final output = _asStringMap(lock['output']);
  final database = _asStringMap(manifest['database']);
  final archive = _asStringMap(manifest['archive']);
  final counts = _asStringMap(manifest['counts']);
  final expected = <String, dynamic>{
    'databaseSha256': database['sha256'],
    'databaseSize': database['size'],
    'archiveSha256': archive['sha256'],
    'archiveSize': archive['size'],
    'tagCount': counts['tagCount'],
    'pairCount': counts['sourcePairCount'],
    'selfRelationCount': counts['selfRelationCount'],
    'directedEdgeCount': counts['directedEdgeCount'],
  };
  for (final entry in expected.entries) {
    if (output[entry.key] != entry.value) {
      throw StateError(
        'Deterministic output mismatch for ${entry.key}: '
        'lock=${output[entry.key]} actual=${entry.value}. '
        'Run with --update-lock only when intentionally publishing a new '
        'immutable data version.',
      );
    }
  }
}

String _normalizeTag(Object? value, int rowNumber, String field) {
  if (value is! String) {
    throw FormatException('CSV row $rowNumber $field must be text');
  }
  final tag = value.trim().toLowerCase();
  if (tag.isEmpty ||
      tag.length > 255 ||
      tag.contains(RegExp(r'[\u0000-\u001f]'))) {
    throw FormatException('CSV row $rowNumber contains an invalid $field');
  }
  return tag;
}

int _parsePositiveCount(Object? value, int rowNumber) {
  if (value is! String || !RegExp(r'^\d+(?:\.0+)?$').hasMatch(value.trim())) {
    throw FormatException(
      'CSV row $rowNumber count is not a positive integer: $value',
    );
  }
  final integerPart = value.trim().split('.').first;
  final count = int.tryParse(integerPart);
  if (count == null || count <= 0) {
    throw FormatException(
      'CSV row $rowNumber count is not a positive integer: $value',
    );
  }
  return count;
}

Future<String> _sha256Of(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

Future<void> _replaceFile(File temporary, File destination) async {
  await destination.parent.create(recursive: true);
  final backup = File('${destination.path}.backup');
  if (await backup.exists()) await backup.delete();
  final hadDestination = await destination.exists();
  if (hadDestination) await destination.rename(backup.path);
  try {
    await temporary.rename(destination.path);
    if (await backup.exists()) await backup.delete();
  } catch (_) {
    if (await destination.exists()) await destination.delete();
    if (await backup.exists()) await backup.rename(destination.path);
    rethrow;
  }
}

Future<void> _writeJson(File file, Object value) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.writing');
  await temporary.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    encoding: utf8,
    flush: true,
  );
  await _replaceFile(temporary, file);
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object');
  return value.map((key, value) => MapEntry('$key', value));
}

void _requireSha256(Object? value, String field) {
  if (value is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw StateError('$field must be a lowercase SHA256 digest');
  }
}

class _BuildStatistics {
  const _BuildStatistics({
    required this.pairCount,
    required this.selfRelationCount,
    required this.directedEdgeCount,
    required this.tagCount,
  });

  final int pairCount;
  final int selfRelationCount;
  final int directedEdgeCount;
  final int tagCount;
}

class _VerificationResult {
  const _VerificationResult({
    required this.tagCount,
    required this.directedEdgeCount,
    required this.queryPlan,
    required this.benchmarks,
  });

  final int tagCount;
  final int directedEdgeCount;
  final List<String> queryPlan;
  final List<Map<String, Object>> benchmarks;
}

class _Options {
  const _Options({
    required this.lockPath,
    required this.outputDirectory,
    required this.clientManifestPath,
    required this.inputPath,
    required this.updateLock,
  });

  final String lockPath;
  final String outputDirectory;
  final String clientManifestPath;
  final String? inputPath;
  final bool updateLock;

  static _Options parse(List<String> arguments) {
    String? value(String name) {
      final prefix = '--$name=';
      final matches = arguments.where(
        (argument) => argument.startsWith(prefix),
      );
      return matches.isEmpty ? null : matches.last.substring(prefix.length);
    }

    final supported = <String>{
      '--update-lock',
      ...arguments.where((argument) => argument.startsWith('--lock=')),
      ...arguments.where((argument) => argument.startsWith('--output-dir=')),
      ...arguments.where(
        (argument) => argument.startsWith('--client-manifest='),
      ),
      ...arguments.where((argument) => argument.startsWith('--input=')),
    };
    final unknown = arguments.where(
      (argument) => !supported.contains(argument),
    );
    if (unknown.isNotEmpty) {
      throw ArgumentError('Unknown arguments: ${unknown.join(', ')}');
    }
    return _Options(
      lockPath: value('lock') ?? _defaultLockPath,
      outputDirectory: value('output-dir') ?? _defaultOutputDirectory,
      clientManifestPath:
          value('client-manifest') ?? _defaultClientManifestPath,
      inputPath: value('input'),
      updateLock: arguments.contains('--update-lock'),
    );
  }
}
