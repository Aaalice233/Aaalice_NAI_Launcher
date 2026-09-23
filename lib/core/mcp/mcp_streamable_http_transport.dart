import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_mcp/server.dart' as mcp;

import '../utils/portable_logger.dart';
import 'mcp_bearer_authenticator.dart';
import 'mcp_origin_policy.dart';
import 'mcp_server_constants.dart';
import 'mcp_session_registry.dart';

const String _logTag = 'McpServer';

/// Streamable HTTP (spec 2025-11-25) in front of [McpSessionRegistry].
///
/// Replace this file with `dart_mcp`'s own `handleStreamableHttpRequest` once
/// 0.6.0 ships it.
class McpStreamableHttpTransport {
  McpStreamableHttpTransport({
    required this.sessions,
    required this.authenticator,
    this.endpointPath = McpServerDefaults.endpointPath,
    this.maxBodyBytes = McpServerDefaults.maxBodyBytes,
    this.keepAliveInterval = McpServerDefaults.keepAliveInterval,
  });

  static const String _allowedMethods = 'POST, DELETE';
  static const String _jsonRpcVersion = '2.0';
  static const int _parseErrorCode = -32700;
  static const int _invalidRequestCode = -32600;
  static const int _sessionNotFoundCode = -32001;
  static const int _sessionClosedCode = -32002;
  static const int _sessionsBusyCode = -32003;
  static const Set<String> _loopbackHosts = {
    '127.0.0.1',
    'localhost',
    '::1',
    '[::1]',
  };

  final McpSessionRegistry sessions;
  final McpBearerAuthenticator authenticator;
  final String endpointPath;
  final int maxBodyBytes;
  final Duration keepAliveInterval;

