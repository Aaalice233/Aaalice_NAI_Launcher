import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_stdio_proxy.dart';

void main() {
  group('McpStdioProxy', () {
    late _FakeMcpServer server;
    late _MemorySink output;
    late _MemorySink diagnostics;

    setUp(() async {
      server = await _FakeMcpServer.start();
      output = _MemorySink();
      diagnostics = _MemorySink();
      addTearDown(() async {
        await output.dispose();
        await diagnostics.dispose();
        await server.close();
      });
    });

    Future<int> runProxy(List<String> stdinLines, {String? token}) {
      final proxy = McpStdioProxy(
        endpoint: server.endpoint,
        token: token ?? server.token,
        input: Stream<List<int>>.fromIterable(
          stdinLines.map((line) => utf8.encode('$line\n')),
        ),
        output: output.sink,
        diagnostics: diagnostics.sink,
      );
      return proxy.run();
    }

    test(
      'propagates the session and protocol headers after initialize',
      () async {
        final exitCode = await runProxy([
          _initialize,
          '',
          _notification,
          _toolsList,
        ]);

        expect(exitCode, 0);
        final lines = await output.lines();
        expect(lines, hasLength(2));
        expect(
          _decode(lines[0])['result'],
          containsPair('protocolVersion', '2025-11-25'),
        );
        expect(_decode(lines[1])['id'], 3);

        expect(server.requests.map((request) => request.method), [
          'POST',
          'POST',
          'POST',
          'DELETE',
        ]);
        expect(server.requests[0].sessionId, isNull);
        expect(
          server.requests[0].accept,
          'application/json, text/event-stream',
        );
        expect(server.requests[0].authorization, 'Bearer ${server.token}');
        for (final request in server.requests.skip(1)) {
          expect(request.sessionId, 'session-1');
          expect(request.protocolVersion, '2025-11-25');
        }
        expect(server.deleted, isTrue);
      },
    );

    test('answers a notification with nothing on stdout', () async {
      final exitCode = await runProxy([_initialize, _notification]);

      expect(exitCode, 0);
      expect(await output.lines(), hasLength(1));
      expect(server.requests[1].body, contains('notifications/initialized'));
    });

    test('writes every server-sent event as its own stdout line', () async {
      final exitCode = await runProxy([_initialize, _toolsCall]);

      expect(exitCode, 0);
      final lines = await output.lines();
      expect(lines, hasLength(3));
      expect(_decode(lines[1])['method'], 'notifications/progress');
      expect(_decode(lines[2])['id'], 4);
      expect(
        (_decode(lines[2])['result']! as Map<String, Object?>)['isError'],
        isFalse,
      );
    });

    test('synthesizes a JSON-RPC error when the token is rejected', () async {
      final exitCode = await runProxy([_initialize], token: 'wrong-token');

      expect(exitCode, 0);
      final lines = await output.lines();
      expect(lines, hasLength(1));
      final error = _decode(lines.single)['error']! as Map<String, Object?>;
      expect(_decode(lines.single)['id'], 1);
      expect(error['code'], -32000);
      expect(
        error['message'],
        'NAI Launcher MCP endpoint returned HTTP 401: invalid token',
      );
      expect(await diagnostics.text(), contains('HTTP 401'));
    });

    test('drops the session and reports the error on HTTP 404', () async {
      final proxy = McpStdioProxy(
        endpoint: server.endpoint,
        token: server.token,
        input: _controlledStdin([
          _initialize,
          () => server.rejectSession = true,
          _toolsList,
          () => server.rejectSession = false,
          _toolsList,
        ]),
        output: output.sink,
        diagnostics: diagnostics.sink,
      );

      expect(await proxy.run(), 0);
      final lines = await output.lines();
      expect(lines, hasLength(3));
      expect(
        (_decode(lines[1])['error']! as Map<String, Object?>)['message'],
        startsWith('NAI Launcher MCP endpoint returned HTTP 404'),
      );
      // The launcher forgot the session, so nothing may claim it again.
      expect(server.requests[2].sessionId, isNull);
      expect(server.requests[2].protocolVersion, isNull);
      expect(server.deleted, isFalse);
    });

    test('claims the new session when the client re-initializes', () async {
      final proxy = McpStdioProxy(
        endpoint: server.endpoint,
        token: server.token,
        input: _controlledStdin([
          _initialize,
          () => server.rejectSession = true,
          _toolsList,
          () => server.rejectSession = false,
          _initialize,
          _toolsList,
        ]),
        output: output.sink,
        diagnostics: diagnostics.sink,
      );

      expect(await proxy.run(), 0);
      expect(server.requests[2].body, contains('initialize'));
      expect(server.requests[2].sessionId, isNull);
      expect(server.requests[2].protocolVersion, isNull);
      expect(server.requests[3].sessionId, 'session-2');
      expect(server.requests[3].protocolVersion, '2025-11-25');
      expect(server.requests.last.method, 'DELETE');
      expect(server.requests.last.sessionId, 'session-2');
    });

    test('ignores a line that is not a JSON-RPC object', () async {
      final exitCode = await runProxy(['not json', '[1,2,3]', _initialize]);

      expect(exitCode, 0);
      expect(await output.lines(), hasLength(1));
      expect(await diagnostics.text(), contains('malformed JSON-RPC line'));
    });

    test('exits 2 when the endpoint refuses the connection', () async {
      final closedPort = await _reserveClosedPort();
      final proxy = McpStdioProxy(
        endpoint: Uri.parse('http://127.0.0.1:$closedPort/mcp'),
        token: 'token',
        input: Stream<List<int>>.fromIterable([utf8.encode('$_initialize\n')]),
        output: output.sink,
        diagnostics: diagnostics.sink,
      );

      expect(await proxy.run(), 2);
      expect(await output.lines(), isEmpty);
      expect(await diagnostics.text(), contains('Cannot reach'));
    });

    test('logs protocol activity to stderr only when verbose', () async {
      final proxy = McpStdioProxy(
        endpoint: server.endpoint,
        token: server.token,
        input: Stream<List<int>>.fromIterable([utf8.encode('$_initialize\n')]),
        output: output.sink,
        diagnostics: diagnostics.sink,
        verbose: true,
      );

      expect(await proxy.run(), 0);
      final logged = await diagnostics.text();
      expect(logged, contains('-> initialize'));
      expect(logged, contains('<- HTTP 200'));
      expect(logged, isNot(contains(server.token)));
    });
  });
}

