import 'dart:convert';
import 'dart:io';

import '../mcp_server_constants.dart';
import 'mcp_sse_line_decoder.dart';

/// Bridges a newline-delimited JSON-RPC stdio client to the launcher's
/// loopback Streamable HTTP endpoint: one POST per incoming message, every
/// server message written back as one stdout line.
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

  final Uri _endpoint;
  final String _token;
  final Stream<List<int>> _input;
  final IOSink _output;
  final IOSink _diagnostics;
  final HttpClient _client;
  final bool _ownsClient;
  final bool _verbose;

  String? _sessionId;
  String? _protocolVersion;
  Object? _initializeRequestId;
  bool _awaitingInitializeResult = false;
  Map<String, Object?>? _initializeMessage;
  int _recoverySequence = 0;

  Future<int> run() async {
    try {
      final lines = _input
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        if (line.trim().isEmpty) {
          continue;
        }
        final earlyExit = await _forward(line);
        if (earlyExit != null) {
          await _output.flush();
          return earlyExit;
        }
      }
      await _deleteSession();
      await _output.flush();
      return 0;
    } finally {
      if (_ownsClient) {
        _client.close(force: true);
      }
    }
  }

  /// Returns a process exit code when the proxy must stop, `null` to continue.
  Future<int?> _forward(String line, {bool canRecoverSession = true}) async {
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
    final message = decoded;
    final id = message['id'];
    final isInitialize = message['method'] == 'initialize';
    if (isInitialize) {
      _initializeMessage = message;
      _initializeRequestId = id;
      _awaitingInitializeResult = true;
      _sessionId = null;
      _protocolVersion = null;
    }

    final HttpClientResponse response;
    try {
      _log('-> ${_describe(message)}');
      response = await _post(line);
    } on SocketException catch (error) {
      _warn(
        'Cannot reach the NAI Launcher MCP endpoint at $_endpoint: '
        '${error.message}',
      );
      return launcherUnavailableExitCode;
    } on Exception catch (error) {
      _reportFailure(id, 'NAI Launcher MCP request failed: $error');
      return null;
    }

    if (isInitialize) {
      final sessionId = response.headers.value(
        McpServerDefaults.sessionIdHeader,
      );
      if (sessionId != null && sessionId.isNotEmpty) {
        _sessionId = sessionId;
      }
    }

    final status = response.statusCode;
    _log('<- HTTP $status');
    if (status == HttpStatus.accepted) {
      await response.drain<void>();
      return null;
    }
    if (status != HttpStatus.ok) {
      final body = await _readBody(response);
      final expiredSession =
          !isInitialize &&
          _sessionId != null &&
          status == HttpStatus.notFound &&
          _isSessionNotFound(body, id);
      if (status == HttpStatus.notFound) {
        _sessionId = null;
        _protocolVersion = null;
      }
      // Only this transport rejection guarantees the tool never executed.
      // Timeouts, dropped streams and other errors must never replay a charge.
      if (expiredSession && canRecoverSession && await _recoverSession()) {
        return _forward(line, canRecoverSession: false);
      }
      final detail = _truncate(body);
      _reportFailure(
        id,
        'NAI Launcher MCP endpoint returned HTTP $status'
        '${detail.isEmpty ? '' : ': $detail'}',
      );
      return expiredSession ? launcherUnavailableExitCode : null;
    }

    if (response.headers.contentType?.mimeType == 'text/event-stream') {
      await _pumpEventStream(response);
      return null;
    }
    _emitEncoded(await _readBody(response));
    return null;
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

  Future<bool> _recoverSession() async {
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
      if (ready.statusCode == HttpStatus.accepted) return true;
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

  Future<void> _pumpEventStream(HttpClientResponse response) async {
    final decoder = McpSseLineDecoder();
    try {
      await for (final chunk in response.transform(utf8.decoder)) {
        for (final message in decoder.addChunk(chunk)) {
          _emit(message);
        }
      }
      for (final message in decoder.flush()) {
        _emit(message);
      }
    } on FormatException catch (error) {
      _warn('Dropping malformed server-sent event: ${error.message}');
    }
  }

  void _emitEncoded(String body) {
    if (body.trim().isEmpty) {
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (error) {
      _warn('Dropping malformed JSON response: ${error.message}');
      return;
    }
    if (decoded is! Map<String, Object?>) {
      _warn('Dropping JSON response that is not an object.');
      return;
    }
    _emit(decoded);
  }

  void _emit(Map<String, Object?> message) {
    _captureNegotiatedVersion(message);
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

  void _reportFailure(Object? id, String description) {
    _warn(description);
    if (id == null) {
      return;
    }
    _output.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'error': {'code': -32000, 'message': description},
      }),
    );
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
