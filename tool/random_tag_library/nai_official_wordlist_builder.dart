import 'dart:convert';

import 'package:crypto/crypto.dart';

const naiOfficialWordlistSchemaVersion = 1;
const naiOfficialWordlistAsset =
    'assets/data/nai_official_random_wordlists.json';

const naiOfficialGeneratorGroups = <String, Map<String, String>>{
  'legacyAnime': {
    'lF': 'cameraAngle',
    'lO': 'focus',
    'lV': 'noHumanScene',
    'lU': 'background',
    'lW': 'framing',
    r'l$': 'style',
    'lH': 'nonHumanFeature',
    'lG': 'skinTone',
    'lX': 'specialEyes',
    'lY': 'eyeShape',
    'lQ': 'hairLength',
    'lK': 'braidedHair',
    'lZ': 'specialHairStyle',
    'lJ': 'bangs',
    'l0': 'breastSize',
    'l3': 'bodyFeature',
    'l2': 'headwear',
    'l1': 'hairAccessory',
    'l5': 'headwearDecoration',
    'l6': 'dress',
    'l4': 'legwear',
    'l8': 'legwearDecoration',
    'l7': 'topwear',
    'l9': 'bottomwear',
    'ce': 'footwear',
    'ct': 'uniform',
    'cr': 'bodysuit',
    'ci': 'swimwear',
    'ca': 'accessoryAndProp',
    'cn': 'expression',
    'co': 'year',
    'cs': 'environment',
    'cl': 'object',
    'cc': 'action',
    'cd': 'effect',
    'ch': 'eyeColor',
    'cu': 'hairColor',
    'cp': 'multicolorHair',
    'cg': 'clothingColor',
  },
  'furryV3': {
    'cx': 'cameraAngle',
    'cw': 'focus',
    'cv': 'noCharacterScene',
    'ck': 'background',
    'cC': 'framing',
    'cI': 'style',
    'cM': 'baseSpecies',
    'cS': 'bodyForm',
    'cD': 'humanoidSpecies',
    'cT': 'specialSpecies',
    'cR': 'bodyColor',
    'cP': 'eyeColor',
    'cz': 'scleraColor',
    'cq': 'eyeShape',
    'cE': 'hairColor',
    'cB': 'multicolorHair',
    'cN': 'hairLength',
    'cL': 'hairStyle',
    'cF': 'hairTexture',
    'cO': 'bangs',
    'cV': 'breastSize',
    'cU': 'bodyFeature',
    'cW': 'headwear',
    r'c$': 'hairAccessory',
    'cH': 'dress',
    'cG': 'legwear',
    'cX': 'topwear',
    'cY': 'bottomwear',
    'cQ': 'footwear',
    'cK': 'uniform',
    'cZ': 'bodysuit',
    'cJ': 'swimwear',
    'c0': 'accessoryAndProp',
    'c3': 'expression',
    'c2': 'year',
    'c1': 'environment',
    'c5': 'object',
    'c6': 'action',
    'c4': 'effect',
    'c8': 'clothingColor',
  },
  'characterPrompts': {
    'dr': 'cameraAngle',
    'di': 'framing',
    'da': 'focus',
    'dn': 'noHumanScene',
    'ds': 'background',
    'dl': 'style',
    'dc': 'nonHumanFeature',
    'dd': 'skinTone',
    'dh': 'specialEyes',
    'du': 'eyeShape',
    'dp': 'hairLength',
    'dg': 'hairStyle',
    'dm': 'specialHairStyle',
    'df': 'bangs',
    'dy': 'breastSize',
    'd_': 'bodyFeature',
    'db': 'headwear',
    'dx': 'hairAccessory',
    'dw': 'headwearDecoration',
    'dv': 'dress',
    'dk': 'legwear',
    'dC': 'legwearDecoration',
    'dj': 'topwear',
    'dA': 'bottomwear',
    'dI': 'footwear',
    'dM': 'uniform',
    'dS': 'bodysuit',
    'dD': 'swimwear',
    'dT': 'accessoryAndProp',
    'dR': 'expression',
    'dP': 'year',
    'dz': 'environment',
    'dq': 'object',
    'dE': 'action',
    'dB': 'effect',
    'dN': 'eyeColor',
    'dL': 'hairColor',
    'dF': 'multicolorHair',
    'dO': 'clothingColor',
  },
};

