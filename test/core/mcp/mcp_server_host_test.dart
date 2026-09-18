import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/mcp/mcp_discovery_file.dart';
import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';
import 'package:nai_launcher/core/mcp/mcp_server_host.dart';
import 'package:nai_launcher/core/mcp/mcp_session_registry.dart';

import 'fake_mcp_tool_executor.dart';
import 'mcp_http_test_client.dart';

const String _token = 'host-test-token';

void main() {
  late Directory tempDir;
  late McpDiscoveryFileStore discovery;
  late FakeMcpToolExecutor executor;
  late McpServerHost host;
  late Completer<AbortSignal> slowToolStarted;
  late Completer<void> slowToolRelease;
  final clients = <McpHttpTestClient>[];

  McpHttpTestClient clientFor(McpServerHost host) {
    final client = McpHttpTestClient(endpoint: host.endpoint!, token: _token);
    clients.add(client);
    return client;
  }

  McpServerHost buildHost(McpDiscoveryFileStore store) => McpServerHost(
    executor: executor,
    discovery: store,
    appVersion: '4.2.1',
    pidProvider: () => 4242,
    clock: () => DateTime.utc(2026, 5, 7, 10, 30),
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mcp_server_host_test_');
    discovery = McpDiscoveryFileStore(directory: tempDir);
    slowToolStarted = Completer<AbortSignal>();
    slowToolRelease = Completer<void>();
    executor = FakeMcpToolExecutor([
      FakeAgentTool(name: 'get_application_context', label: 'Context'),
      FakeAgentTool(
        name: 'generate_image',
        label: 'Generate',
        handler: (callId, params, signal) async {
          slowToolStarted.complete(signal);
          await slowToolRelease.future;
          return AgentToolResult(
            content: [const ToolResultTextContent('done')],
            details: null,
          );
        },
      ),
    ]);
    host = buildHost(discovery);
  });

  tearDown(() async {
    if (!slowToolRelease.isCompleted) {
      slowToolRelease.complete();
    }
    for (final client in clients) {
      client.close();
    }
    clients.clear();
    await host.stop();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('is idle before start', () {
    expect(host.isListening, isFalse);
    expect(host.port, isNull);
    expect(host.endpoint, isNull);
    expect(host.sessions, isEmpty);
  });

  test('start binds loopback and publishes the discovery file', () async {
    await host.start(port: 0, token: _token);

    expect(host.isListening, isTrue);
    expect(host.port, isNotNull);
    expect(
      host.endpoint.toString(),
      'http://${McpServerDefaults.loopbackHost}:${host.port}'
      '${McpServerDefaults.endpointPath}',
    );

    final document = await discovery.read();
    expect(document, isNotNull);
    expect(document!.port, host.port);
    expect(document.pid, 4242);
    expect(document.token, _token);
    expect(document.appVersion, '4.2.1');
    expect(document.startedAt, DateTime.utc(2026, 5, 7, 10, 30));
    expect(document.endpoint, host.endpoint);
    expect(document.protocolVersions, contains('2025-11-25'));
    expect(document.protocolVersions, contains('2024-11-05'));
  });

  test('stop closes the server and removes the discovery file', () async {
    await host.start(port: 0, token: _token);
    final port = host.port!;

    await host.stop();

    expect(host.isListening, isFalse);
    expect(host.port, isNull);
    expect(host.endpoint, isNull);
    expect(await discovery.read(), isNull);
    expect(
      Socket.connect(
        McpServerDefaults.loopbackHost,
        port,
        timeout: const Duration(seconds: 2),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('a taken port surfaces as McpHostBindException', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(blocker.close);

    await expectLater(
      host.start(port: blocker.port, token: _token),
      throwsA(
        isA<McpHostBindException>()
            .having((error) => error.port, 'port', blocker.port)
            .having((error) => error.cause, 'cause', isA<SocketException>()),
      ),
    );
    expect(host.isListening, isFalse);
  });

  test('stop tolerates a host that never started', () async {
    await host.stop();
    await host.stop();

    expect(host.isListening, isFalse);
    expect(host.port, isNull);
  });

  test('a failed discovery write releases the bound port', () async {
    final store = _FailingDiscoveryStore(tempDir);
    final failing = buildHost(store);
    addTearDown(failing.stop);

    await expectLater(
      failing.start(port: 0, token: _token),
      throwsA(isA<FileSystemException>()),
    );

    expect(failing.isListening, isFalse);
    expect(failing.port, isNull);
    expect(failing.endpoint, isNull);

    final boundPort = store.lastWrittenPort!;
    final rebound = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      boundPort,
    );
    await rebound.close(force: true);

    await failing.stop();
    await failing.stop();

    store.failWrites = false;
    await failing.start(port: boundPort, token: _token);

    expect(failing.isListening, isTrue);
    expect(failing.port, boundPort);
    expect((await store.read())!.port, boundPort);
  });

  test('a failed start keeps the discovery file of another instance', () async {
    await discovery.write(
      McpDiscoveryDocument(
        port: 20624,
        pid: 777,
        startedAt: DateTime.utc(2026, 5, 7, 9),
        token: 'other-instance-token',
        protocolVersions: const ['2025-11-25'],
        appVersion: '4.2.0',
      ),
    );
    final failing = buildHost(_FailingDiscoveryStore(tempDir));
    addTearDown(failing.stop);

    await expectLater(
      failing.start(port: 0, token: _token),
      throwsA(isA<FileSystemException>()),
    );

    final survivor = await discovery.read();
    expect(survivor, isNotNull);
    expect(survivor!.pid, 777);
    expect(survivor.token, 'other-instance-token');
  });

  test('start and stop can be cycled repeatedly', () async {
    for (var round = 0; round < 3; round++) {
      await host.start(port: 0, token: '$_token-$round');

      expect(host.isListening, isTrue);
      expect(host.port, isNotNull);
      expect((await discovery.read())!.token, '$_token-$round');

      await host.stop();

      expect(host.isListening, isFalse);
      expect(host.port, isNull);
      expect(await discovery.read(), isNull);
    }
  });

  test('starting twice rebinds without leaking the old server', () async {
    await host.start(port: 0, token: _token);
    final first = host.port!;

    await host.start(port: 0, token: _token);

    expect(host.port, isNot(first));
    expect((await discovery.read())!.port, host.port);
  });

  test('serves a full handshake and tool call over HTTP', () async {
    await host.start(port: 0, token: _token);
    final client = clientFor(host);

    await client.initialize(clientName: 'codex', clientVersion: '0.9.1');
    final response = await client.callTool(
      'get_application_context',
      arguments: {'verbose': false},
      id: 3,
    );

    expect(response.statusCode, HttpStatus.ok);
    expect((response.json['result'] as Map)['isError'], isFalse);
    expect(executor.lastCall.clientLabel, 'codex 0.9.1');
  });

  test('rejects a client presenting the wrong token', () async {
    await host.start(port: 0, token: _token);
    final client = McpHttpTestClient(endpoint: host.endpoint!, token: 'nope');
    clients.add(client);

    final response = await client.post({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'ping',
    });

    expect(response.statusCode, HttpStatus.unauthorized);
  });

  test(
    'image capabilities work on the MCP port without granting RPC access',
    () async {
      await host.start(port: 0, token: _token);
      final link = host.imageEndpoint.publish(
        Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
        metadataStripped: true,
      )!;
      final http = HttpClient()..findProxy = (_) => 'DIRECT';
      addTearDown(() => http.close(force: true));
      final image = await (await http.getUrl(link.url)).close();
      expect(image.statusCode, 200);
      expect(await image.fold<List<int>>([], (a, b) => a..addAll(b)), [
        1,
        2,
        3,
      ]);
      final rpc = await (await http.getUrl(host.endpoint!)).close();
      expect(rpc.statusCode, 401);
      await rpc.drain<void>();
      final oldPath = link.url.path;
      await host.stop();
      await host.start(port: 0, token: 'new-token');
      final old = await (await http.getUrl(
        host.endpoint!.replace(path: oldPath),
      )).close();
      expect(old.statusCode, 404);
      await old.drain<void>();
    },
  );

  test(
    'the token is dropped on stop and refreshed on the next start',
    () async {
      await host.start(port: 0, token: _token);
      await host.stop();
      await host.start(port: 0, token: 'second-token');

      final stale = clientFor(host);
      expect(
        (await stale.post({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'ping',
        })).statusCode,
        HttpStatus.unauthorized,
      );

      final fresh = McpHttpTestClient(
        endpoint: host.endpoint!,
        token: 'second-token',
      );
      clients.add(fresh);
      expect((await fresh.initialize()).statusCode, HttpStatus.ok);
    },
  );

  test('sessions and sessionChanges track connected clients', () async {
    final emitted = <List<McpSessionSummary>>[];
    final subscription = host.sessionChanges.listen(emitted.add);
    addTearDown(subscription.cancel);

    await host.start(port: 0, token: _token);
    final client = clientFor(host);
    await client.initialize(clientName: 'claude-code', clientVersion: '2.4.0');

    expect(host.sessions, hasLength(1));
    expect(host.sessions.single.id, client.sessionId);
    expect(host.sessions.single.clientName, 'claude-code');
    expect(host.sessions.single.clientVersion, '2.4.0');
    expect(emitted.last.single.clientName, 'claude-code');

    await client.delete();
    expect(host.sessions, isEmpty);
    expect(emitted.last, isEmpty);
  });

  test('stop aborts calls that are still running', () async {
    await host.start(port: 0, token: _token);
    final client = clientFor(host);
    await client.initialize();
    // A stopping host force-closes its sockets, so the caller sees either a
    // 503 or a dropped connection; only the abort matters here.
    final pending = client
        .callTool('generate_image', id: 4)
        .then<void>((_) {}, onError: (Object _) {});

    final signal = await slowToolStarted.future;
    await host.stop();
    await pending;

    expect(signal.aborted, isTrue);
    expect(signal.reason, 'server stopped');
    expect(host.sessions, isEmpty);
  });
}

class _FailingDiscoveryStore extends McpDiscoveryFileStore {
  _FailingDiscoveryStore(Directory directory) : super(directory: directory);

  bool failWrites = true;
  int? lastWrittenPort;

  @override
  Future<void> write(McpDiscoveryDocument document) async {
    lastWrittenPort = document.port;
    if (failWrites) {
      throw const FileSystemException('discovery directory is not writable');
    }
    return super.write(document);
  }
}