  final Set<_McpEventStream> _eventStreams = <_McpEventStream>{};

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    if (request.uri.path != endpointPath) {
      return _writeStatus(response, HttpStatus.notFound, 'Unknown endpoint');
    }
    if (!McpOriginPolicy.allows(request.headers.value('origin'))) {
      PortableLogger.w('Rejected non-loopback Origin', _logTag);
      return _writeStatus(response, HttpStatus.forbidden, 'Origin not allowed');
    }
    if (!_hasLoopbackHost(request.headers)) {
      PortableLogger.w('Rejected non-loopback Host header', _logTag);
      return _writeStatus(response, HttpStatus.forbidden, 'Host not allowed');
    }
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (!authenticator.authorize(authorization)) {
      response.headers.set(HttpHeaders.wwwAuthenticateHeader, 'Bearer');
      return _writeStatus(
        response,
        HttpStatus.unauthorized,
        'Missing or invalid bearer token',
      );
    }
    switch (request.method) {
      case 'POST':
        return _handlePost(request);
      case 'DELETE':
        return _handleDelete(request);
      default:
        response.headers.set(HttpHeaders.allowHeader, _allowedMethods);
        return _writeStatus(
          response,
          HttpStatus.methodNotAllowed,
          '${request.method} is not supported on this endpoint',
        );
    }
  }

  /// Drops any event stream still open, since detached sockets are no longer
  /// owned by the [HttpServer] that accepted them.
  Future<void> shutdown() async {
    final streams = _eventStreams.toList(growable: false);
    _eventStreams.clear();
    for (final stream in streams) {
      stream.detach();
    }
  }

  Future<void> _handleDelete(HttpRequest request) async {
    final id = request.headers.value(McpServerDefaults.sessionIdHeader);
    final session = id == null ? null : sessions.find(id);
    if (session == null) {
      return _writeStatus(
        request.response,
        HttpStatus.notFound,
        'Session not found',
      );
    }
    await sessions.close(session.id);
    return _writeStatus(request.response, HttpStatus.ok, null);
  }

  Future<void> _handlePost(HttpRequest request) async {
    final response = request.response;
    final mimeType = request.headers.contentType?.mimeType.toLowerCase();
    if (mimeType != 'application/json') {
      return _writeStatus(
        response,
        HttpStatus.unsupportedMediaType,
        'Content-Type must be application/json',
      );
    }
    final protocolVersion = request.headers.value(
      McpServerDefaults.protocolVersionHeader,
    );
    if (protocolVersion != null &&
        mcp.ProtocolVersion.tryParse(protocolVersion.trim()) == null) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.badRequest,
        code: _invalidRequestCode,
        message: 'Unsupported ${McpServerDefaults.protocolVersionHeader}',
      );
    }

    final body = await _readBody(request);
    if (body == null) {
      response.persistentConnection = false;
      return _writeStatus(
        response,
        HttpStatus.requestEntityTooLarge,
        'Request body exceeds $maxBodyBytes bytes',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.badRequest,
        code: _parseErrorCode,
        message: 'Request body is not valid JSON',
      );
    }
    if (decoded is List) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.badRequest,
        code: _invalidRequestCode,
        message: 'JSON-RPC batching was removed in MCP 2025-06-18',
      );
    }
    if (decoded is! Map<String, Object?>) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.badRequest,
        code: _invalidRequestCode,
        message: 'Request body must be a JSON-RPC object',
      );
    }

    final message = decoded;
    final method = message['method'];
    final id = message['id'];
    final isRequest = method is String && id != null;
    final isNotification = method is String && id == null;
    if (!isRequest && !isNotification && !_isResponse(message)) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.badRequest,
        code: _invalidRequestCode,
        message: 'Message is neither a request, a notification nor a response',
      );
    }

    final McpSession? session;
    try {
      session = _resolveSession(request, method: method, isRequest: isRequest);
    } on McpSessionCapacityException catch (error) {
      PortableLogger.w(
        'Refused a new session: all ${error.maxSessions} are busy',
        _logTag,
      );
      return _writeJsonRpcError(
        response,
        status: HttpStatus.serviceUnavailable,
        id: id,
        code: _sessionsBusyCode,
        message: 'Every session is busy running a tool call',
      );
    }
    if (session == null) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.notFound,
        id: id,
        code: _sessionNotFoundCode,
        message: 'Session not found',
      );
    }
    sessions.touch(session);
    response.headers.set(McpServerDefaults.sessionIdHeader, session.id);

    if (isRequest) {
      return _forwardRequest(request, session, message);
    }
    if (method == mcp.CancelledNotification.methodName) {
      _abortCancelledCall(session, message);
    }
    session.send(message);
    return _writeStatus(response, HttpStatus.accepted, null);
  }

  McpSession? _resolveSession(
    HttpRequest request, {
    required Object? method,
    required bool isRequest,
  }) {
    if (isRequest && method == mcp.InitializeRequest.methodName) {
      return sessions.create();
    }
    final id = request.headers.value(McpServerDefaults.sessionIdHeader);
    return id == null ? null : sessions.find(id);
  }

  Future<void> _forwardRequest(
    HttpRequest request,
    McpSession session,
    Map<String, Object?> message,
  ) async {
    final id = message['id'];
    final callId = _callIdFor(session.id, id);
    final isToolCall = message['method'] == mcp.CallToolRequest.methodName;
    if (isToolCall) {
      _injectCallId(message, callId);
      session.signalFor(callId);
    }
    try {
      if (_acceptsEventStream(request)) {
        await _respondWithEventStream(request, session, message, id: id);
      } else {
        await _respondWithJson(request, session, message, id: id);
      }
    } finally {
      if (isToolCall) {
        session.endCall(callId);
      }
    }
  }

  Future<void> _respondWithJson(
    HttpRequest request,
    McpSession session,
    Map<String, Object?> message, {
    required Object? id,
  }) async {
    final completer = Completer<Map<String, Object?>>();
    final subscription = _listenForResponse(session, message, completer, null);
    Map<String, Object?>? result;
    try {
      session.send(message);
      result = await completer.future;
    } on _McpSessionClosedException {
      result = null;
    } finally {
      await subscription.cancel();
    }

    final response = request.response;
    if (result == null) {
      return _writeJsonRpcError(
        response,
        status: HttpStatus.serviceUnavailable,
        id: id,
        code: _sessionClosedCode,
        message: 'Session closed before the response was produced',
      );
    }
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    response.write(jsonEncode(result));
    await response.close();
  }

  Future<void> _respondWithEventStream(
    HttpRequest request,
    McpSession session,
    Map<String, Object?> message, {
    required Object? id,
  }) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    // The raw writes below are not chunk framed, and only a detached socket
    // reports the client hanging up while a tool call is still running.
    response.persistentConnection = false;
    response.headers.chunkedTransferEncoding = false;
    final stream = _McpEventStream(
      await response.detachSocket(),
      keepAliveInterval,
    );
    _eventStreams.add(stream);

    final completer = Completer<Map<String, Object?>>();
    final subscription = _listenForResponse(
      session,
      message,
      completer,
      stream.writeEvent,
    );
    try {
      session.send(message);
      stream.writeEvent(await completer.future);
    } on _McpSessionClosedException {
      stream.writeEvent(
        _errorBody(
          id: id,
          code: _sessionClosedCode,
          message: 'Session closed before the response was produced',
        ),
      );
    } finally {
      await subscription.cancel();
      _eventStreams.remove(stream);
      await stream.close();
    }
  }

  StreamSubscription<Map<String, Object?>> _listenForResponse(
    McpSession session,
    Map<String, Object?> request,
    Completer<Map<String, Object?>> completer,
    void Function(Map<String, Object?> message)? onRelated,
  ) {
    final id = request['id'];
    final progressToken = _progressTokenOf(request);
    return session.outgoing.listen(
      (outgoing) {
        if (_isResponse(outgoing)) {
          // Other ids are answered on the connection that carried them.
          if (outgoing['id'] == id && !completer.isCompleted) {
            completer.complete(outgoing);
          }
          return;
        }
        if (onRelated != null && _relatesTo(outgoing, progressToken)) {
          onRelated(outgoing);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(const _McpSessionClosedException());
        }
      },
    );
  }

  // Without a GET stream only progress for this request's token has a place
  // to go; other server-initiated messages are dropped rather than duplicated.
  bool _relatesTo(Map<String, Object?> message, Object? progressToken) {
    if (progressToken == null ||
        message['method'] != mcp.ProgressNotification.methodName) {
      return false;
    }
    final params = message['params'];
    return params is Map && params['progressToken'] == progressToken;
  }

  Object? _progressTokenOf(Map<String, Object?> request) {
    final params = request['params'];
    if (params is! Map) {
      return null;
    }
    final meta = params['_meta'];
    return meta is Map ? meta['progressToken'] : null;
  }

  void _abortCancelledCall(McpSession session, Map<String, Object?> message) {
    final params = message['params'];
    if (params is! Map) {
      return;
    }
    final requestId = params['requestId'];
    if (requestId == null) {
      return;
    }
    session.abortCall(_callIdFor(session.id, requestId), 'cancelled by client');
  }

  void _injectCallId(Map<String, Object?> message, String callId) {
    final params = message['params'];
    if (params is! Map<String, Object?>) {
      message['params'] = <String, Object?>{
        '_meta': <String, Object?>{McpServerDefaults.callIdMetaKey: callId},
      };
      return;
    }
    final meta = params['_meta'];
    params['_meta'] = <String, Object?>{
      if (meta is Map) ...meta.cast<String, Object?>(),
      McpServerDefaults.callIdMetaKey: callId,
    };
  }

  /// Returns `null` once the body passes [maxBodyBytes]. The socket is still
  /// drained: `HttpServer` refuses to send a response over a request whose
  /// body was abandoned mid-stream, so only the buffer is capped.
  Future<String?> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    var overflow = request.contentLength > maxBodyBytes;
    await for (final chunk in request) {
      if (overflow) {
        continue;
      }
      builder.add(chunk);
      if (builder.length > maxBodyBytes) {
        overflow = true;
        builder.clear();
      }
    }
    if (overflow) {
      return null;
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  bool _hasLoopbackHost(HttpHeaders headers) {
    final host = headers.host;
    if (host == null || host.isEmpty) {
      return true;
    }
    return _loopbackHosts.contains(host.toLowerCase());
  }

  bool _acceptsEventStream(HttpRequest request) {
    final accept = request.headers[HttpHeaders.acceptHeader];
    if (accept == null) {
      return false;
    }
    return accept.join(',').toLowerCase().contains('text/event-stream');
  }

  bool _isResponse(Map<String, Object?> message) =>
      !message.containsKey('method') &&
      (message.containsKey('result') || message.containsKey('error'));

  // `1` and `"1"` are different JSON-RPC ids, so the tag keeps them apart.
  String _callIdFor(String sessionId, Object? requestId) {
    final prefix = sessionId.length <= 8
        ? sessionId
        : sessionId.substring(0, 8);
    final tag = switch (requestId) {
      num() => 'n',
      String() => 's',
      _ => 'o',
    };
    return '$prefix-$tag$requestId';
  }

  Map<String, Object?> _errorBody({
    required Object? id,
    required int code,
    required String message,
  }) => <String, Object?>{
    'jsonrpc': _jsonRpcVersion,
    'id': id,
    'error': <String, Object?>{'code': code, 'message': message},
  };

  Future<void> _writeStatus(
    HttpResponse response,
    int status,
    String? message,
  ) async {
    response.statusCode = status;
    if (message != null) {
      response.headers.contentType = ContentType.text;
      response.write(message);
    }
    await response.close();
  }

  Future<void> _writeJsonRpcError(
    HttpResponse response, {
    required int status,
    required int code,
    required String message,
    Object? id,
  }) async {
    response.statusCode = status;
    response.headers.contentType = ContentType(
      'application',
      'json',
      charset: 'utf-8',
    );
    response.write(
      jsonEncode(_errorBody(id: id, code: code, message: message)),
    );
    await response.close();
  }
}