const naiOfficialEntrySchemas = <String, List<String>>{
  'legacyAnime': ['value', 'weight', 'anyOfDependencies'],
  'furryV3': ['value', 'weight', 'anyOfDependencies'],
  'characterPrompts': [
    'value',
    'weight',
    'declaredProvides',
    'requiredFlags',
    'excludedByFlags',
    'ignoredTrailingData',
  ],
};

class NaiOfficialWordlistBuildResult {
  const NaiOfficialWordlistBuildResult({
    required this.asset,
    required this.encodedBytes,
    required this.outputSha256,
    required this.generatorCounts,
    required this.groupCounts,
    required this.totalEntryCount,
  });

  final Map<String, Object?> asset;
  final List<int> encodedBytes;
  final String outputSha256;
  final Map<String, int> generatorCounts;
  final Map<String, Map<String, int>> groupCounts;
  final int totalEntryCount;
}

NaiOfficialWordlistBuildResult buildNaiOfficialWordlistAsset({
  required List<int> sourceBytes,
  required String sourceFileName,
}) {
  final sourceSha256 = sha256.convert(sourceBytes).toString();
  final source = utf8.decode(sourceBytes);
  final generators = <Map<String, Object?>>[];
  final generatorCounts = <String, int>{};
  final groupCounts = <String, Map<String, int>>{};
  var totalEntryCount = 0;

  for (final generator in naiOfficialGeneratorGroups.entries) {
    final groups = <Map<String, Object?>>[];
    final counts = <String, int>{};
    var generatorEntryCount = 0;
    for (final group in generator.value.entries) {
      final records = decodeAssignedArray(source, group.key);
      _validateRecords(generator.key, group.key, records);
      counts[group.key] = records.length;
      generatorEntryCount += records.length;
      groups.add({
        'id': group.key,
        'semantic': group.value,
        'entries': records,
      });
    }
    groupCounts[generator.key] = counts;
    generatorCounts[generator.key] = generatorEntryCount;
    totalEntryCount += generatorEntryCount;
    generators.add({
      'id': generator.key,
      'entryFields': naiOfficialEntrySchemas[generator.key],
      'entryCount': generatorEntryCount,
      'groups': groups,
    });
  }

  final asset = <String, Object?>{
    'schemaVersion': naiOfficialWordlistSchemaVersion,
    'dataVersion': sourceSha256.substring(0, 12),
    'source': {
      'fileName': sourceFileName,
      'size': sourceBytes.length,
      'sha256': sourceSha256,
    },
    'totalEntryCount': totalEntryCount,
    'generators': generators,
  };
  final encodedBytes = utf8.encode(
    '${const JsonEncoder.withIndent('  ').convert(asset)}\n',
  );
  return NaiOfficialWordlistBuildResult(
    asset: asset,
    encodedBytes: encodedBytes,
    outputSha256: sha256.convert(encodedBytes).toString(),
    generatorCounts: Map.unmodifiable(generatorCounts),
    groupCounts: Map<String, Map<String, int>>.unmodifiable({
      for (final entry in groupCounts.entries)
        entry.key: Map<String, int>.unmodifiable(entry.value),
    }),
    totalEntryCount: totalEntryCount,
  );
}

List<dynamic> decodeAssignedArray(String source, String variable) {
  final assignment = RegExp(
    '(?<![A-Za-z0-9_\\\$])${RegExp.escape(variable)}=\\[',
  ).firstMatch(source);
  if (assignment == null) {
    throw FormatException('Missing array assignment: $variable');
  }
  final start = assignment.end - 1;
  final end = _arrayEnd(source, start);
  final value = jsonDecode(source.substring(start, end + 1));
  if (value is! List) {
    throw FormatException('$variable is not an array');
  }
  return value;
}

void _validateRecords(String generator, String group, List<dynamic> records) {
  if (records.isEmpty) throw FormatException('$group contains no records');
  final maxFields = naiOfficialEntrySchemas[generator]!.length;
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    if (record is! List || record.length < 2 || record.length > maxFields) {
      throw FormatException(
        '$generator/$group[$index] has invalid field count: $record',
      );
    }
    if (record[0] is! String && record[0] is! num) {
      throw FormatException('$generator/$group[$index] has invalid value');
    }
    final weight = record[1];
    if (weight is! num || weight.toInt() != weight || weight < 0) {
      throw FormatException('$generator/$group[$index] has invalid weight');
    }
    for (var field = 2; field < record.length; field++) {
      final mustBeFlagArray =
          generator != 'characterPrompts' || field == 3 || field == 4;
      if (mustBeFlagArray && record[field] is! List) {
        throw FormatException(
          '$generator/$group[$index][$field] is not a flag array',
        );
      }
    }
  }
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
