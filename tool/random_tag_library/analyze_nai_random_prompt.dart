import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'nai_official_wordlist_builder.dart';

/// Produces aggregate evidence only. It never writes or emits proprietary tags.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/random_tag_library/'
      'analyze_nai_random_prompt.dart <1741-*.js>',
    );
    exitCode = 2;
    return;
  }
  final sourceFile = File(args.single);
  if (!await sourceFile.exists()) {
    stderr.writeln('Reference bundle not found: ${sourceFile.path}');
    exitCode = 2;
    return;
  }

  final bytes = await sourceFile.readAsBytes();
  final sourceHash = sha256.convert(bytes).toString();
  final source = utf8.decode(bytes);
  final lock =
      jsonDecode(
            await File(
              'tool/random_tag_library/source_lock.json',
            ).readAsString(),
          )
          as Map<String, dynamic>;
  final expected = Map<String, dynamic>.from(lock['referenceAnalysis'] as Map);
  _expect(bytes.length == expected['size'], 'reference size mismatch');
  _expect(sourceHash == expected['sha256'], 'reference SHA-256 mismatch');
  _expect(
    Uri.tryParse(expected['sourcePage'] as String)?.hasScheme == true,
    'reference source page is invalid',
  );
  DateTime.parse(expected['retrievedAt'] as String);

  final generatorStats = <String, Object?>{};
  for (final generator in naiOfficialGeneratorGroups.entries) {
    final arrayCounts = <String, int>{};
    var entryCount = 0;
    final uniqueEntries = <String>{};
    for (final variable in generator.value.keys) {
      final value = decodeAssignedArray(source, variable);
      arrayCounts[variable] = value.length;
      entryCount += value.length;
      for (final item in value) {
        if (item is List && item.isNotEmpty) uniqueEntries.add('${item.first}');
      }
    }
    final expectedGenerator = Map<String, dynamic>.from(
      (expected['generators'] as Map)[generator.key] as Map,
    );
    _expect(
      generator.value.length == expectedGenerator['arrayCount'],
      '${generator.key} array count mismatch',
    );
    _expect(
      entryCount == expectedGenerator['entryCount'],
      '${generator.key} entry count mismatch: '
      '$entryCount != ${expectedGenerator['entryCount']}',
    );
    generatorStats[generator.key] = {
      'arrayCount': generator.value.length,
      'entryCount': entryCount,
      'uniqueFirstColumnValues': uniqueEntries.length,
      'categoryCounts': arrayCounts,
    };
  }

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'file': sourceFile.uri.pathSegments.last,
      'size': bytes.length,
      'sha256': sourceHash,
      'generators': generatorStats,
    }),
  );
  stdout.writeln('NovelAI random-prompt reference analysis passed.');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
