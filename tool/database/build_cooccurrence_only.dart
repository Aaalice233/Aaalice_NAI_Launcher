import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

const _schemaVersion = 1;

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final input = File(options.inputPath);
  if (!await input.exists()) {
    stderr.writeln('Missing co-occurrence CSV: ${input.path}');
    exitCode = 2;
    return;
  }

  final lockFile = File(options.lockPath);
  final lock =
      jsonDecode(await lockFile.readAsString()) as Map<String, dynamic>;
  final source = lock['source'] as Map<String, dynamic>;
  final actualSourceHash = (await sha256.bind(input.openRead()).first)
      .toString();
  final expectedSourceHash = source['sha256'] as String?;
  if (actualSourceHash != expectedSourceHash) {
    throw StateError(
      'Source SHA256 mismatch: expected=$expectedSourceHash '
      'actual=$actualSourceHash',
    );
  }

  final output = File(options.outputPath).absolute;
  final temporary = File('${output.path}.building');
  await output.parent.create(recursive: true);
  if (await temporary.exists()) await temporary.delete();

  var imported = 0;
  var skipped = 0;
  Database? database;
  try {
    database = sqlite3.open(temporary.path);
    database.execute('''
      PRAGMA journal_mode=DELETE;
      PRAGMA synchronous=OFF;
      PRAGMA temp_store=MEMORY;
      CREATE TABLE metadata(
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );
      CREATE TABLE cooccurrences(
        id INTEGER PRIMARY KEY,
        tag1 TEXT NOT NULL COLLATE NOCASE,
        tag2 TEXT NOT NULL COLLATE NOCASE,
        count INTEGER NOT NULL CHECK(count >= 0),
        cooccurrence_score REAL NOT NULL DEFAULT 0
      );
    ''');

    final insert = database.prepare(
      'INSERT INTO cooccurrences(tag1, tag2, count) VALUES (?, ?, ?)',
    );
    database.execute('BEGIN IMMEDIATE');
    try {
      var isHeader = true;
      final lines = input
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (isHeader) {
          isHeader = false;
          continue;
        }
        if (line.trim().isEmpty) continue;
        final parsed = const CsvToListConverter(
          shouldParseNumbers: false,
        ).convert(line);
        if (parsed.isEmpty || parsed.first.length < 3) {
          skipped++;
          continue;
        }
        final row = parsed.first;
        final tag1 = '${row[0]}'.trim().toLowerCase();
        final tag2 = '${row[1]}'.trim().toLowerCase();
        final count = double.tryParse('${row[2]}')?.round();
        if (!_isValidTag(tag1) ||
            !_isValidTag(tag2) ||
            tag1 == tag2 ||
            count == null ||
            count < 0) {
          skipped++;
          continue;
        }
        insert.execute([tag1, tag2, count]);
        imported++;
        if (imported % 100000 == 0) {
          stdout.writeln('Imported $imported co-occurrence pairs…');
        }
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    } finally {
      insert.dispose();
    }

    database.execute('''
      CREATE INDEX idx_tag1 ON cooccurrences(tag1);
      CREATE INDEX idx_tag2 ON cooccurrences(tag2);
      CREATE INDEX idx_count ON cooccurrences(count DESC);
      ANALYZE;
    ''');
    final metadata = database.prepare(
      'INSERT INTO metadata(key, value) VALUES (?, ?)',
    );
    try {
      final values = <String, String>{
        'schema_version': '$_schemaVersion',
        'source_dataset': '${source['dataset']}',
        'source_revision': '${source['revision']}',
        'source_url': '${source['url']}',
        'source_sha256': actualSourceHash,
        'record_count': '$imported',
      };
      for (final entry in values.entries) {
        metadata.execute([entry.key, entry.value]);
      }
    } finally {
      metadata.dispose();
    }

    final quickCheck = database.select('PRAGMA quick_check').first.values.first;
    if (quickCheck != 'ok') {
      throw StateError(
        'Co-occurrence database quick_check failed: $quickCheck',
      );
    }
    database.dispose();
    database = null;

    await _atomicReplace(temporary, output);
    final outputHash = (await sha256.bind(output.openRead()).first).toString();
    final outputSize = await output.length();
    await _updateManifest(
      File(options.manifestPath),
      sha: outputHash,
      size: outputSize,
      dataVersion: '${source['revision']}'.substring(0, 12),
    );

    final outputLock = lock['output'] as Map<String, dynamic>;
    outputLock
      ..['path'] = options.outputPath
      ..['sha256'] = outputHash
      ..['size'] = outputSize
      ..['recordCount'] = imported;
    await lockFile.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(lock)}\n',
      encoding: utf8,
    );

    stdout.writeln(
      'Built ${output.path}: records=$imported skipped=$skipped '
      'sha256=$outputHash',
    );
  } catch (_) {
    database?.dispose();
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
}

Future<void> _atomicReplace(File temporary, File output) async {
  final backup = File('${output.path}.backup');
  if (await backup.exists()) await backup.delete();
  final hadOutput = await output.exists();
  if (hadOutput) await output.rename(backup.path);
  try {
    await temporary.rename(output.path);
    if (await backup.exists()) await backup.delete();
  } catch (_) {
    if (await output.exists()) await output.delete();
    if (await backup.exists()) await backup.rename(output.path);
    rethrow;
  }
}

Future<void> _updateManifest(
  File file, {
  required String sha,
  required int size,
  required String dataVersion,
}) async {
  final manifest =
      jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final databases = manifest['databases'] as Map<String, dynamic>;
  databases['cooccurrence.db'] = {
    'schemaVersion': _schemaVersion,
    'dataVersion': dataVersion,
    'sha256': sha,
    'size': size,
  };
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    encoding: utf8,
  );
}

bool _isValidTag(String value) =>
    value.isNotEmpty &&
    value.length <= 255 &&
    !value.contains(RegExp(r'[\u0000-\u001f,]'));

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

  static _Options parse(List<String> arguments) {
    String value(String name, String fallback) {
      final prefix = '--$name=';
      final matches = arguments.where(
        (argument) => argument.startsWith(prefix),
      );
      return matches.isEmpty ? fallback : matches.last.substring(prefix.length);
    }

    return _Options(
      inputPath: value(
        'input',
        'assets/translations/hf_danbooru_cooccurrence.csv',
      ),
      outputPath: value('output', 'assets/databases/cooccurrence.db'),
      lockPath: value('lock', 'tool/database/cooccurrence_source_lock.json'),
      manifestPath: value('manifest', 'assets/databases/manifest.json'),
    );
  }
}
