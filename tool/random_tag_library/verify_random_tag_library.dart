import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

import 'nai_official_wordlist_builder.dart';

Future<void> main(List<String> args) async {
  final updateLock = args.contains('--update-lock');
  final sourceIndex = args.indexOf('--source');
  if (sourceIndex >= 0 && sourceIndex + 1 >= args.length) {
    throw const FormatException('--source requires a bundle path');
  }
  final supportedArgumentCount =
      (updateLock ? 1 : 0) + (sourceIndex >= 0 ? 2 : 0);
  if (args.length != supportedArgumentCount) {
    throw const FormatException(
      'Usage: verify_random_tag_library.dart '
      '[--update-lock] [--source <1741-*.js bundle>]',
    );
  }
  await verifyRandomTagLibrary(
    updateLock: updateLock,
    sourceBundlePath: sourceIndex < 0 ? null : args[sourceIndex + 1],
  );
}

Future<void> verifyRandomTagLibrary({
  bool updateLock = false,
  String? sourceBundlePath,
}) async {
  final lockFile = File('tool/random_tag_library/source_lock.json');
  final lock =
      jsonDecode(await lockFile.readAsString()) as Map<String, dynamic>;
  await _verifyOfficialWordlist(lock, sourceBundlePath: sourceBundlePath);
  final referenceAnalysis = Map<String, dynamic>.from(
    lock['referenceAnalysis'] as Map,
  );
  _expect(
    Uri.tryParse(referenceAnalysis['sourcePage'] as String)?.hasScheme == true,
    'reference source page is invalid',
  );
  DateTime.parse(referenceAnalysis['retrievedAt'] as String);
  _expect(
    (referenceAnalysis['size'] as int) > 0,
    'reference file size is invalid',
  );
  _expect(
    RegExp(r'^[0-9a-f]{64}$').hasMatch(referenceAnalysis['sha256'] as String),
    'reference SHA-256 is invalid',
  );

  final taxonomyFile = File(lock['taxonomyAsset'] as String);
  final taxonomyBytes = await taxonomyFile.readAsBytes();
  final taxonomySha256 = sha256.convert(taxonomyBytes).toString();
  if (!updateLock) {
    _expect(
      taxonomySha256 == lock['taxonomySha256'],
      'taxonomy SHA-256 mismatch',
    );
  }

  final taxonomy =
      jsonDecode(utf8.decode(taxonomyBytes)) as Map<String, dynamic>;
  if (!updateLock) {
    _expect(
      taxonomy['schemaVersion'] == lock['taxonomyVersion'],
      'taxonomy schema version mismatch',
    );
  }
  final catalogSourceLock =
      jsonDecode(await File(lock['catalogSourceLock'] as String).readAsString())
          as Map<String, dynamic>;
  final source = taxonomy['source'] as Map<String, dynamic>;
  _expect(source['url'] == catalogSourceLock['url'], 'source URL mismatch');
  _expect(
    source['commit'] == catalogSourceLock['commit'],
    'source commit lock mismatch',
  );
  _expect(
    source['sha256'] == catalogSourceLock['sha256'],
    'source SHA-256 lock mismatch',
  );
  _expect(
    source['license'] == catalogSourceLock['upstreamLicense'],
    'source license mismatch',
  );
  _expect(
    source['catalogTagCount'] == catalogSourceLock['expectedTagCount'],
    'source tag count mismatch',
  );
  _expect(
    source['catalogAliasCount'] == catalogSourceLock['expectedAliasCount'],
    'source alias count mismatch',
  );
  DateTime.parse(source['versionDate'] as String);

  final catalogManifest =
      jsonDecode(await File(lock['catalogManifest'] as String).readAsString())
          as Map<String, dynamic>;
  final catalogEntry =
      (catalogManifest['databases'] as Map)['tag_catalog.db'] as Map;
  _expect(
    catalogEntry['schemaVersion'] == lock['catalogSchemaVersion'],
    'catalog schema version mismatch',
  );
  _expect(
    catalogEntry['dataVersion'] == lock['catalogDataVersion'],
    'catalog data version mismatch',
  );
  _expect(
    catalogEntry['sha256'] == lock['catalogSha256'],
    'catalog manifest SHA-256 mismatch',
  );

  final databaseFile = File('assets/databases/tag_catalog.db');
  _expect(await databaseFile.exists(), 'tag catalog is missing');
  _expect(
    sha256.convert(await databaseFile.readAsBytes()).toString() ==
        lock['catalogSha256'],
    'tag catalog file SHA-256 mismatch',
  );

  final verificationStopwatch = Stopwatch()..start();
  final database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
  try {
    final metadata = {
      for (final row in database.select('SELECT key, value FROM metadata'))
        row['key'] as String: row['value'] as String,
    };
    _expect(
      metadata['data_version'] == lock['catalogDataVersion'],
      'database data version mismatch',
    );
    _expect(
      metadata['source_commit'] == source['commit'],
      'source commit mismatch',
    );
    _expect(
      metadata['source_sha256'] == source['sha256'],
      'source SHA-256 mismatch',
    );
    _expect(
      metadata['tag_count'] == '${lock['expectedCatalogTagCount']}',
      'catalog tag count mismatch',
    );
    _expect(
      metadata['alias_count'] == '${lock['expectedCatalogAliasCount']}',
      'catalog alias count mismatch',
    );

    final eligibility = Map<String, dynamic>.from(
      taxonomy['eligibility'] as Map,
    );
    final eligibleCategories = (eligibility['catalogCategories'] as List)
        .cast<int>();
    final eligibleCount = _countCatalogCategories(database, eligibleCategories);
    if (!updateLock) {
      _expect(
        eligibleCount == lock['expectedEligibleTagCount'],
        'eligible catalog count mismatch: '
        '$eligibleCount != ${lock['expectedEligibleTagCount']}',
      );
    }

    final expectedCounts = Map<String, dynamic>.from(
      lock['expectedCategoryCounts'] as Map? ?? const {},
    );
    final actualCounts = <String, int>{};
    final categories = taxonomy['categories'] as Map<String, dynamic>;
    for (final entry in categories.entries) {
      actualCounts[entry.key] = _countCategory(
        database,
        Map<String, dynamic>.from(entry.value as Map),
      );
      _expect(actualCounts[entry.key]! > 0, '${entry.key} resolved no tags');
      if (!updateLock && expectedCounts.isNotEmpty) {
        _expect(
          actualCounts[entry.key] == expectedCounts[entry.key],
          '${entry.key} count mismatch: ${actualCounts[entry.key]} != ${expectedCounts[entry.key]}',
        );
      }
    }
    _expect(
      updateLock ||
          expectedCounts.isEmpty ||
          expectedCounts.length == actualCounts.length,
      'expected category set mismatch',
    );

    if (updateLock) {
      lock['taxonomyVersion'] = taxonomy['schemaVersion'];
      lock['taxonomySha256'] = taxonomySha256;
      lock['expectedEligibleTagCount'] = eligibleCount;
      lock['expectedCategoryCounts'] = actualCounts;
      await lockFile.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(lock)}\n',
      );
      stdout.writeln('Updated ${lockFile.path}.');
    }

    verificationStopwatch.stop();
    stdout.writeln(
      'Complete descriptive candidate coverage: $eligibleCount tags.',
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(actualCounts));
    stdout.writeln(
      'Random tag library verification passed in '
      '${verificationStopwatch.elapsedMilliseconds} ms.',
    );
  } finally {
    database.dispose();
  }
}

