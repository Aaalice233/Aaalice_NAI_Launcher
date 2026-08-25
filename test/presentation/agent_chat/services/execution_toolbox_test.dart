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

    final readResult = await tool(
      'read',
    ).execute('t2', {'path': 'notes/prompt.txt'});
    expect(textOf(readResult), contains('masterpiece, best quality'));
  });

  test('read of missing file surfaces an error result', () async {
    await expectLater(
      tool('read').execute('t6', {'path': 'no_such_file.txt'}),
      throwsA(isA<Object>()),
    );
  });

  test('read rejects parent traversal outside the workspace', () async {
    final outside = File(
      '${tmp.parent.path}${Platform.pathSeparator}outside-${tmp.path.hashCode}.txt',
    );
    await outside.writeAsString('private');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });

    await expectLater(
      tool('read').execute('t7', {
        'path': '..${Platform.pathSeparator}${outside.uri.pathSegments.last}',
      }),
      throwsA(isA<Object>()),
    );
  });

  test('full access explicitly permits files outside the workspace', () async {
    final outside = File(
      '${tmp.parent.path}${Platform.pathSeparator}outside-full-${tmp.path.hashCode}.txt',
    );
    await outside.writeAsString('explicit access');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete();
    });
    final fullAccessTool = ExecutionToolbox(
      tmp.path,
      allowOutsideWorkspace: true,
    ).tools().single;

    final result = await fullAccessTool.execute('t8', {'path': outside.path});
    expect(textOf(result), contains('explicit access'));
  });

  test('read rejects a symlink that escapes the workspace', () async {
    final outsideDir = await Directory.systemTemp.createTemp('agent-outside');
    final outsideFile = File(
      '${outsideDir.path}${Platform.pathSeparator}secret.txt',
    );
    await outsideFile.writeAsString('secret');
    addTearDown(() async {
      if (await outsideDir.exists()) await outsideDir.delete(recursive: true);
    });
    final link = Link('${tmp.path}${Platform.pathSeparator}escape');
    try {
      await link.create(outsideDir.path);
    } on FileSystemException {
      return;
    }

    await expectLater(
      tool('read').execute('t9', {'path': 'escape/secret.txt'}),
      throwsA(isA<Object>()),
    );
  });

  test('read rejects files above the in-memory safety limit', () async {
    final large = File('${tmp.path}${Platform.pathSeparator}large.txt');
    await large.open(mode: FileMode.write).then((handle) async {
      await handle.truncate(20 * 1024 * 1024 + 1);
      await handle.close();
    });

    await expectLater(
      tool('read').execute('t10', {'path': 'large.txt'}),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('exceeds the 20.0MB read limit'),
        ),
      ),
    );
  });

  test('read reports unsupported BMP conversion as an error result', () async {
    final bmp = File('${tmp.path}${Platform.pathSeparator}image.bmp');
    final bytes = List<int>.filled(30, 0)
      ..[0] = 0x42
      ..[1] = 0x4d
      ..[2] = 30
      ..[10] = 26
      ..[14] = 12
      ..[22] = 1
      ..[24] = 24;
    await bmp.writeAsBytes(bytes);

    final result = await tool('read').execute('t11', {'path': 'image.bmp'});

    expect(textOf(result), contains('Image omitted'));
    expect(result.isError, isTrue);
  });
}
