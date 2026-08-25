import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/execution_toolbox.dart';

void main() {
  late Directory tmp;
  late List<AgentTool> tools;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('execution_toolbox_test');
    tools = ExecutionToolbox(tmp.path).tools();
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  AgentTool tool(String name) => tools.firstWhere((t) => t.name == name);

  String textOf(AgentToolResult result) => result.content
      .whereType<ToolResultTextContent>()
      .map((c) => c.text)
      .join();

  test('exposes only the read tool (write/edit/bash disabled)', () {
    expect(tools.map((t) => t.name), ['read']);
  });

  test('read round-trips via workspace-relative path', () async {
    final file = File(
      '${tmp.path}${Platform.pathSeparator}notes'
      '${Platform.pathSeparator}prompt.txt',
    );
    await file.create(recursive: true);
    await file.writeAsString('masterpiece, best quality');

    final readResult = await tool('read').execute('t2', {
      'path': 'notes/prompt.txt',
    });
    expect(textOf(readResult), contains('masterpiece, best quality'));
  });

  test('read of missing file surfaces an error result', () async {
    await expectLater(
      tool('read').execute('t6', {'path': 'no_such_file.txt'}),
      throwsA(isA<Object>()),
    );
  });
}