int _countCategory(Database database, Map<String, dynamic> rule) {
  final where = <String>[];
  final arguments = <Object?>[];
  final includes = <String>[];
  for (final glob
      in (rule['includeGlobs'] as List? ?? const []).cast<String>()) {
    includes.add('name GLOB ?');
    arguments.add(glob);
  }
  for (final name
      in (rule['includeExact'] as List? ?? const []).cast<String>()) {
    includes.add('name = ?');
    arguments.add(name);
  }
  final includeAll = rule['includeAll'] == true;
  _expect(includeAll || includes.isNotEmpty, 'category rule is empty');
  if (!includeAll) {
    where.add('(${includes.join(' OR ')})');
  }
  final includeTokens = (rule['includeTokens'] as List? ?? const [])
      .cast<String>();
  final excludeTokens = (rule['excludeTokens'] as List? ?? const [])
      .cast<String>();
  if (includeTokens.isNotEmpty) {
    where.add(_tokenClause(includeTokens, arguments));
  }
  if (excludeTokens.isNotEmpty) {
    where.add('NOT ${_tokenClause(excludeTokens, arguments)}');
  }
  final catalogCategories =
      (rule['catalogCategories'] as List? ?? const [0, 7, 12]).cast<int>();
  _expect(catalogCategories.isNotEmpty, 'catalogCategories is empty');
  final placeholders = List.filled(catalogCategories.length, '?').join(',');
  arguments.addAll(catalogCategories);
  where.add('category IN ($placeholders)');
  final statement = database.prepare(
    'SELECT COUNT(*) AS count FROM tags WHERE ${where.join(' AND ')}',
  );
  try {
    return statement.select(arguments).first['count'] as int;
  } finally {
    statement.dispose();
  }
}

