import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_bridge.dart';

void main() {
  late List<String> evaluated;
  late Model3dBridge bridge;
  late List<(String, Map<String, dynamic>)> events;

  Future<void> fakeEval(String source) async {
    evaluated.add(source);
  }

  /// 从 evaluateJavascript 源码中还原 dispatch 的命令 JSON
  Map<String, dynamic> lastCommand() {
    final match = RegExp(r'^window\.naiEditor\.dispatch\((.+)\)$')
        .firstMatch(evaluated.last)!;
    final inner = jsonDecode(match.group(1)!) as String;
    return jsonDecode(inner) as Map<String, dynamic>;
  }

  void reply(int requestId, {required bool ok, Map<String, dynamic>? data}) {
    bridge.handleJsMessage([
      {'type': 'response', 'requestId': requestId, 'ok': ok, 'data': data ?? {}},
    ]);
  }

  setUp(() {
    evaluated = [];
    events = [];
    bridge = Model3dBridge(
      evalJs: fakeEval,
      timeout: const Duration(milliseconds: 200),
      onEvent: (type, data) => events.add((type, data)),
    );
  });

  test('sends command as double-encoded json and resolves on response', () async {
    final future = bridge.serialize();
    final command = lastCommand();
    expect(command['type'], 'serialize');
    reply(
      command['requestId'] as int,
      ok: true,
      data: {
        'sceneState': {'version': 1},
      },
    );
    expect(await future, {'version': 1});
  });

  test('loadModel passes url/builtin/sceneState', () async {
    final future = bridge.loadModel(
      builtin: 'mannequin',
      sceneState: {'version': 1},
    );
    final command = lastCommand();
    expect(command['builtin'], 'mannequin');
    expect(command['sceneState'], {'version': 1});
    reply(command['requestId'] as int, ok: true, data: {'boneCount': 19});
    expect((await future)['boneCount'], 19);
  });

  test('render decodes base64 png', () async {
    final future = bridge.render(width: 2, height: 2);
    final command = lastCommand();
    expect(command['width'], 2);
    reply(
      command['requestId'] as int,
      ok: true,
      data: {'png': base64Encode([137, 80, 78, 71])},
    );
    expect(await future, [137, 80, 78, 71]);
  });

  test('error response throws Model3dBridgeException', () async {
    final future = bridge.resetPose();
    reply(
      lastCommand()['requestId'] as int,
      ok: false,
      data: {'error': 'boom'},
    );
    await expectLater(future, throwsA(isA<Model3dBridgeException>()));
  });

  test('times out when no response arrives', () async {
    await expectLater(
      bridge.undoPose(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('forwards non-response messages as events', () {
    bridge.handleJsMessage([
      {'type': 'onDirty'},
    ]);
    bridge.handleJsMessage([
      {'type': 'onModelLoaded', 'boneCount': 19, 'duplicateBoneNames': []},
    ]);
    expect(events[0].$1, 'onDirty');
    expect(events[1].$1, 'onModelLoaded');
    expect(events[1].$2['boneCount'], 19);
  });

  test('dispose fails pending commands', () async {
    final future = bridge.serialize();
    bridge.dispose();
    await expectLater(future, throwsA(isA<Model3dBridgeException>()));
  });

  test('ignores messages after dispose', () {
    bridge.dispose();
    bridge.handleJsMessage([
      {'type': 'onDirty'},
    ]);
    expect(events, isEmpty);
  });

  test('malformed response fields do not throw', () {
    expect(
      () => bridge.handleJsMessage([
        {
          'type': 'response',
          'requestId': 'not-an-int',
          'ok': true,
          'data': 'not-a-map',
        },
      ]),
      returnsNormally,
    );
    expect(
      () => bridge.handleJsMessage([
        {'type': 42},
      ]),
      returnsNormally,
    );
  });
}
