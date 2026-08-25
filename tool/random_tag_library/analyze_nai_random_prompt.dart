import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _generatorVariables = <String, List<String>>{
  'legacyAnime': [
    'lF',
    'lO',
    'lV',
    'lU',
    'lW',
    r'l$',
    'lH',
    'lG',
    'lX',
    'lY',
    'lQ',
    'lK',
    'lZ',
    'lJ',
    'l0',
    'l3',
    'l2',
    'l1',
    'l5',
    'l6',
    'l4',
    'l8',
    'l7',
    'l9',
    'ce',
    'ct',
    'cr',
    'ci',
    'ca',
    'cn',
    'co',
    'cs',
    'cl',
    'cc',
    'cd',
    'ch',
    'cu',
    'cp',
    'cg',
  ],
  'furryV3': [
    'cx',
    'cw',
    'cv',
    'ck',
    'cC',
    'cI',
    'cM',
    'cS',
    'cD',
    'cT',
    'cR',
    'cP',
    'cz',
    'cq',
    'cE',
    'cB',
    'cN',
    'cL',
    'cF',
    'cO',
    'cV',
    'cU',
    'cW',
    r'c$',
    'cH',
    'cG',
    'cX',
    'cY',
    'cQ',
    'cK',
    'cZ',
    'cJ',
    'c0',
    'c3',
    'c2',
    'c1',
    'c5',
    'c6',
    'c4',
    'c8',
  ],
  'characterPrompts': [
    'dr',
    'di',
    'da',
    'dn',
    'ds',
    'dl',
    'dc',
    'dd',
    'dh',
    'du',
    'dp',
    'dg',
    'dm',
    'df',
    'dy',
    'd_',
    'db',
    'dx',
    'dw',
    'dv',
    'dk',
    'dC',
    'dj',
    'dA',
    'dI',
    'dM',
    'dS',
    'dD',
    'dT',
    'dR',
    'dP',
    'dz',
    'dq',
    'dE',
    'dB',
    'dN',
    'dL',
    'dF',
    'dO',
  ],
};

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
  for (final generator in _generatorVariables.entries) {
    final arrayCounts = <String, int>{};
    var entryCount = 0;
    final uniqueEntries = <String>{};
    for (final variable in generator.value) {
      final value = _decodeAssignedArray(source, variable);
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

List<dynamic> _decodeAssignedArray(String source, String variable) {
  final assignment = RegExp(
    '(?<![A-Za-z0-9_\\\$])${RegExp.escape(variable)}=\\[',
  ).firstMatch(source);
  _expect(assignment != null, 'missing array assignment: $variable');
  final start = assignment!.end - 1;
  final end = _arrayEnd(source, start);
  final value = jsonDecode(source.substring(start, end + 1));
  _expect(value is List, '$variable is not an array');
  return value as List<dynamic>;
}

int _arrayEnd(String source, int start) {
  var depth = 0;
  var escaped = false;
  int? quote;
  for (var index = start; index < source.length; index++) {
    final code = source.codeUnitAt(index);
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (code == 0x5c) {
        escaped = true;
      } else if (code == quote) {
        quote = null;
      }
      continue;
    }
    if (code == 0x22 || code == 0x27) {
      quote = code;
    } else if (code == 0x5b) {
      depth++;
    } else if (code == 0x5d) {
      depth--;
      if (depth == 0) return index;
    }
  }
  throw const FormatException('Unterminated array literal');
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
