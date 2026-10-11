import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/cli/mcp_stdio_proxy.dart';

import '../../../helpers/unreachable_loopback.dart';

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

    McpStdioProxy proxyFor(Stream<List<int>> input, {String? token}) =>
        McpStdioProxy(
          endpoint: server.endpoint,
          token: token ?? server.token,
          input: input,
          output: output.sink,
          diagnostics: diagnostics.sink,
        );

    Future<int> runProxy(List<String> stdinLines, {String? token}) {
      return proxyFor(
        Stream<List<int>>.fromIterable(
          stdinLines.map((line) => utf8.encode('$line\n')),
        ),
        token: token,
      ).run();
    }

    /// Starts a proxy whose stdin stays open, so a test can interleave lines
    /// with an in-flight response.
    (_StdinPipe, Future<int>) startProxy() {
      final stdin = _StdinPipe();
      addTearDown(stdin.close);
      return (stdin, proxyFor(stdin.stream).run());
    }

    /// Indexes stdout by JSON-RPC id, because concurrent requests answer in
    /// completion order rather than arrival order.
    Future<Map<Object?, Map<String, Object?>>> answersById() async => {
      for (final line in await output.lines())
        _decode(line)['id']: _decode(line),
    };

    /// Drops the session only once the handshake is answered; flipping it
    /// earlier would be undone by the launcher's own initialize handler.
    Future<void> expireSessionAfterHandshake(_StdinPipe stdin) async {
      stdin.write(_initialize);
      await _soon(output.awaitLine((line) => line.contains('"id":1')));
      server.rejectSession = true;
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

    test('forwards a cancellation while the call is still pending', () async {
      server.holdToolCall = Completer<void>();
      final (stdin, running) = startProxy();

      stdin
        ..write(_initialize)
        ..write(_toolsCall);
      await _soon(server.awaitRequests(_isToolCall));
      stdin.write(_cancelled);
      await _soon(server.awaitRequests(_isCancellation));

      expect(server.toolResultWritten, isFalse);
      server.holdToolCall!.complete();
      await stdin.close();

      expect(await _soon(running), 0);
      final lines = await output.lines();
      expect(lines.map((line) => _decode(line)['id']), [1, null, 4]);
    });

    test('answers a ping while the call is still pending', () async {
      server.holdToolCall = Completer<void>();
      final (stdin, running) = startProxy();

      stdin
        ..write(_initialize)
        ..write(_toolsCall);
      await _soon(server.awaitRequests(_isToolCall));
      stdin.write(_ping);

      final pong = await _soon(
        output.awaitLine((line) => line.contains('"id":6')),
      );
      expect(_decode(pong)['result'], isNotNull);
      expect(server.toolResultWritten, isFalse);

      server.holdToolCall!.complete();
      await stdin.close();
      expect(await _soon(running), 0);
    });

    test('a stream that ends without a result answers the id once', () async {
      server.truncateToolStream = true;

      expect(await _soon(runProxy([_initialize, _toolsCall])), 0);

      final lines = await output.lines();
      expect(lines, hasLength(3));
      final failure = _decode(lines.last);
      expect(failure['id'], 4);
      final error = failure['error']! as Map<String, Object?>;
      expect(error['code'], -32000);
      expect(error['message'], contains('does not retry it'));
      expect(server.toolExecutions, 1);
      expect(server.requests.where(_isToolCall), hasLength(1));
    });

    test('a malformed server-sent event fails only that request', () async {
      server.malformedToolEvent = true;

      expect(await _soon(runProxy([_initialize, _toolsCall, _toolsList])), 0);

      final answers = await answersById();
      expect(answers[4]!['error'], isNotNull);
      expect(answers[3]!['result'], isNotNull);
      expect(await diagnostics.text(), contains('malformed server-sent event'));
      expect(server.requests.where(_isToolCall), hasLength(1));
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

    test(
      'a request queued with initialize waits for the new session',
      () async {
        final (stdin, running) = startProxy();

        stdin
          ..write(_initialize)
          ..write(_toolsList);
        await stdin.close();

        expect(await _soon(running), 0);
        expect(server.requests[0].body, contains('"method":"initialize"'));
        expect(server.requests[1].body, contains('"method":"tools/list"'));
        expect(server.requests[1].sessionId, 'session-1');
        expect(server.requests[1].protocolVersion, '2025-11-25');
      },
    );

    test('concurrent session rejections share one handshake', () async {
      final (stdin, running) = startProxy();
      stdin.write(_initialize);
      await _soon(output.awaitLine((line) => line.contains('"id":1')));

      server
        ..holdSessionRejection = Completer<void>()
        ..rejectSession = true;
      stdin
        ..write(_toolsList)
        ..write(_toolsListAlt);
      await _soon(server.awaitRequests(_isToolsList, count: 2));
      server.holdSessionRejection!.complete();
      await stdin.close();

      expect(await _soon(running), 0);
      final handshakes = server.requests.where(_isHandshake).toList();
      expect(handshakes, hasLength(2));
      expect(handshakes.last.sessionId, isNull);
      expect(handshakes.last.protocolVersion, isNull);
      expect(
        server.requests.where(
          (request) => request.body.contains('notifications/initialized'),
        ),
        hasLength(1),
      );
      final calls = server.requests.where(_isToolsList).toList();
      expect(calls, hasLength(4));
      expect(calls.skip(2).map((request) => request.sessionId), [
        'session-2',
        'session-2',
      ]);
      final answers = await answersById();
      expect(answers[3]!['result'], isNotNull);
      expect(answers[5]!['result'], isNotNull);
      expect(server.deleted, isTrue);
    });

    test('claims the new session when the client re-initializes', () async {
      expect(await runProxy([_initialize, _initialize, _toolsList]), 0);
      expect(server.requests[1].body, contains('initialize'));
      expect(server.requests[1].sessionId, isNull);
      expect(server.requests[1].protocolVersion, isNull);
      expect(server.requests[2].sessionId, 'session-2');
      expect(server.requests[2].protocolVersion, '2025-11-25');
      expect(server.requests.last.method, 'DELETE');
      expect(server.requests.last.sessionId, 'session-2');
    });

    for (final sse in [false, true]) {
      test(
        'a rejected submission executes once after ${sse ? 'SSE' : 'JSON'} recovery',
        () async {
          server.initializeUsingSse = sse;
          final (stdin, running) = startProxy();
          await expireSessionAfterHandshake(stdin);
          stdin.write(_toolsCall);
          await stdin.close();

          expect(await _soon(running), 0);
          expect(server.toolExecutions, 1);
          expect(server.requests.where(_isToolCall), hasLength(2));
          final lines = await output.lines();
          expect(lines, hasLength(3));
          expect(_decode(lines.last)['id'], 4);
          expect(_decode(lines.last)['result'], isNotNull);
        },
      );
    }

    test('repeated session rejection is bounded to one recovery', () async {
      server.expireToolRequests = true;
      expect(await runProxy([_initialize, _toolsCall]), 2);
      expect(server.toolExecutions, 0);
      expect(server.requests.where(_isHandshake), hasLength(2));
      expect(server.requests.where(_isToolCall), hasLength(2));
      expect(_decode((await output.lines()).last)['error'], isNotNull);
    });

    test('failed handshake never replays the rejected submission', () async {
      server.failRecovery = true;
      final (stdin, running) = startProxy();
      await expireSessionAfterHandshake(stdin);
      stdin.write(_toolsCall);
      await stdin.close();

      expect(await _soon(running), 2);
      expect(server.toolExecutions, 0);
      expect(server.requests.where(_isToolCall), hasLength(1));
    });

    for (final status in [
      HttpStatus.internalServerError,
      HttpStatus.notFound,
    ]) {
      test(
        'HTTP $status with an unknown outcome never replays a submission',
        () async {
          server.toolFailureStatus = status;
          expect(await runProxy([_initialize, _toolsCall]), 0);
          expect(server.toolExecutions, 1);
          expect(server.requests.where(_isToolCall), hasLength(1));
          expect(server.requests.where(_isHandshake), hasLength(1));
          expect(_decode((await output.lines()).last)['error'], isNotNull);
        },
      );
    }

    test('waits for a pending call before closing the session', () async {
      server.holdToolCall = Completer<void>();
      final (stdin, running) = startProxy();

      stdin
        ..write(_initialize)
        ..write(_toolsCall);
      await _soon(server.awaitRequests(_isToolCall));
      await stdin.close();
      await pumpEventQueue();
      expect(server.deleted, isFalse);

      server.holdToolCall!.complete();
      expect(await _soon(running), 0);
      final lines = await output.lines();
      expect(_decode(lines.last)['id'], 4);
      expect(_decode(lines.last)['result'], isNotNull);
      expect(server.requests.last.method, 'DELETE');
      expect(server.deleted, isTrue);
    });

    test('ignores a line that is not a JSON-RPC object', () async {
      final exitCode = await runProxy(['not json', '[1,2,3]', _initialize]);

      expect(exitCode, 0);
      expect(await output.lines(), hasLength(1));
      expect(await diagnostics.text(), contains('malformed JSON-RPC line'));
    });

    test('exits 2 when the endpoint refuses the connection', () async {
      final refusing = await RefusingLoopbackPort.reserve();
      addTearDown(refusing.release);
      final proxy = McpStdioProxy(
        endpoint: Uri.parse('http://127.0.0.1:${refusing.port}/mcp'),
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
const String _toolsListAlt = '{"jsonrpc":"2.0","id":5,"method":"tools/list"}';
const String _ping = '{"jsonrpc":"2.0","id":6,"method":"ping"}';
const String _cancelled =
    '{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":4}}';
const String _toolsCall =
    '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"submit_generation","arguments":{"preparation_id":"prep-1","confirmed":true}}}';

bool _isHandshake(_RecordedRequest request) =>
    request.body.contains('"method":"initialize"');
bool _isToolCall(_RecordedRequest request) =>
    request.body.contains('"method":"tools/call"');
bool _isToolsList(_RecordedRequest request) =>
    request.body.contains('"method":"tools/list"');
bool _isCancellation(_RecordedRequest request) =>
    request.body.contains('"method":"notifications/cancelled"');

Map<String, Object?> _decode(String line) =>
    jsonDecode(line) as Map<String, Object?>;

/// Fails a regression fast instead of letting it eat the whole test budget.
Future<T> _soon<T>(Future<T> future) =>
    future.timeout(const Duration(seconds: 10));

/// Stdin the test writes to line by line, so lines can arrive while an earlier
/// response is still open.
class _StdinPipe {
  final StreamController<List<int>> _controller = StreamController<List<int>>();

  Stream<List<int>> get stream => _controller.stream;

  void write(String line) => _controller.add(utf8.encode('$line\n'));

  Future<void> close() =>
      _controller.isClosed ? Future<void>.value() : _controller.close();
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
  final List<void Function()> _watchers = <void Function()>[];
  bool rejectSession = false;
  bool expireToolRequests = false;
  bool initializeUsingSse = false;
  bool failRecovery = false;
  bool truncateToolStream = false;
  bool malformedToolEvent = false;
  bool toolResultWritten = false;
  Completer<void>? holdToolCall;
  Completer<void>? holdSessionRejection;
  int? toolFailureStatus;
  int toolExecutions = 0;
  bool deleted = false;
  int _sessions = 0;

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}/mcp');

  Future<void> close() => _server.close(force: true);

  /// Completes once [count] recorded requests match, before their responses
  /// are written, so a test can assert on what has not happened yet.
  Future<void> awaitRequests(
    bool Function(_RecordedRequest request) matches, {
    int count = 1,
  }) {
    final completer = Completer<void>();
    void check() {
      if (!completer.isCompleted && requests.where(matches).length >= count) {
        completer.complete();
      }
    }

    _watchers.add(check);
    check();
    return completer.future.whenComplete(() => _watchers.remove(check));
  }

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
    for (final watcher in [..._watchers]) {
      watcher();
    }
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
    if (message['method'] != 'initialize' &&
        (rejectSession ||
            (expireToolRequests && message['method'] == 'tools/call') ||
            request.headers.value('Mcp-Session-Id') != 'session-$_sessions')) {
      await holdSessionRejection?.future;
      response.statusCode = HttpStatus.notFound;
      await _writeJson(response, {
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32001, 'message': 'Session not found'},
      });
      return;
    }
    switch (message['method']) {
      case 'initialize':
        if (failRecovery && _sessions > 0) {
          response.statusCode = HttpStatus.serviceUnavailable;
          await response.close();
          return;
        }
        rejectSession = false;
        response.headers.set('Mcp-Session-Id', 'session-${++_sessions}');
        final initialized = <String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': {
            'protocolVersion': '2025-11-25',
            'capabilities': <String, Object?>{},
            'serverInfo': {'name': 'nai-launcher', 'version': '0.0.0'},
          },
        };
        if (initializeUsingSse) {
          await _writeEventStream(response, [initialized]);
        } else {
          await _writeJson(response, initialized);
        }
      case 'tools/call':
        toolExecutions++;
        if (toolFailureStatus case final status?) {
          response.statusCode = status;
          response.write('Unknown execution outcome');
          await response.close();
          return;
        }
        await _writeToolCall(response, id);
      default:
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

  Future<void> _writeToolCall(HttpResponse response, Object? id) async {
    _startEventStream(response);
    _writeEvent(response, {
      'jsonrpc': '2.0',
      'method': 'notifications/progress',
      'params': {'progress': 1, 'total': 2},
    });
    await response.flush();
    await holdToolCall?.future;
    if (malformedToolEvent) {
      response.write('event: message\ndata: {"jsonrpc":\n\n');
      await response.close();
      return;
    }
    if (!truncateToolStream) {
      toolResultWritten = true;
      _writeEvent(response, {
        'jsonrpc': '2.0',
        'id': id,
        'result': {'isError': false, 'content': <Object?>[]},
      });
    }
    await response.close();
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
    _startEventStream(response);
    for (final message in messages) {
      _writeEvent(response, message);
    }
    await response.close();
  }

  void _startEventStream(HttpResponse response) {
    response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
    response.write(': keep-alive\n\n');
  }

  void _writeEvent(HttpResponse response, Map<String, Object?> message) =>
      response.write('event: message\ndata: ${jsonEncode(message)}\n\n');
}

/// Collects everything written to an [IOSink] without touching the process.
class _MemorySink {
  _MemorySink() {
    _controller = StreamController<List<int>>();
    _subscription = _controller.stream.listen((chunk) {
      _chunks.add(chunk);
      for (final watcher in [..._watchers]) {
        watcher();
      }
    });
    sink = IOSink(_controller.sink);
  }

  late final StreamController<List<int>> _controller;
  late final StreamSubscription<List<int>> _subscription;
  late final IOSink sink;
  final List<List<int>> _chunks = <List<int>>[];
  final List<void Function()> _watchers = <void Function()>[];

  Future<String> text() async {
    await sink.flush();
    await Future<void>.delayed(Duration.zero);
    return _collected;
  }

  Future<List<String>> lines() async {
    final collected = await text();
    if (collected.isEmpty) {
      return const <String>[];
    }
    return const LineSplitter().convert(collected);
  }

  /// Completes as soon as a matching line is written, so a test can observe
  /// stdout while another response is still open.
  Future<String> awaitLine(bool Function(String line) matches) {
    final completer = Completer<String>();
    void check() {
      if (completer.isCompleted) {
        return;
      }
      for (final line in const LineSplitter().convert(_collected)) {
        if (matches(line)) {
          completer.complete(line);
          return;
        }
      }
    }

    _watchers.add(check);
    check();
    return completer.future.whenComplete(() => _watchers.remove(check));
  }

  String get _collected =>
      utf8.decode(_chunks.expand((chunk) => chunk).toList());

  Future<void> dispose() async {
    await sink.close();
    await _subscription.cancel();
  }
}
