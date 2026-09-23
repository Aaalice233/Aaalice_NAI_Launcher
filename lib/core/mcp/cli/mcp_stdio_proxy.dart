import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import '../mcp_server_constants.dart';
import 'mcp_sse_line_decoder.dart';

/// Bridges a newline-delimited JSON-RPC stdio client to the launcher's
/// loopback Streamable HTTP endpoint: one POST per incoming message, every
/// server message written back as one stdout line. Requests are forwarded
/// concurrently so a pending call never delays a cancellation.
class McpStdioProxy {
  McpStdioProxy({
    required Uri endpoint,
    required String token,
    required Stream<List<int>> input,
    required IOSink output,
    required IOSink diagnostics,
    HttpClient? client,
    bool verbose = false,
  }) : _endpoint = endpoint,
       _token = token,
       _input = input,
       _output = output,
       _diagnostics = diagnostics,
       _client = client ?? HttpClient(),
       _ownsClient = client == null,
       _verbose = verbose;

  /// Exit code used when the launcher is gone, so the client stops reusing a
  /// proxy that would otherwise keep the executable locked during updates.
  static const int launcherUnavailableExitCode = 2;

  static const String _acceptedContentTypes =
      'application/json, text/event-stream';
  static const int _errorDetailLimit = 200;

  /// Bounds in-flight POSTs so a flooding client cannot open an unbounded
  /// number of sockets; later requests wait in arrival order.
  static const int _maxConcurrentRequests = 8;

  static const String _alreadySubmitted =
      'The request was already submitted and its outcome is unknown, so the '
      'proxy does not retry it.';

  final Uri _endpoint;
  final String _token;
  final Stream<List<int>> _input;
  final IOSink _output;
  final IOSink _diagnostics;
  final HttpClient _client;
  final bool _ownsClient;
  final bool _verbose;

  final Queue<_Outgoing> _requests = Queue<_Outgoing>();
  final Queue<_Outgoing> _oneWay = Queue<_Outgoing>();
  final Set<Future<void>> _inFlight = <Future<void>>{};

  String? _sessionId;
  String? _protocolVersion;
  Object? _initializeRequestId;
  bool _awaitingInitializeResult = false;
  Map<String, Object?>? _initializeMessage;
  int _recoverySequence = 0;
  int _sessionGeneration = 0;
  int _concurrentRequests = 0;
  Completer<void>? _gate;
  Future<bool>? _recovery;
  StreamSubscription<String>? _stdin;
  Completer<void>? _stdinClosed;
  int? _fatalExitCode;

  Future<int> run() async {
    try {
      await _readStdin();
      await _drain();
      if (_fatalExitCode == null) {
        await _deleteSession();
      }
      await _output.flush();
      return _fatalExitCode ?? 0;
    } finally {
      if (_ownsClient) {
        _client.close(force: true);
      }
    }
  }