const String _initialize =
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}';
const String _notification =
    '{"jsonrpc":"2.0","method":"notifications/initialized"}';
const String _toolsList = '{"jsonrpc":"2.0","id":3,"method":"tools/list"}';
const String _toolsCall = '{"jsonrpc":"2.0","id":4,"method":"tools/call"}';

Map<String, Object?> _decode(String line) =>
    jsonDecode(line) as Map<String, Object?>;

/// Emits stdin lines with interleaved side effects so a test can change the
/// server's behaviour between two forwarded messages.
Stream<List<int>> _controlledStdin(List<Object> steps) async* {
  for (final step in steps) {
    if (step is String) {
      yield utf8.encode('$step\n');
    } else {
      (step as void Function())();
    }
  }
}

Future<int> _reserveClosedPort() async {
  final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = probe.port;
  await probe.close();
  return port;
}

class _RecordedRequest {
  _RecordedRequest({
    required this.method,
    required this.authorization,
    required this.accept,
    required this.sessionId,
    required this.protocolVersion,
    required this.body,
  });

  final String method;
  final String? authorization;
  final String? accept;
  final String? sessionId;
  final String? protocolVersion;
  final String body;
}

class _FakeMcpServer {
  _FakeMcpServer._(this._server, this.token);

  static Future<_FakeMcpServer> start({String token = 'test-token'}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeMcpServer._(server, token);
    server.listen(fake._handle);
    return fake;
  }

  final HttpServer _server;
  final String token;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];
  bool rejectSession = false;
  bool deleted = false;
  int _sessions = 0;

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}/mcp');

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    requests.add(
      _RecordedRequest(
        method: request.method,
        authorization: request.headers.value(HttpHeaders.authorizationHeader),
        accept: request.headers.value(HttpHeaders.acceptHeader),
        sessionId: request.headers.value('Mcp-Session-Id'),
        protocolVersion: request.headers.value('MCP-Protocol-Version'),
        body: body,
      ),
    );
    final response = request.response;
    if (request.method == 'DELETE') {
      deleted = true;
      await response.close();
      return;
    }
    if (request.headers.value(HttpHeaders.authorizationHeader) !=
        'Bearer $token') {
      response.statusCode = HttpStatus.unauthorized;
      response.write('invalid token');
      await response.close();
      return;
    }

    final message = jsonDecode(body) as Map<String, Object?>;
    final id = message['id'];
    switch (message['method']) {
      case 'initialize':
        response.headers.set('Mcp-Session-Id', 'session-${++_sessions}');
        await _writeJson(response, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-11-25',
            'capabilities': <String, Object?>{},
            'serverInfo': {'name': 'nai-launcher', 'version': '0.0.0'},
          },
        });
      case 'tools/call':
        await _writeEventStream(response, [
          {
            'jsonrpc': '2.0',
            'method': 'notifications/progress',
            'params': {'progress': 1, 'total': 2},
          },
          {
            'jsonrpc': '2.0',
            'id': id,
            'result': {'isError': false, 'content': <Object?>[]},
          },
        ]);
      default:
        if (rejectSession) {
          response.statusCode = HttpStatus.notFound;
          response.write('unknown session');
          await response.close();
          return;
        }
        if (id == null) {
          response.statusCode = HttpStatus.accepted;
          await response.close();
          return;
        }
        await _writeJson(response, {
          'jsonrpc': '2.0',
          'id': id,
          'result': {'tools': <Object?>[]},
        });
    }
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, Object?> message,
  ) async {
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(message));
    await response.close();
  }

  Future<void> _writeEventStream(
    HttpResponse response,
    List<Map<String, Object?>> messages,
  ) async {
    response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
    response.write(': keep-alive\n\n');
    for (final message in messages) {
      response.write('event: message\ndata: ${jsonEncode(message)}\n\n');
    }
    await response.close();
  }
}

/// Collects everything written to an [IOSink] without touching the process.
class _MemorySink {
  _MemorySink() {
    _controller = StreamController<List<int>>();
    _subscription = _controller.stream.listen(_chunks.add);
    sink = IOSink(_controller.sink);
  }

  late final StreamController<List<int>> _controller;
  late final StreamSubscription<List<int>> _subscription;
  late final IOSink sink;
  final List<List<int>> _chunks = <List<int>>[];

  Future<String> text() async {
    await sink.flush();
    await Future<void>.delayed(Duration.zero);
    return utf8.decode(_chunks.expand((chunk) => chunk).toList());
  }

  Future<List<String>> lines() async {
    final collected = await text();
    if (collected.isEmpty) {
      return const <String>[];
    }
    return const LineSplitter().convert(collected);
  }

  Future<void> dispose() async {
    await sink.close();
    await _subscription.cancel();
  }
}
