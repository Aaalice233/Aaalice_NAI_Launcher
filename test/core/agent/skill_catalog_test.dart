import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
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
        skillEnabledOverrides: const {'manual': false},
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

  test('only current image project Skills are enabled by default', () async {
    final project = Directory('${temp.path}/project-skills');
    final piUser = Directory('${temp.path}/pi-user-skills');
    final commonUser = Directory('${temp.path}/common-user-skills');
    await _writeSkill(project, 'project-skill', 'Project');
    await _writeSkill(piUser, 'pi-skill', 'Pi user');
    await _writeSkill(commonUser, 'global-skill', 'Global user');

    final loaded = await const SkillCatalogService().scan(
      roots: [
        SkillRoot(source: SkillSource.workspace, path: project.path),
        SkillRoot(source: SkillSource.piUser, path: piUser.path),
        SkillRoot(source: SkillSource.commonUser, path: commonUser.path),
      ],
    );

    expect(
      {for (final entry in loaded.effectiveEntries) entry.id: entry.enabled},
      {'project-skill': true, 'pi-skill': false, 'global-skill': false},
    );
    expect(loaded.enabledSkillMap().keys, ['project-skill']);
  });

  test(
    'explicit choices survive rescans and newly discovered Skills',
    () async {
      final project = Directory('${temp.path}/project-skills');
      final global = Directory('${temp.path}/global-skills');
      await _writeSkill(project, 'kept-off', 'Project disabled');
      await _writeSkill(global, 'kept-on', 'Global enabled');

      const overrides = {'kept-off': false, 'kept-on': true};
      await _writeSkill(project, 'new-project', 'New project');
      await _writeSkill(global, 'new-global', 'New global');
      final rescanned = await const SkillCatalogService().scan(
        roots: [
          SkillRoot(source: SkillSource.workspace, path: project.path),
          SkillRoot(source: SkillSource.commonUser, path: global.path),
        ],
        skillEnabledOverrides: overrides,
      );

      expect(
        {
          for (final entry in rescanned.effectiveEntries)
            entry.id: entry.enabled,
        },
        {
          'kept-off': false,
          'kept-on': true,
          'new-project': true,
          'new-global': false,
        },
      );
    },
  );

  test('roots use the current image project path and preserve priority', () {
    final workspace = Directory('${temp.path}/image-project');
    final support = Directory('${temp.path}/support');
    final roots = SkillCatalogService.roots(
      workspaceDirectory: workspace,
      supportDirectory: support,
      environment: {'HOME': '${temp.path}/home'},
    );

    expect(roots.map((root) => root.source), [
      SkillSource.workspace,
      SkillSource.piUser,
      SkillSource.commonUser,
    ]);
    expect(roots.first.path, p.join(workspace.path, '.pi', 'skills'));
    expect(
      roots[1].path,
      p.join('${temp.path}/home', '.pi', 'agent', 'skills'),
    );
    expect(roots[2].path, p.join('${temp.path}/home', '.agents', 'skills'));
  });

  test('roots omit project Skills when no image project path is available', () {
    final roots = SkillCatalogService.roots(
      workspaceDirectory: null,
      supportDirectory: Directory('${temp.path}/support'),
      environment: {'HOME': '${temp.path}/home'},
    );

    expect(roots.map((root) => root.source), [
      SkillSource.piUser,
      SkillSource.commonUser,
    ]);
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