  Future<void> _readStdin() {
    final closed = Completer<void>();
    _stdinClosed = closed;
    _stdin = _input
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _accept,
          onDone: _stopReading,
          onError: (Object error) {
            _warn('Cannot read the JSON-RPC stream from stdin: $error');
            _stopReading();
          },
          cancelOnError: true,
        );
    return closed.future;
  }

  void _stopReading() {
    final closed = _stdinClosed;
    if (closed == null || closed.isCompleted) {
      return;
    }
    closed.complete();
    unawaited(_stdin?.cancel());
  }

  /// Runs on the stdin subscription, so it may only queue work: awaiting a
  /// POST here is what used to make cancellations arrive after the result.
  void _accept(String line) {
    if (_fatalExitCode != null || line.trim().isEmpty) {
      return;
    }
    final message = _decode(line);
    if (message == null) {
      return;
    }
    final outgoing = _Outgoing(line, message);
    (outgoing.expectsResponse || outgoing.isHandshake ? _requests : _oneWay)
        .add(outgoing);
    _pump();
  }

  void _pump() {
    while (_fatalExitCode == null && _gate == null) {
      if (_oneWay.isNotEmpty) {
        _begin(_oneWay.removeFirst());
        continue;
      }
      if (_requests.isEmpty) {
        return;
      }
      if (_requests.first.isHandshake) {
        // The session id and protocol version it negotiates belong to every
        // later message, so nothing may overlap it.
        if (_inFlight.isNotEmpty) {
          return;
        }
        _closeGate();
        _begin(_requests.removeFirst());
        continue;
      }
      if (_concurrentRequests >= _maxConcurrentRequests) {
        return;
      }
      _concurrentRequests++;
      _begin(_requests.removeFirst());
    }
  }

  void _begin(_Outgoing outgoing) {
    late final Future<void> entry;
    entry = _forward(outgoing)
        .catchError((Object error) {
          _settle(outgoing, 'NAI Launcher MCP proxy failed to forward: $error');
        })
        .whenComplete(() {
          _inFlight.remove(entry);
          if (outgoing.isHandshake) {
            _openGate();
          } else if (outgoing.expectsResponse) {
            _concurrentRequests--;
          }
          _pump();
        });
    _inFlight.add(entry);
  }

  void _closeGate() => _gate ??= Completer<void>();

  void _openGate() {
    final gate = _gate;
    _gate = null;
    gate?.complete();
  }

  void _stop(int exitCode) {
    _fatalExitCode ??= exitCode;
    _stopReading();
  }

  Future<void> _drain() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(_inFlight.toList());
    }
    final abandoned = [..._requests, ..._oneWay];
    _requests.clear();
    _oneWay.clear();
    for (final outgoing in abandoned.where((o) => o.expectsResponse)) {
      _settle(
        outgoing,
        'NAI Launcher MCP proxy stopped before sending this '
        'request, which therefore never reached the launcher.',
      );
    }
  }

  Future<void> _forward(
    _Outgoing outgoing, {
    bool canRecoverSession = true,
  }) async {
    if (outgoing.isHandshake) {
      _startHandshake(outgoing.message);
    }
    final generation = _sessionGeneration;
    final HttpClientResponse response;
    try {
      _log('-> ${_describe(outgoing.message)}');
      response = await _post(outgoing.line);
    } on SocketException catch (error) {
      _warn(
        'Cannot reach the NAI Launcher MCP endpoint at $_endpoint: '
        '${error.message}',
      );
      _stop(launcherUnavailableExitCode);
      return;
    } on Exception catch (error) {
      _settle(outgoing, 'NAI Launcher MCP request failed: $error');
      return;
    }
    if (outgoing.isHandshake) {
      _captureSession(response);
    }
    try {
      await _receive(
        response,
        outgoing,
        generation,
        canRecoverSession: canRecoverSession,
      );
    } on Exception catch (error) {
      _settle(
        outgoing,
        'NAI Launcher MCP stream failed: $error $_alreadySubmitted',
      );
      return;
    }
    if (outgoing.expectsResponse && !outgoing.answered) {
      _settle(
        outgoing,
        'NAI Launcher MCP closed the stream before answering. '
        '$_alreadySubmitted',
      );
    }
  }

  Future<void> _receive(
    HttpClientResponse response,
    _Outgoing outgoing,
    int generation, {
    required bool canRecoverSession,
  }) async {
    final status = response.statusCode;
    _log('<- HTTP $status');
    if (status == HttpStatus.accepted) {
      await response.drain<void>();
      return;
    }
    if (status != HttpStatus.ok) {
      return _receiveFailure(
        response,
        outgoing,
        generation,
        canRecoverSession: canRecoverSession,
      );
    }
    if (response.headers.contentType?.mimeType == 'text/event-stream') {
      return _pumpEventStream(response, outgoing);
    }
    _emitEncoded(await _readBody(response), outgoing);
  }

  Future<void> _receiveFailure(
    HttpClientResponse response,
    _Outgoing outgoing,
    int generation, {
    required bool canRecoverSession,
  }) async {
    final status = response.statusCode;
    final body = await _readBody(response);
    final expiredSession =
        !outgoing.isHandshake &&
        generation > 0 &&
        status == HttpStatus.notFound &&
        _isSessionNotFound(body, outgoing.message['id']);
    if (status == HttpStatus.notFound) {
      _invalidateSession(generation);
    }
    // Only this transport rejection guarantees the tool never executed.
    // Timeouts, dropped streams and other errors must never replay a charge.
    if (expiredSession &&
        canRecoverSession &&
        await _recoverSession(generation)) {
      return _forward(outgoing, canRecoverSession: false);
    }
    final detail = _truncate(body);
    _settle(
      outgoing,
      'NAI Launcher MCP endpoint returned HTTP $status'
      '${detail.isEmpty ? '' : ': $detail'}',
    );
    if (expiredSession) {
      _stop(launcherUnavailableExitCode);
    }
  }

  Future<HttpClientResponse> _post(String line) async {
    final request = await _client.postUrl(_endpoint);
    _applyHeaders(request.headers);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, _acceptedContentTypes);
    final payload = utf8.encode(line);
    request.contentLength = payload.length;
    request.add(payload);
    return request.close();
  }

  void _startHandshake(Map<String, Object?> message) {
    _initializeMessage = message;
    _initializeRequestId = message['id'];
    _awaitingInitializeResult = true;
    _sessionId = null;
    _protocolVersion = null;
  }

  void _captureSession(HttpClientResponse response) {
    final sessionId = response.headers.value(McpServerDefaults.sessionIdHeader);
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
      _sessionGeneration++;
    }
  }

  void _invalidateSession(int generation) {
    if (_sessionGeneration != generation) {
      return;
    }
    _sessionId = null;
    _protocolVersion = null;
  }

  static bool _isSessionNotFound(String body, Object? id) {
    try {
      final message = jsonDecode(body);
      return message is Map &&
          message['id'] == id &&
          message['error'] is Map &&
          message['error']['code'] == -32001 &&
          message['error']['message'] == 'Session not found';
    } on FormatException {
      return false;
    }
  }

  /// Concurrent rejections share one handshake: replaying it per request would
  /// leave every caller but the last holding a session the launcher dropped.
  Future<bool> _recoverSession(int staleGeneration) {
    if (_sessionGeneration != staleGeneration) {
      return Future<bool>.value(_sessionId != null);
    }
    final running = _recovery;
    if (running != null) {
      return running;
    }
    _closeGate();
    final started = _handshakeAgain().whenComplete(() {
      _recovery = null;
      _openGate();
      _pump();
    });
    return _recovery = started;
  }

  Future<bool> _handshakeAgain() async {
    final initialize = _initializeMessage;
    if (initialize == null) return false;
    final id = 'proxy-reinitialize-${++_recoverySequence}';
    try {
      _log('Recovering expired HTTP session');
      final response = await _post(jsonEncode({...initialize, 'id': id}));
      final session = response.headers.value(McpServerDefaults.sessionIdHeader);
      if (response.statusCode != HttpStatus.ok ||
          session == null ||
          session.isEmpty) {
        await response.drain<void>();
        return false;
      }
      final result = await _readInitializeResult(response, id);
      if (result?['protocolVersion'] case final String version) {
        _sessionId = session;
        _protocolVersion = version;
      } else {
        return false;
      }
      final ready = await _post(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      await ready.drain<void>();
      if (ready.statusCode == HttpStatus.accepted) {
        _sessionGeneration++;
        return true;
      }
    } on Exception catch (error) {
      _warn('MCP session recovery failed: ${error.runtimeType}');
    }
    _sessionId = null;
    _protocolVersion = null;
    return false;
  }

  Future<Map<String, Object?>?> _readInitializeResult(
    HttpClientResponse response,
    String id,
  ) async {
    final body = await _readBody(response);
    final List<Object?> messages;
    if (response.headers.contentType?.mimeType == 'text/event-stream') {
      final decoder = McpSseLineDecoder();
      messages = [...decoder.addChunk(body), ...decoder.flush()];
    } else {
      messages = [jsonDecode(body)];
    }
    for (final message in messages) {
      if (message is Map && message['id'] == id && message['result'] is Map) {
        return Map<String, Object?>.from(message['result'] as Map);
      }
    }
    return null;
  }

  Future<void> _pumpEventStream(
    HttpClientResponse response,
    _Outgoing outgoing,
  ) async {
    final decoder = McpSseLineDecoder();
    try {
      await for (final chunk in response.transform(utf8.decoder)) {
        for (final message in decoder.addChunk(chunk)) {
          _emit(message, outgoing);
        }
      }
      for (final message in decoder.flush()) {
        _emit(message, outgoing);
      }
    } on FormatException catch (error) {
      _settle(
        outgoing,
        'NAI Launcher MCP sent a malformed server-sent event: '
        '${error.message}. $_alreadySubmitted',
      );
    }
  }

  void _emitEncoded(String body, _Outgoing outgoing) {
    if (body.trim().isEmpty) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      _settle(
        outgoing,
        'NAI Launcher MCP sent a malformed JSON response: ${error.message}. '
        '$_alreadySubmitted',
      );
      return;
    }
    if (decoded is! Map<String, Object?>) {
      _settle(
        outgoing,
        'NAI Launcher MCP sent a JSON response that is not an object. '
        '$_alreadySubmitted',
      );
      return;
    }
    _emit(decoded, outgoing);
  }

  void _emit(Map<String, Object?> message, _Outgoing outgoing) {
    _captureNegotiatedVersion(message);
    if (outgoing.expectsResponse &&
        message['id'] == outgoing.message['id'] &&
        (message.containsKey('result') || message.containsKey('error'))) {
      outgoing.answered = true;
    }
    _output.writeln(jsonEncode(message));
  }

  void _captureNegotiatedVersion(Map<String, Object?> message) {
    if (!_awaitingInitializeResult || message['id'] != _initializeRequestId) {
      return;
    }
    final result = message['result'];
    if (result is! Map) {
      return;
    }
    final version = result['protocolVersion'];
    if (version is String && version.isNotEmpty) {
      _protocolVersion = version;
      _awaitingInitializeResult = false;
    }
  }

  /// Every forwarded request leaves exactly one answer on stdout, so a client
  /// never waits on an id the launcher stopped talking about.
  void _settle(_Outgoing outgoing, String description) {
    _warn(description);
    if (!outgoing.expectsResponse || outgoing.answered) {
      return;
    }
    outgoing.answered = true;
    _output.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': outgoing.message['id'],
        'error': {'code': -32000, 'message': description},
      }),
    );
  }

  Map<String, Object?>? _decode(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException catch (error) {
      _warn('Ignoring malformed JSON-RPC line from stdin: ${error.message}');
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      _warn('Ignoring JSON-RPC line that is not an object.');
      return null;
    }
    return decoded;
  }

  Future<void> _deleteSession() async {
    if (_sessionId == null) {
      return;
    }
    try {
      final request = await _client.deleteUrl(_endpoint);
      _applyHeaders(request.headers);
      final response = await request.close();
      await response.drain<void>();
    } on Exception catch (error) {
      _log('Session teardown failed: $error');
    }
  }

  void _applyHeaders(HttpHeaders headers) {
    headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    final sessionId = _sessionId;
    if (sessionId != null) {
      headers.set(McpServerDefaults.sessionIdHeader, sessionId);
    }
    final protocolVersion = _protocolVersion;
    if (protocolVersion != null) {
      headers.set(McpServerDefaults.protocolVersionHeader, protocolVersion);
    }
  }

  Future<String> _readBody(HttpClientResponse response) =>
      response.transform(utf8.decoder).join();

  String _truncate(String body) {
    final trimmed = body.trim();
    if (trimmed.length <= _errorDetailLimit) {
      return trimmed;
    }
    return '${trimmed.substring(0, _errorDetailLimit)}...';
  }

  String _describe(Map<String, Object?> message) {
    final method = message['method'];
    if (method is String) {
      return method;
    }
    return 'response id=${message['id']}';
  }

  void _log(String message) {
    if (_verbose) {
      _diagnostics.writeln('[nai-launcher-mcp] $message');
    }
  }

  void _warn(String message) {
    _diagnostics.writeln('[nai-launcher-mcp] $message');
  }
}

/// One JSON-RPC line read from stdin, carried through a replay so the client
/// still sees a single answer for its id.
class _Outgoing {
  _Outgoing(this.line, this.message);

  final String line;
  final Map<String, Object?> message;
  bool answered = false;

  bool get isHandshake => message['method'] == 'initialize';

  /// Notifications carry no id and the client's own responses carry no method;
  /// neither gets an answer written back.
  bool get expectsResponse =>
      message.containsKey('method') && message['id'] != null;
}