/// One detached SSE connection. A client hanging up only stops the writes: MCP
/// 2025-11-25 says a dropped stream is not a cancellation, so the tool call it
/// carries runs to completion and its result is discarded.
class _McpEventStream {
  _McpEventStream(this._socket, Duration keepAliveInterval) {
    _subscription = _socket.listen(
      _discardIncoming,
      onDone: detach,
      onError: (Object _) => detach(),
      cancelOnError: false,
    );
    _keepAlive = Timer.periodic(
      keepAliveInterval,
      (_) => _write(': keep-alive\n\n'),
    );
  }

  final Socket _socket;

  late final StreamSubscription<Uint8List> _subscription;
  late final Timer _keepAlive;
  bool _attached = true;

  void writeEvent(Map<String, Object?> message) =>
      _write('event: message\ndata: ${jsonEncode(message)}\n\n');

  /// Stops pushing and drops the socket without a goodbye, for a peer that is
  /// already gone or a transport that is shutting down.
  void detach() {
    if (!_release()) {
      return;
    }
    PortableLogger.d('Event stream detached', _logTag);
    _socket.destroy();
  }

  Future<void> close() async {
    if (!_release()) {
      return;
    }
    try {
      await _socket.flush();
      await _socket.close();
    } on SocketException {
      // The peer is already gone; destroying below is the only cleanup left.
    }
    _socket.destroy();
  }

  bool _release() {
    if (!_attached) {
      return false;
    }
    _attached = false;
    _keepAlive.cancel();
    unawaited(_subscription.cancel());
    return true;
  }

  void _write(String frame) {
    if (!_attached) {
      return;
    }
    try {
      _socket.write(frame);
    } on SocketException catch (error) {
      PortableLogger.w('Event stream write failed: ${error.message}', _logTag);
    }
  }

  static void _discardIncoming(Uint8List _) {}
}

class _McpSessionClosedException implements Exception {
  const _McpSessionClosedException();
}
