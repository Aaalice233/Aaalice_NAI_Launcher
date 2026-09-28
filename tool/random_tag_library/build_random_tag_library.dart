import 'dart:convert';
import 'dart:io';

import 'nai_official_wordlist_builder.dart';
import 'verify_random_tag_library.dart' as verifier;

/// Rebuilds the official NovelAI wordlist asset from the explicitly supplied,
/// source-locked frontend bundle and refreshes deterministic taxonomy counts.
Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln(
      'Usage: dart run tool/random_tag_library/build_random_tag_library.dart '
      '[<1741-*.js bundle>]',
    );
    exitCode = 2;
    return;
  }

  if (args.isNotEmpty) {
    await _buildOfficialWordlist(File(args.single));
  }
  await verifier.verifyRandomTagLibrary(updateLock: true);
}

Future<void> _buildOfficialWordlist(File sourceFile) async {
  if (!await sourceFile.exists()) {
    throw StateError('NovelAI source bundle not found: ${sourceFile.path}');
  }
  final lockFile = File('tool/random_tag_library/source_lock.json');
  final lock =
      jsonDecode(await lockFile.readAsString()) as Map<String, dynamic>;
  final reference = Map<String, dynamic>.from(lock['referenceAnalysis'] as Map);
  final bytes = await sourceFile.readAsBytes();
  final expectedFileName = reference['fileName'] as String;
  if (sourceFile.uri.pathSegments.last != expectedFileName) {
    throw StateError(
      'NovelAI source file name mismatch: '
      '${sourceFile.uri.pathSegments.last} != $expectedFileName',
    );
  }

  final result = buildNaiOfficialWordlistAsset(
    sourceBytes: bytes,
    sourceFileName: expectedFileName,
  );
  final source = result.asset['source']! as Map<String, Object?>;
  _expect(source['size'] == reference['size'], 'reference size mismatch');
  _expect(
    source['sha256'] == reference['sha256'],
    'reference SHA-256 mismatch',
  );

  final expectedGenerators = Map<String, dynamic>.from(
    reference['generators'] as Map,
  );
  for (final generator in result.generatorCounts.entries) {
    final expected = Map<String, dynamic>.from(
      expectedGenerators[generator.key] as Map,
    );
    _expect(
      naiOfficialGeneratorGroups[generator.key]!.length ==
          expected['arrayCount'],
      '${generator.key} array count mismatch',
    );
    _expect(
      generator.value == expected['entryCount'],
      '${generator.key} entry count mismatch',
    );
  }

  final assetFile = File(naiOfficialWordlistAsset);
  await assetFile.writeAsBytes(result.encodedBytes, flush: true);
  lock['schemaVersion'] = 2;
  lock['officialWordlist'] = {
    'schemaVersion': naiOfficialWordlistSchemaVersion,
    'asset': naiOfficialWordlistAsset,
    'outputSha256': result.outputSha256,
    'sourceFileName': expectedFileName,
    'sourceSize': source['size'],
    'sourceSha256': source['sha256'],
    'totalArrayCount': naiOfficialGeneratorGroups.values.fold<int>(
      0,
      (total, groups) => total + groups.length,
    ),
    'totalEntryCount': result.totalEntryCount,
    'generatorEntryCounts': result.generatorCounts,
    'groupEntryCounts': result.groupCounts,
  };
  await lockFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(lock)}\n',
    flush: true,
  );
  stdout.writeln(
    'Built ${assetFile.path}: ${result.totalEntryCount} records, '
    '${result.outputSha256}.',
  );
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
