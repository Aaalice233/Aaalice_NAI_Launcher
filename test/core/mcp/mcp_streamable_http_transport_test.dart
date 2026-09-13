import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_bearer_authenticator.dart';
import 'package:nai_launcher/core/mcp/mcp_launcher_server.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';
import 'package:nai_launcher/core/mcp/mcp_streamable_http_transport.dart';

import 'fake_mcp_tool_executor.dart';
import 'mcp_http_test_client.dart';

const String _token = 'transport-test-token';

void main() {
  late HttpServer httpServer;
  late McpSessionRegistry registry;
  late McpStreamableHttpTransport transport;
  late McpHttpTestClient client;
  late FakeMcpToolExecutor executor;
  late Uri endpoint;

  late Completer<AbortSignal> slowToolStarted;
  late Completer<void> slowToolRelease;

  Future<void> startServer({
    int maxBodyBytes = McpServerDefaults.maxBodyBytes,
    Duration keepAliveInterval = McpServerDefaults.keepAliveInterval,
  }) async {
    httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    registry = McpSessionRegistry(
      createServer: (channel, session) => McpLauncherServer.fromStreamChannel(
        channel,
        executor: executor,
        sessionId: session.id,
        appVersion: '1.0.0',
        signalFor: session.signalFor,
        onClientInfo: session.attachClientInfo,
      ),
    );
    transport = McpStreamableHttpTransport(
      sessions: registry,
      authenticator: McpBearerAuthenticator(() => _token),
      maxBodyBytes: maxBodyBytes,
      keepAliveInterval: keepAliveInterval,
    );
    unawaited(() async {
      await for (final request in httpServer) {
        unawaited(transport.handle(request));
      }
    }());
    endpoint = Uri(
      scheme: 'http',
      host: McpServerDefaults.loopbackHost,
      port: httpServer.port,
      path: McpServerDefaults.endpointPath,
    );
    client = McpHttpTestClient(endpoint: endpoint, token: _token);
  }

  setUp(() async {
    slowToolStarted = Completer<AbortSignal>();
    slowToolRelease = Completer<void>();
    executor = FakeMcpToolExecutor([
      FakeAgentTool(name: 'get_application_context', label: 'Context'),
      FakeAgentTool(
        name: 'delete_fixed_tag',
        label: 'Delete',
        handler: (callId, params, signal) async => AgentToolResult(
          content: [const ToolResultTextContent('tag is gone')],
          details: null,
          isError: true,
        ),
      ),
      FakeAgentTool(
        name: 'generate_image',
        label: 'Generate',
        handler: (callId, params, signal) async {
          slowToolStarted.complete(signal);
          signal!.addListener((_) {
            if (!slowToolRelease.isCompleted) {
              slowToolRelease.complete();
            }
          });
          await slowToolRelease.future;
          return AgentToolResult(
            content: [ToolResultTextContent('finished ${signal.reason}')],
            details: null,
          );
        },
      ),
    ]);
    await startServer();
  });

  tearDown(() async {
    if (!slowToolRelease.isCompleted) {
      slowToolRelease.complete();
    }
    client.close();
    await registry.dispose();
    await transport.shutdown();
    await httpServer.close(force: true);
  });

  group('gatekeeping', () {
    test('rejects a request without a bearer token', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, sendAuthorization: false);

      expect(response.statusCode, HttpStatus.unauthorized);
      expect(response.header('www-authenticate'), 'Bearer');
    });

    test('rejects a wrong bearer token', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, authorization: 'Bearer nope');

      expect(response.statusCode, HttpStatus.unauthorized);
    });

    test('rejects a remote Origin', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, origin: 'http://evil.com');

      expect(response.statusCode, HttpStatus.forbidden);
    });

    test('accepts a loopback Origin', () async {
      final response = await client.post(
        {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-11-25',
            'capabilities': <String, Object?>{},
            'clientInfo': {'name': 'browser', 'version': '1'},
          },
        },
        origin: 'http://localhost:5173',
        sendSession: false,
      );

      expect(response.statusCode, HttpStatus.ok);
    });

    test('rejects a rebinding Host header', () async {
      final body = jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'});
      final raw = await client.raw(
        'POST ${McpServerDefaults.endpointPath} HTTP/1.1\r\n'
        'Host: evil.com\r\n'
        'Authorization: Bearer $_token\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${body.length}\r\n'
        'Connection: close\r\n\r\n',
        body: body,
      );

      expect(raw, startsWith('HTTP/1.1 403'));
    });

    test('rejects another path', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, path: endpoint.replace(path: '/not-mcp'));

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('answers GET with 405 and the supported verbs', () async {
      final response = await client.get();

      expect(response.statusCode, HttpStatus.methodNotAllowed);
      expect(response.header('allow'), 'POST, DELETE');
    });

    test('answers PUT with 405', () async {
      final response = await client.method('PUT');

      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });
  });

  group('request validation', () {
    test('rejects a non-JSON content type', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, contentType: 'text/plain');

      expect(response.statusCode, HttpStatus.unsupportedMediaType);
    });

    test('rejects a malformed body with a parse error', () async {
      final response = await client.post(null, rawBody: '{not json');

      expect(response.statusCode, HttpStatus.badRequest);
      expect((response.json['error'] as Map)['code'], -32700);
      expect(response.json['id'], isNull);
    });

    test('rejects a JSON-RPC batch', () async {
      final response = await client.post([
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
      ]);

      expect(response.statusCode, HttpStatus.badRequest);
      expect((response.json['error'] as Map)['code'], -32600);
      expect((response.json['error'] as Map)['message'], contains('batching'));
    });

    test(
      'rejects a body that is neither request, notification nor response',
      () async {
        final response = await client.post({'jsonrpc': '2.0'});

        expect(response.statusCode, HttpStatus.badRequest);
        expect((response.json['error'] as Map)['code'], -32600);
      },
    );

    test('rejects an unknown MCP-Protocol-Version', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      }, protocolVersion: '1999-01-01');

      expect(response.statusCode, HttpStatus.badRequest);
      expect((response.json['error'] as Map)['code'], -32600);
    });

    test('accepts a known MCP-Protocol-Version', () async {
      await client.initialize();

      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'ping',
      }, protocolVersion: '2025-11-25');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.json['result'], isEmpty);
    });

    test('rejects a chunked body over the limit', () async {
      await httpServer.close(force: true);
      await registry.dispose();
      await startServer(maxBodyBytes: 512);

      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
        'params': {'padding': 'x' * 2048},
      });

      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test('rejects a declared Content-Length over the limit', () async {
      await httpServer.close(force: true);
      await registry.dispose();
      await startServer(maxBodyBytes: 512);

      final body = jsonEncode({'padding': 'x' * 4000});
      final raw = await client.raw(
        'POST ${McpServerDefaults.endpointPath} HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'Authorization: Bearer $_token\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${body.length}\r\n'
        'Connection: close\r\n\r\n',
        body: body,
      );

      expect(raw, startsWith('HTTP/1.1 413'));
    });
  });

  group('sessions', () {
    test('initialize opens a session and returns its id', () async {
      final response = await client.initialize();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.sessionId, isNotNull);
      expect(registry.find(response.sessionId!), isNotNull);
      expect(
        (response.json['result'] as Map)['serverInfo'],
        containsPair('name', McpServerDefaults.serverName),
      );
    });

    test('a request without a session id is rejected', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      }, sendSession: false);

      expect(response.statusCode, HttpStatus.notFound);
      expect((response.json['error'] as Map)['code'], -32001);
      expect(response.json['id'], 2);
    });

    test('a request with an unknown session id is rejected', () async {
      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      }, session: 'not-a-session');

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('notifications are accepted without a body', () async {
      await client.initialize();

      final response = await client.post({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });

      expect(response.statusCode, HttpStatus.accepted);
      expect(response.body, isEmpty);
    });

    test('DELETE ends the session and later calls are rejected', () async {
      await client.initialize();
      final sessionId = client.sessionId!;

      final deleted = await client.delete();
      expect(deleted.statusCode, HttpStatus.ok);
      expect(registry.find(sessionId), isNull);

      final afterwards = await client.post({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/list',
      });
      expect(afterwards.statusCode, HttpStatus.notFound);
    });

    test('DELETE for an unknown session is a 404', () async {
      final response = await client.delete(session: 'not-a-session');

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('two clients get isolated sessions', () async {
      final second = McpHttpTestClient(endpoint: endpoint, token: _token);
      addTearDown(second.close);

      await client.initialize(clientName: 'claude-code');
      await second.initialize(clientName: 'codex');

      expect(client.sessionId, isNot(second.sessionId));
      expect(registry.length, 2);
      expect(
        registry.summaries.map((summary) => summary.clientName),
        containsAll(<String>['claude-code', 'codex']),
      );

      await client.delete();
      expect(registry.find(second.sessionId!), isNotNull);
      final stillWorks = await second.post({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/list',
      });
      expect(stillWorks.statusCode, HttpStatus.ok);
    });
  });

  group('tool calls', () {
    test('tools/list is deterministic in JSON mode', () async {
      await client.initialize();

      final response = await client.post({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      expect(response.header('content-type'), startsWith('application/json'));
      final tools = ((response.json['result'] as Map)['tools'] as List)
          .cast<Map<String, Object?>>();
      expect(tools.map((tool) => tool['name']), [
        'get_application_context',
        'delete_fixed_tag',
        'generate_image',
      ]);
    });

    test('tools/call answers with JSON and injects the call id', () async {
      await client.initialize();

      final response = await client.callTool(
        'get_application_context',
        arguments: {'verbose': true},
        id: 7,
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.json['id'], 7);
      expect(executor.lastCall.arguments, {'verbose': true});
      expect(executor.lastCall.sessionId, client.sessionId);
      expect(
        executor.lastCall.callId,
        '${client.sessionId!.substring(0, 8)}-7',
      );
      expect(executor.lastCall.clientLabel, 'claude-code 2.4.0');
    });

    test('tools/call answers with an event stream when asked', () async {
      await client.initialize(acceptEventStream: true);

      final response = await client.callTool(
        'get_application_context',
        id: 8,
        acceptEventStream: true,
      );

      expect(response.statusCode, HttpStatus.ok);
      expect(response.header('content-type'), startsWith('text/event-stream'));
      expect(response.body, contains('event: message'));
      expect(response.events, hasLength(1));
      expect(response.events.single['id'], 8);
      expect(
        ((response.events.single['result'] as Map)['content'] as List).first,
        containsPair('text', 'get_application_context ran'),
      );
    });

    test('a failing tool keeps isError inside the result', () async {
      await client.initialize();

      final response = await client.callTool('delete_fixed_tag', id: 9);

      expect(response.statusCode, HttpStatus.ok);
      expect((response.json['result'] as Map)['isError'], isTrue);
    });

    test('an event stream emits keep-alive comments while waiting', () async {
      await httpServer.close(force: true);
      await registry.dispose();
      await startServer(keepAliveInterval: const Duration(milliseconds: 50));
      await client.initialize(acceptEventStream: true);

      final pending = client.callTool(
        'generate_image',
        id: 11,
        acceptEventStream: true,
      );
      await slowToolStarted.future;
      await Future<void>.delayed(const Duration(milliseconds: 260));
      slowToolRelease.complete();

      final response = await pending;
      expect(response.keepAliveCount, greaterThanOrEqualTo(2));
      expect(response.events.single['id'], 11);
    });

    test('notifications/cancelled aborts the running call', () async {
      await client.initialize();

      final pending = client.callTool('generate_image', id: 12);
      final signal = await slowToolStarted.future;

      final cancelled = await client.post({
        'jsonrpc': '2.0',
        'method': 'notifications/cancelled',
        'params': {'requestId': 12, 'reason': 'user stopped'},
      });

      expect(cancelled.statusCode, HttpStatus.accepted);
      final response = await pending;
      expect(signal.aborted, isTrue);
      expect(signal.reason, 'cancelled by client');
      expect(
        ((response.json['result'] as Map)['content'] as List).first,
        containsPair('text', 'finished cancelled by client'),
      );
    });

    test(
      'concurrent calls in one session get only their own response',
      () async {
        await client.initialize(acceptEventStream: true);

        final slow = client.callTool(
          'generate_image',
          id: 21,
          acceptEventStream: true,
        );
        await slowToolStarted.future;
        final fast = await client.callTool(
          'get_application_context',
          id: 22,
          acceptEventStream: true,
        );
        expect(fast.events.map((event) => event['id']), [22]);

        slowToolRelease.complete();
        final slowResponse = await slow;
        expect(slowResponse.events.map((event) => event['id']), [21]);
      },
    );

    test(
      'progress rides only on the stream whose request owns its token',
      () async {
        await client.initialize(acceptEventStream: true);

        final pending = client.post({
          'jsonrpc': '2.0',
          'id': 23,
          'method': 'tools/call',
          'params': {
            'name': 'generate_image',
            'arguments': <String, Object?>{},
            '_meta': {'progressToken': 'slow'},
          },
        }, acceptEventStream: true);
        await slowToolStarted.future;

        // Stands in for the protocol server emitting messages on its own.
        final serverSink = registry.find(client.sessionId!)!.channel.sink;
        for (final notification in <Map<String, Object?>>[
          {
            'method': 'notifications/progress',
            'params': {'progressToken': 'other', 'progress': 1},
          },
          {
            'method': 'notifications/progress',
            'params': {'progressToken': 'slow', 'progress': 1},
          },
          {'method': 'notifications/tools/list_changed'},
        ]) {
          serverSink.add(jsonEncode({'jsonrpc': '2.0', ...notification}));
        }
        await Future<void>.delayed(Duration.zero);
        slowToolRelease.complete();

        final response = await pending;
        expect(response.events.map((event) => event['method'] ?? event['id']), [
          'notifications/progress',
          23,
        ]);
        expect(
          (response.events.first['params'] as Map)['progressToken'],
          'slow',
        );
      },
    );

    test('a client that hangs up aborts the running call', () async {
      await client.initialize(acceptEventStream: true);
      final body = jsonEncode({
        'jsonrpc': '2.0',
        'id': 13,
        'method': 'tools/call',
        'params': {'name': 'generate_image', 'arguments': <String, Object?>{}},
      });

      final socket = await Socket.connect(endpoint.host, endpoint.port);
      socket.listen((_) {}, onError: (Object _) {});
      socket.write(
        'POST ${McpServerDefaults.endpointPath} HTTP/1.1\r\n'
        'Host: 127.0.0.1\r\n'
        'Authorization: Bearer $_token\r\n'
        'Accept: text/event-stream\r\n'
        '${McpServerDefaults.sessionIdHeader}: ${client.sessionId}\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${body.length}\r\n\r\n$body',
      );
      await socket.flush();

      final signal = await slowToolStarted.future;
      socket.destroy();

      final reason = await _abortReason(
        signal,
      ).timeout(const Duration(seconds: 5));
      expect(reason, 'client disconnected');
    });
  });
}

Future<String?> _abortReason(AbortSignal signal) {
  final completer = Completer<String?>();
  signal.addListener((reason) {
    if (!completer.isCompleted) {
      completer.complete(reason);
    }
  });
  return completer.future;
}
