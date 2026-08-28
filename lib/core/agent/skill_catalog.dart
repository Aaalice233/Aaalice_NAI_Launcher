import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'harness/env/dart_io_execution_env.dart';
import 'harness/harness_types.dart';
import 'harness/skills.dart';
import 'private_data_guard.dart';

enum SkillSource { workspace, piUser, commonUser }

typedef SkillManifestMetadata = ({String name, String description});

SkillManifestMetadata parseStrictSkillManifest(Uint8List bytes) {
  final raw = utf8.decode(bytes);
  final match = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)',
  ).firstMatch(raw);
  if (match == null) {
    throw const FormatException('SKILL.md must contain YAML frontmatter.');
  }
  final fields = <String, String>{};
  const allowedFields = {'name', 'description', 'disable-model-invocation'};
  for (final rawLine in match.group(1)!.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final separator = line.indexOf(':');
    if (separator <= 0) {
      throw const FormatException('SKILL.md contains invalid frontmatter.');
    }
    final key = line.substring(0, separator).trim();
    if (!allowedFields.contains(key)) {
      throw FormatException('SKILL.md contains unknown field "$key".');
    }
    if (fields.containsKey(key)) {
      throw FormatException('SKILL.md contains duplicate field "$key".');
    }
    var value = line.substring(separator + 1).trim();
    final startsQuoted = value.startsWith('"') || value.startsWith("'");
    final endsQuoted = value.endsWith('"') || value.endsWith("'");
    final matchingQuotes =
        value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    if ((startsQuoted || endsQuoted) && !matchingQuotes) {
      throw FormatException('SKILL.md field "$key" has invalid quoting.');
    }
    if (matchingQuotes) value = value.substring(1, value.length - 1);
    if (key == 'disable-model-invocation' &&
        (matchingQuotes || (value != 'true' && value != 'false'))) {
      throw const FormatException(
        'disable-model-invocation must be true or false.',
      );
    }
    fields[key] = value;
  }
  if (!fields.containsKey('name') || !fields.containsKey('description')) {
    throw const FormatException(
      'SKILL.md requires name and description fields.',
    );
  }
  final name = fields['name']!;
  final description = fields['description']!;
  if (!RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?$').hasMatch(name) ||
      name.contains('--')) {
    throw FormatException('Invalid Skill name: $name');
  }
  if (description.isEmpty || description.length > 1024) {
    throw const FormatException('Skill description is missing or too long.');
  }
  return (name: name, description: description);
}

extension SkillSourcePriority on SkillSource {
  int get priority => index;
}

class SkillRoot {
  const SkillRoot({required this.path, required this.source});

  final String path;
  final SkillSource source;
}

class SkillCatalogEntry {
  const SkillCatalogEntry({
    required this.id,
    required this.skill,
    required this.source,
    required this.safePath,
    required this.enabled,
    this.shadowedBy,
  });

  final String id;
  final HarnessSkill skill;
  final SkillSource source;
  final String safePath;
  final bool enabled;
  final SkillSource? shadowedBy;

  bool get isEffective => shadowedBy == null;
  bool get isModelVisible => enabled && skill.disableModelInvocation != true;

  SkillCatalogEntry copyWith({bool? enabled}) => SkillCatalogEntry(
    id: id,
    skill: skill,
    source: source,
    safePath: safePath,
    enabled: enabled ?? this.enabled,
    shadowedBy: shadowedBy,
  );
}

class SourcedSkillDiagnostic {
  const SourcedSkillDiagnostic({
    required this.diagnostic,
    required this.source,
    required this.safePath,
  });

  final SkillDiagnostic diagnostic;
  final SkillSource source;
  final String safePath;
}

class SkillCatalogSnapshot {
  const SkillCatalogSnapshot({
    this.entries = const [],
    this.diagnostics = const [],
  });

  final List<SkillCatalogEntry> entries;
  final List<SourcedSkillDiagnostic> diagnostics;

  List<SkillCatalogEntry> get effectiveEntries =>
      entries.where((entry) => entry.isEffective).toList(growable: false);

  Map<String, HarnessSkill> enabledSkillMap() => {
    for (final entry in effectiveEntries)
      if (entry.enabled) entry.id: entry.skill,
  };
}

class SkillCatalogService {
  const SkillCatalogService();

  static List<SkillRoot> roots({
    required Directory workspaceDirectory,
    required Directory supportDirectory,
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    return [
      SkillRoot(
        path: p.join(workspaceDirectory.path, '.pi', 'skills'),
        source: SkillSource.workspace,
      ),
      SkillRoot(
        path: home == null
            ? p.join(supportDirectory.path, 'pi-user', 'skills')
            : p.join(home, '.pi', 'agent', 'skills'),
        source: SkillSource.piUser,
      ),
      if (home != null)
        SkillRoot(
          path: p.join(home, '.agents', 'skills'),
          source: SkillSource.commonUser,
        ),
    ];
  }

  Future<SkillCatalogSnapshot> scan({
    required List<SkillRoot> roots,
    Set<String> disabledSkillIds = const {},
  }) async {
    final env = DartIoExecutionEnv(allowOutsideWorkingDirectory: true);
    final orderedRoots = [...roots]
      ..sort((a, b) => a.source.priority.compareTo(b.source.priority));
    final loaded = await loadSourcedSkills<SkillRoot>(env, [
      for (final root in orderedRoots) (path: root.path, source: root),
    ]);
    final winners = <String, SkillSource>{};
    final entries = <SkillCatalogEntry>[];
    for (final item in loaded.skills) {
      final skill = item.skill;
      final source = item.source.source;
      final shadowedBy = winners[skill.name];
      winners.putIfAbsent(skill.name, () => source);
      entries.add(
        SkillCatalogEntry(
          id: skill.name,
          skill: skill,
          source: source,
          safePath: _safePath(skill.filePath, source),
          enabled: !disabledSkillIds.contains(skill.name),
          shadowedBy: shadowedBy,
        ),
      );
    }
    entries.sort((a, b) {
      final effective = (b.isEffective ? 1 : 0) - (a.isEffective ? 1 : 0);
      if (effective != 0) return effective;
      final name = a.id.compareTo(b.id);
      if (name != 0) return name;
      return a.source.priority.compareTo(b.source.priority);
    });
    return SkillCatalogSnapshot(
      entries: entries,
      diagnostics: [
        for (final item in loaded.diagnostics)
          SourcedSkillDiagnostic(
            diagnostic: SkillDiagnostic(
              code: item.diagnostic.code,
              message: PrivateDataGuard.redactAbsolutePaths(
                item.diagnostic.message,
              ),
              path: _safePath(item.diagnostic.path, item.source.source),
            ),
            source: item.source.source,
            safePath: _safePath(item.diagnostic.path, item.source.source),
          ),
      ],
    );
  }

  static String _safePath(String path, SkillSource source) {
    final segments = p
        .split(p.normalize(path))
        .where((segment) => segment.isNotEmpty)
        .toList();
    final tail = segments.length <= 3
        ? segments
        : segments.sublist(segments.length - 3);
    return '${source.name}:/.../${p.joinAll(tail)}';
  }
}
