import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nai_launcher/core/mcp/mcp_server_constants.dart';

class McpHttpResponse {
  McpHttpResponse({
    required this.statusCode,
    required this.body,
    required Map<String, String> headers,
  }) : _headers = headers;

  final int statusCode;
  final String body;
  final Map<String, String> _headers;

  String? header(String name) => _headers[name.toLowerCase()];

  String? get sessionId => header(McpServerDefaults.sessionIdHeader);

  Map<String, Object?> get json => jsonDecode(body) as Map<String, Object?>;

  /// The JSON payloads of every `event: message` frame, in order.
  List<Map<String, Object?>> get events => [
    for (final line in body.split('\n'))
      if (line.startsWith('data: '))
        jsonDecode(line.substring('data: '.length)) as Map<String, Object?>,
  ];

  int get keepAliveCount =>
      body.split('\n').where((line) => line.startsWith(': ')).length;
}

/// Drives the loopback MCP endpoint the way an external client would.
class McpHttpTestClient {
  McpHttpTestClient({required this.endpoint, required this.token});

  final Uri endpoint;
  final String token;
  final HttpClient _client = HttpClient();

  String? sessionId;

  Future<McpHttpResponse> post(
    Object? message, {
    bool acceptEventStream = false,
    String? contentType = 'application/json',
    String? authorization,
    bool sendAuthorization = true,
    String? origin,
    String? protocolVersion,
    String? session,
    bool sendSession = true,
    String? rawBody,
    Uri? path,
  }) => _send(
    'POST',
    acceptEventStream: acceptEventStream,
    contentType: contentType,
    authorization: authorization,
    sendAuthorization: sendAuthorization,
    origin: origin,
    protocolVersion: protocolVersion,
    session: session,
    sendSession: sendSession,
    body: rawBody ?? jsonEncode(message),
    path: path,
  );

  Future<McpHttpResponse> delete({String? session, bool sendSession = true}) =>
      _send('DELETE', session: session, sendSession: sendSession);

  Future<McpHttpResponse> get({bool acceptEventStream = true}) =>
      _send('GET', acceptEventStream: acceptEventStream);

  Future<McpHttpResponse> method(String verb) => _send(verb);

  /// Runs the `initialize` handshake and remembers the session id.
  Future<McpHttpResponse> initialize({
    String clientName = 'claude-code',
    String clientVersion = '2.4.0',
    bool acceptEventStream = false,
  }) async {
    final response = await post(
      {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-11-25',
          'capabilities': <String, Object?>{},
          'clientInfo': {'name': clientName, 'version': clientVersion},
        },
      },
      acceptEventStream: acceptEventStream,
      sendSession: false,
    );
    sessionId = response.sessionId;
    await post({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
    return response;
  }

  Future<McpHttpResponse> callTool(
    String name, {
    Map<String, Object?> arguments = const {},
    int id = 10,
    bool acceptEventStream = false,
  }) => post({
    'jsonrpc': '2.0',
    'id': id,
    'method': 'tools/call',
    'params': {'name': name, 'arguments': arguments},
  }, acceptEventStream: acceptEventStream);

  /// Sends a handcrafted request so tests can forge headers `HttpClient`
  /// manages itself. Always closes the connection after the response.
  Future<String> raw(String head, {String body = ''}) async {
    final socket = await Socket.connect(endpoint.host, endpoint.port);
    final buffer = StringBuffer();
    final closed = Completer<void>();
    void finish() {
      if (!closed.isCompleted) {
        closed.complete();
      }
    }

    socket.listen(
      (data) => buffer.write(utf8.decode(data, allowMalformed: true)),
      onDone: finish,
      onError: (Object _) => finish(),
    );
    socket.write('$head$body');
    await socket.flush();
    await closed.future.timeout(const Duration(seconds: 5), onTimeout: finish);
    socket.destroy();
    return buffer.toString();
  }

  void close() => _client.close(force: true);

  Future<McpHttpResponse> _send(
    String verb, {
    bool acceptEventStream = false,
    String? contentType,
    String? authorization,
    bool sendAuthorization = true,
    String? origin,
    String? protocolVersion,
    String? session,
    bool sendSession = true,
    String? body,
    Uri? path,
  }) async {
    final request = await _client.openUrl(verb, path ?? endpoint);
    if (sendAuthorization) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        authorization ?? 'Bearer $token',
      );
    }
    if (origin != null) {
      request.headers.set('origin', origin);
    }
    if (protocolVersion != null) {
      request.headers.set(
        McpServerDefaults.protocolVersionHeader,
        protocolVersion,
      );
    }
    final resolvedSession = session ?? sessionId;
    if (sendSession && resolvedSession != null) {
      request.headers.set(McpServerDefaults.sessionIdHeader, resolvedSession);
    }
    request.headers.set(
      HttpHeaders.acceptHeader,
      acceptEventStream
          ? 'application/json, text/event-stream'
          : 'application/json',
    );
    if (body != null) {
      if (contentType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      } else {
        request.headers.removeAll(HttpHeaders.contentTypeHeader);
      }
      request.add(utf8.encode(body));
    }
    final response = await request.close();
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name.toLowerCase()] = values.join(', ');
    });
    return McpHttpResponse(
      statusCode: response.statusCode,
      body: await response.transform(utf8.decoder).join(),
      headers: headers,
    );
  }
}
