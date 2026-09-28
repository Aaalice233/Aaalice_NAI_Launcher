import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/core/agent/harness/skills.dart';

void main() {
  test('invalid skill metadata is diagnosed and excluded', () async {
    final root = await Directory.systemTemp.createTemp('agent-skills-');
    addTearDown(() => root.delete(recursive: true));
    final skillDir = Directory(
      '${root.path}${Platform.pathSeparator}valid-directory',
    );
    await skillDir.create(recursive: true);
    await File(
      '${skillDir.path}${Platform.pathSeparator}SKILL.md',
    ).writeAsString('''---
name: Wrong Name
description: Invalid metadata must not load.
---
Instructions
''');
    final env = DartIoExecutionEnv(
      workingDirectory: root.path,
      allowOutsideWorkingDirectory: true,
    );

    final result = await loadSkills(env, root.path);

    expect(result.skills, isEmpty);
    expect(
      result.diagnostics.map((item) => item.code),
      contains(SkillDiagnosticCode.invalidMetadata),
    );
  });
}