int _countCatalogCategories(Database database, List<int> categories) {
  final placeholders = List.filled(categories.length, '?').join(',');
  final statement = database.prepare(
    'SELECT COUNT(*) AS count FROM tags WHERE category IN ($placeholders)',
  );
  try {
    return statement.select(categories).first['count'] as int;
  } finally {
    statement.dispose();
  }
}

String _tokenClause(List<String> tokens, List<Object?> arguments) {
  final clauses = <String>[];
  for (final token in tokens) {
    clauses.add('(name = ? OR name GLOB ? OR name GLOB ? OR name GLOB ?)');
    arguments.addAll([token, '${token}_*', '*_$token', '*_${token}_*']);
  }
  return '(${clauses.join(' OR ')})';
}

Future<void> _verifyOfficialWordlist(
  Map<String, dynamic> lock, {
  String? sourceBundlePath,
}) async {
  _expect(lock['schemaVersion'] == 2, 'source lock schema mismatch');
  final official = Map<String, dynamic>.from(
    lock['officialWordlist'] as Map? ?? const {},
  );
  _expect(official.isNotEmpty, 'officialWordlist lock is missing');
  _expect(
    official['schemaVersion'] == naiOfficialWordlistSchemaVersion,
    'official wordlist schema lock mismatch',
  );
  _expect(
    official['asset'] == naiOfficialWordlistAsset,
    'official wordlist asset path mismatch',
  );
  final assetFile = File(official['asset'] as String);
  _expect(await assetFile.exists(), 'official wordlist asset is missing');
  final assetBytes = await assetFile.readAsBytes();
  _expect(
    sha256.convert(assetBytes).toString() == official['outputSha256'],
    'official wordlist output SHA-256 mismatch',
  );
  final asset = jsonDecode(utf8.decode(assetBytes)) as Map<String, dynamic>;
  _expect(
    asset['schemaVersion'] == naiOfficialWordlistSchemaVersion,
    'official wordlist asset schema mismatch',
  );
  final source = Map<String, dynamic>.from(asset['source'] as Map);
  _expect(
    source['fileName'] == official['sourceFileName'],
    'official wordlist source file name mismatch',
  );
  _expect(
    source['size'] == official['sourceSize'],
    'official wordlist source size mismatch',
  );
  _expect(
    source['sha256'] == official['sourceSha256'],
    'official wordlist source SHA-256 mismatch',
  );

  final expectedGeneratorCounts = Map<String, dynamic>.from(
    official['generatorEntryCounts'] as Map,
  );
  final expectedGroupCounts = Map<String, dynamic>.from(
    official['groupEntryCounts'] as Map,
  );
  final generators = asset['generators'] as List<dynamic>;
  _expect(
    generators.length == naiOfficialGeneratorGroups.length,
    'official generator count mismatch',
  );
  var arrayCount = 0;
  var totalEntryCount = 0;
  for (
    var generatorIndex = 0;
    generatorIndex < generators.length;
    generatorIndex++
  ) {
    final expectedGenerator = naiOfficialGeneratorGroups.entries.elementAt(
      generatorIndex,
    );
    final generator = Map<String, dynamic>.from(
      generators[generatorIndex] as Map,
    );
    _expect(
      generator['id'] == expectedGenerator.key,
      'official generator order mismatch at $generatorIndex',
    );
    _expect(
      jsonEncode(generator['entryFields']) ==
          jsonEncode(naiOfficialEntrySchemas[expectedGenerator.key]),
      '${expectedGenerator.key} entry schema mismatch',
    );
    final groups = generator['groups'] as List<dynamic>;
    _expect(
      groups.length == expectedGenerator.value.length,
      '${expectedGenerator.key} group count mismatch',
    );
    final lockedGroupCounts = Map<String, dynamic>.from(
      expectedGroupCounts[expectedGenerator.key] as Map,
    );
    var generatorEntryCount = 0;
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final expectedGroup = expectedGenerator.value.entries.elementAt(
        groupIndex,
      );
      final group = Map<String, dynamic>.from(groups[groupIndex] as Map);
      _expect(
        group['id'] == expectedGroup.key &&
            group['semantic'] == expectedGroup.value,
        '${expectedGenerator.key} group order mismatch at $groupIndex',
      );
      final records = group['entries'] as List<dynamic>;
      _expect(
        records.length == lockedGroupCounts[expectedGroup.key],
        '${expectedGenerator.key}/${expectedGroup.key} count mismatch',
      );
      for (var recordIndex = 0; recordIndex < records.length; recordIndex++) {
        final record = records[recordIndex];
        _expect(
          record is List && record.length >= 2,
          '${expectedGenerator.key}/${expectedGroup.key}[$recordIndex] '
          'is malformed',
        );
        final fields = record as List<dynamic>;
        _expect(
          fields[1] is int && (fields[1] as int) >= 0,
          '${expectedGenerator.key}/${expectedGroup.key}[$recordIndex] '
          'has invalid weight',
        );
      }
      generatorEntryCount += records.length;
      arrayCount++;
    }
    _expect(
      generatorEntryCount == expectedGeneratorCounts[expectedGenerator.key],
      '${expectedGenerator.key} total count mismatch',
    );
    _expect(
      generator['entryCount'] == generatorEntryCount,
      '${expectedGenerator.key} embedded count mismatch',
    );
    totalEntryCount += generatorEntryCount;
  }
  _expect(
    arrayCount == official['totalArrayCount'],
    'official total array count mismatch',
  );
  _expect(
    totalEntryCount == official['totalEntryCount'] &&
        asset['totalEntryCount'] == totalEntryCount,
    'official total entry count mismatch',
  );

  if (sourceBundlePath != null) {
    final bundle = File(sourceBundlePath);
    _expect(await bundle.exists(), 'official source bundle is missing');
    _expect(
      bundle.uri.pathSegments.last == official['sourceFileName'],
      'official source bundle file name mismatch',
    );
    final rebuilt = buildNaiOfficialWordlistAsset(
      sourceBytes: await bundle.readAsBytes(),
      sourceFileName: bundle.uri.pathSegments.last,
    );
    _expect(
      _bytesEqual(rebuilt.encodedBytes, assetBytes),
      'official wordlist build is not deterministic',
    );
  }
  stdout.writeln(
    'Verified official wordlist: $totalEntryCount records in '
    '$arrayCount groups.',
  );
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
