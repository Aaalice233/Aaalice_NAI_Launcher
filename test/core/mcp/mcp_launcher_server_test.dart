import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart' as mcp;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_launcher_server.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:stream_channel/stream_channel.dart';

import 'fake_mcp_tool_executor.dart';

void main() {
  late StreamChannelController<String> controller;
  late StreamController<Map<String, Object?>> incoming;
  late StreamSubscription<String> incomingSubscription;
  late McpLauncherServer server;
  late FakeMcpToolExecutor executor;
  late Map<String, AbortController> abortControllers;
  mcp.Implementation? announcedClient;

  Map<String, Object?> decode(String raw) =>
      jsonDecode(raw) as Map<String, Object?>;

  Future<Map<String, Object?>> send(Map<String, Object?> message) {
    final id = message['id'];
    final response = incoming.stream
        .firstWhere((candidate) => candidate['id'] == id)
        .timeout(const Duration(seconds: 5));
    controller.local.sink.add(jsonEncode(message));
    return response;
  }

  Future<Map<String, Object?>> initialize({
    String clientName = 'claude-code',
    String clientVersion = '2.4.0',
  }) async {
    final result = await send({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': <String, Object?>{},
        'clientInfo': {'name': clientName, 'version': clientVersion},
      },
    });
    controller.local.sink.add(
      jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
    );
    return result['result'] as Map<String, Object?>;
  }

  void buildServer(FakeMcpToolExecutor toolExecutor) {
    executor = toolExecutor;
    controller = StreamChannelController<String>();
    incoming = StreamController<Map<String, Object?>>.broadcast();
    incomingSubscription = controller.local.stream.listen(
      (raw) => incoming.add(decode(raw)),
    );
    abortControllers = <String, AbortController>{};
    server = McpLauncherServer.fromStreamChannel(
      controller.foreign,
      executor: executor,
      sessionId: 'session-abcdef',
      appVersion: '9.9.9',
      signalFor: (callId) =>
          (abortControllers[callId] ??= AbortController()).signal,
      onClientInfo: (info) => announcedClient = info,
    );
  }

  setUp(() {
    announcedClient = null;
    buildServer(
      FakeMcpToolExecutor([
        FakeAgentTool(name: 'get_application_context', label: 'Context'),
        FakeAgentTool(
          name: 'save_generated_image',
          label: 'Save',
          parameters: const {
            'type': 'object',
            'properties': {
              'path': {'type': 'string'},
            },
          },
        ),
        FakeAgentTool(name: 'delete_fixed_tag', label: 'Delete'),
      ]),
    );
  });

  tearDown(() async {
    await server.shutdown();
    await incomingSubscription.cancel();
    await incoming.close();
    await controller.local.sink.close();
  });

  test(
    'initialize reports the launcher implementation and instructions',
    () async {
      final result = await initialize();

      expect(result['protocolVersion'], '2025-11-25');
      expect(result['serverInfo'], {
        'name': McpServerDefaults.serverName,
        'version': '9.9.9',
      });
      expect((result['capabilities'] as Map)['tools'], {'listChanged': true});
      expect(
        result['instructions'],
        isNot(contains('get_application_context')),
      );
      expect(result['instructions'], contains('submit_generation'));
      expect((result['instructions'] as String).length, lessThan(220));
    },
  );

  test('initialize hands the client implementation to the host', () async {
    await initialize(clientName: 'cursor', clientVersion: '1.2.3');

    expect(announcedClient, isNotNull);
    expect(announcedClient!.name, 'cursor');
    expect(announcedClient!.version, '1.2.3');
    expect(McpLauncherServer.clientLabelFor(announcedClient), 'cursor 1.2.3');
    expect(server.clientLabel, 'cursor 1.2.3');
  });

  test('clientLabel falls back before the handshake', () {
    expect(server.clientLabel, McpLauncherServer.unknownClientLabel);
    expect(
      McpLauncherServer.clientLabelFor(null),
      McpLauncherServer.unknownClientLabel,
    );
  });

  test(
    'an unsupported client protocol version falls back to the latest',
    () async {
      final result = await send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '1999-01-01',
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': 'old', 'version': '0.1'},
        },
      });

      expect(
        (result['result'] as Map)['protocolVersion'],
        mcp.ProtocolVersion.latestSupported.versionString,
      );
    },
  );

  test('tools/list keeps the executor order and carries annotations', () async {
    await initialize();

    final result = await send({
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/list',
    });
    final tools = ((result['result'] as Map)['tools'] as List)
        .cast<Map<String, Object?>>();

    expect(tools.map((tool) => tool['name']), [
      'get_application_context',
      'save_generated_image',
      'delete_fixed_tag',
    ]);
    expect(tools.first['title'], 'Context');
    expect((tools.first['annotations'] as Map)['readOnlyHint'], isTrue);
    expect((tools.last['annotations'] as Map)['destructiveHint'], isTrue);
    expect((tools[1]['inputSchema'] as Map)['properties'], {
      'path': {'type': 'string'},
    });
  });

  test(
    'tools/call forwards arguments, session, call id and client label',
    () async {
      await initialize();

      final result = await send({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'save_generated_image',
          'arguments': {'path': 'C:/tmp/a.png'},
          '_meta': {McpServerDefaults.callIdMetaKey: 'sessiona-3'},
        },
      });

      expect(executor.calls, hasLength(1));
      expect(executor.lastCall.toolName, 'save_generated_image');
      expect(executor.lastCall.sessionId, 'session-abcdef');
      expect(executor.lastCall.callId, 'sessiona-3');
      expect(executor.lastCall.arguments, {'path': 'C:/tmp/a.png'});
      expect(executor.lastCall.clientLabel, 'claude-code 2.4.0');
      expect((result['result'] as Map)['isError'], isFalse);
    },
  );

  test(
    'tools/call without injected metadata gets a generated call id',
    () async {
      await initialize();

      await send({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {'name': 'get_application_context'},
      });

      expect(executor.lastCall.callId, 'session-abcdef-local-0');
      expect(executor.lastCall.arguments, isEmpty);
    },
  );

  test('tools/call passes the abort signal for its call id', () async {
    final observed = Completer<String?>();
    buildServer(
      FakeMcpToolExecutor([
        FakeAgentTool(
          name: 'get_application_context',
          label: 'Context',
          handler: (callId, params, signal) async {
            signal!.addListener(observed.complete);
            await observed.future;
            return AgentToolResult(
              content: [const ToolResultTextContent('aborted')],
              details: null,
            );
          },
        ),
      ]),
    );
    await initialize();

    final pending = send({
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'tools/call',
      'params': {
        'name': 'get_application_context',
        '_meta': {McpServerDefaults.callIdMetaKey: 'call-5'},
      },
    });
    await Future<void>.delayed(Duration.zero);
    abortControllers['call-5']!.abort('cancelled by client');

    await pending;
    expect(await observed.future, 'cancelled by client');
  });

  test(
    'an executor failure becomes an isError result, not an RPC error',
    () async {
      buildServer(
        FakeMcpToolExecutor([
          FakeAgentTool(name: 'get_application_context', label: 'Context'),
        ], onCall: (_) => Future.error(StateError('tool exploded'))),
      );
      await initialize();

      final result = await send({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/call',
        'params': {'name': 'get_application_context'},
      });

      expect(result.containsKey('error'), isFalse);
      final body = result['result'] as Map<String, Object?>;
      expect(body['isError'], isTrue);
      expect(
        ((body['content'] as List).first as Map)['text'],
        contains('tool exploded'),
      );
    },
  );

  test('an unknown tool answers with an isError result', () async {
    await initialize();

    final result = await send({
      'jsonrpc': '2.0',
      'id': 7,
      'method': 'tools/call',
      'params': {'name': 'not_a_tool'},
    });

    expect((result['result'] as Map)['isError'], isTrue);
    expect(executor.calls, isEmpty);
  });

  test('ping answers with an empty result', () async {
    await initialize();

    final result = await send({'jsonrpc': '2.0', 'id': 8, 'method': 'ping'});

    expect(result['result'], isEmpty);
  });
}
