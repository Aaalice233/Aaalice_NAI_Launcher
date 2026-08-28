import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/agent/harness/skills.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('agent-skill-catalog-');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test(
    'higher-priority roots win and disabled skills stay diagnosed',
    () async {
      final builtin = Directory('${temp.path}/builtin');
      final user = Directory('${temp.path}/user');
      await _writeSkill(builtin, 'demo', 'Built in');
      await _writeSkill(user, 'demo', 'User copy');
      await _writeSkill(user, 'manual', 'Manual only', disableModel: true);

      final loaded = await const SkillCatalogService().scan(
        roots: [
          SkillRoot(source: SkillSource.piUser, path: user.path),
          SkillRoot(source: SkillSource.workspace, path: builtin.path),
        ],
        disabledSkillIds: {'manual'},
      );

      final demo = loaded.effectiveEntries.singleWhere(
        (entry) => entry.skill.name == 'demo',
      );
      final manual = loaded.entries.singleWhere(
        (entry) => entry.skill.name == 'manual',
      );
      expect(demo.source, SkillSource.workspace);
      expect(demo.skill.description, 'Built in');
      expect(manual.enabled, isFalse);
      expect(manual.skill.disableModelInvocation, isTrue);
      expect(loaded.enabledSkillMap(), isNot(contains('manual')));
      expect(
        loaded.entries.any(
          (entry) => entry.skill.name == 'demo' && !entry.isEffective,
        ),
        isTrue,
      );
    },
  );

  test('malformed metadata remains visible as a diagnostic', () async {
    final root = Directory('${temp.path}/user');
    final folder = Directory('${root.path}/broken');
    await folder.create(recursive: true);
    await File('${folder.path}/SKILL.md').writeAsString('not front matter');

    final loaded = await const SkillCatalogService().scan(
      roots: [SkillRoot(source: SkillSource.piUser, path: root.path)],
    );

    expect(loaded.entries, isEmpty);
    expect(
      loaded.diagnostics.single.diagnostic.code,
      SkillDiagnosticCode.invalidMetadata,
    );
    expect(
      loaded.diagnostics.single.diagnostic.path,
      startsWith('piUser:/.../'),
    );
    expect(
      loaded.diagnostics.single.diagnostic.path,
      isNot(contains(temp.path)),
    );
  });
}

Future<void> _writeSkill(
  Directory root,
  String name,
  String description, {
  bool disableModel = false,
}) async {
  final folder = Directory('${root.path}/$name');
  await folder.create(recursive: true);
  await File('${folder.path}/SKILL.md').writeAsString('''
---
name: $name
description: $description
disable-model-invocation: $disableModel
---
Instructions for $name.
''');
}
