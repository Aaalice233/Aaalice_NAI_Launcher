import 'dart:collection';

const officialWordlistSchemaVersion = 1;
const officialWordlistAssetPath =
    'assets/data/nai_official_random_wordlists.json';
const officialWordlistTotalEntryCount = 5960;
const officialWordlistTotalGroupCount = 118;
const officialWordlistGeneratorEntryCounts = <String, int>{
  'legacyAnime': 1865,
  'furryV3': 1639,
  'characterPrompts': 2456,
};

class OfficialWordlistData {
  OfficialWordlistData({
    required this.schemaVersion,
    required this.dataVersion,
    required this.sourceFileName,
    required this.sourceSize,
    required this.sourceSha256,
    required List<OfficialWordlist> generators,
  }) : generators = List.unmodifiable(generators),
       generatorsById = UnmodifiableMapView({
         for (final generator in generators) generator.id: generator,
       });

  final int schemaVersion;
  final String dataVersion;
  final String sourceFileName;
  final int sourceSize;
  final String sourceSha256;
  final List<OfficialWordlist> generators;
  final Map<String, OfficialWordlist> generatorsById;

  int get totalEntryCount =>
      generators.fold(0, (total, generator) => total + generator.entryCount);

  factory OfficialWordlistData.fromJson(Map<String, dynamic> json) {
    final source = Map<String, dynamic>.from(json['source'] as Map);
    final generators = (json['generators'] as List<dynamic>)
        .map(
          (value) => OfficialWordlist.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final data = OfficialWordlistData(
      schemaVersion: json['schemaVersion'] as int,
      dataVersion: json['dataVersion'] as String,
      sourceFileName: source['fileName'] as String,
      sourceSize: source['size'] as int,
      sourceSha256: source['sha256'] as String,
      generators: generators,
    );
    if (data.schemaVersion != officialWordlistSchemaVersion) {
      throw FormatException(
        'Unsupported official wordlist schema: ${data.schemaVersion}',
      );
    }
    final expectedGeneratorIds = officialWordlistGeneratorEntryCounts.keys
        .toList(growable: false);
    final actualGeneratorIds = data.generators
        .map((generator) => generator.id)
        .toList(growable: false);
    if (!_sameValues(actualGeneratorIds, expectedGeneratorIds)) {
      throw FormatException(
        'Official wordlist generator order mismatch: $actualGeneratorIds',
      );
    }
    for (final generator in data.generators) {
      final expectedCount = officialWordlistGeneratorEntryCounts[generator.id]!;
      if (generator.entryCount != expectedCount) {
        throw FormatException(
          '${generator.id} entry count mismatch: '
          '${generator.entryCount} != $expectedCount',
        );
      }
    }
    final groupCount = data.generators.fold<int>(
      0,
      (total, generator) => total + generator.groups.length,
    );
    if (groupCount != officialWordlistTotalGroupCount) {
      throw FormatException(
        'Official wordlist group count mismatch: $groupCount',
      );
    }
    if (data.totalEntryCount != officialWordlistTotalEntryCount ||
        json['totalEntryCount'] != data.totalEntryCount) {
      throw FormatException(
        'Official wordlist entry count mismatch: ${data.totalEntryCount}',
      );
    }
    if (data.sourceFileName.isEmpty ||
        data.sourceSize <= 0 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(data.sourceSha256) ||
        data.dataVersion != data.sourceSha256.substring(0, 12)) {
      throw const FormatException('Official wordlist source metadata mismatch');
    }
    return data;
  }
}

bool _sameValues(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class OfficialWordlist {
  OfficialWordlist({
    required this.id,
    required List<String> entryFields,
    required List<OfficialWordlistGroup> groups,
    required int declaredEntryCount,
  }) : entryFields = List.unmodifiable(entryFields),
       groups = List.unmodifiable(groups),
       groupsById = UnmodifiableMapView({
         for (final group in groups) group.id: group,
       }) {
    if (entryCount != declaredEntryCount) {
      throw FormatException(
        '$id entry count mismatch: $entryCount != $declaredEntryCount',
      );
    }
  }

  final String id;
  final List<String> entryFields;
  final List<OfficialWordlistGroup> groups;
  final Map<String, OfficialWordlistGroup> groupsById;

  int get entryCount =>
      groups.fold(0, (total, group) => total + group.entries.length);

  OfficialWordlistGroup group(String id) {
    final value = groupsById[id];
    if (value == null) throw StateError('$this is missing group $id');
    return value;
  }

  factory OfficialWordlist.fromJson(Map<String, dynamic> json) {
    return OfficialWordlist(
      id: json['id'] as String,
      entryFields: (json['entryFields'] as List<dynamic>).cast<String>(),
      groups: (json['groups'] as List<dynamic>)
          .map(
            (value) => OfficialWordlistGroup.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      declaredEntryCount: json['entryCount'] as int,
    );
  }

  @override
  String toString() => 'OfficialWordlist($id)';
}

class OfficialWordlistGroup {
  OfficialWordlistGroup({
    required this.id,
    required this.semantic,
    required List<OfficialWordlistEntry> entries,
  }) : entries = List.unmodifiable(entries);

  final String id;
  final String semantic;
  final List<OfficialWordlistEntry> entries;

  factory OfficialWordlistGroup.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return OfficialWordlistGroup(
      id: id,
      semantic: json['semantic'] as String,
      entries: (json['entries'] as List<dynamic>)
          .map(
            (value) => OfficialWordlistEntry.fromRaw(
              groupId: id,
              raw: List<dynamic>.from(value as List),
            ),
          )
          .toList(growable: false),
    );
  }
}

class OfficialWordlistEntry {
  OfficialWordlistEntry._({required this.groupId, required List<Object?> raw})
    : raw = List.unmodifiable(raw);

  factory OfficialWordlistEntry.fromRaw({
    required String groupId,
    required List<Object?> raw,
  }) {
    if (raw.length < 2 ||
        (raw.first is! String && raw.first is! num) ||
        raw[1] is! int ||
        (raw[1] as int) < 0) {
      throw FormatException('Malformed official wordlist record in $groupId');
    }
    return OfficialWordlistEntry._(groupId: groupId, raw: raw);
  }

  final String groupId;
  final List<Object?> raw;

  Object get value => raw[0]!;
  String get text => value.toString();
  int get weight => raw[1]! as int;

  List<Object?> fieldValues(int index) {
    if (index >= raw.length || raw[index] is! List) return const [];
    return List<Object?>.unmodifiable(raw[index]! as List);
  }

  List<String> stringFieldValues(int index) =>
      fieldValues(index).whereType<String>().toList(growable: false);
}
