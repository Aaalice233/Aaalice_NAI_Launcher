import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart' as mcp;

import '../utils/portable_logger.dart';
import 'mcp_bearer_authenticator.dart';
import 'mcp_discovery_file.dart';
import 'mcp_launcher_server.dart';
import 'mcp_server_constants.dart';
import 'mcp_session_registry.dart';
import 'mcp_streamable_http_transport.dart';
import 'mcp_tool_executor.dart';

/// The loopback port is already taken, usually by a second launcher instance.
class McpHostBindException implements Exception {
  const McpHostBindException(this.port, this.cause);

  final int port;
  final Object cause;

  @override
  String toString() => 'McpHostBindException(port: $port, cause: $cause)';
}

/// Binds the loopback HTTP server, publishes the discovery file and keeps the
/// session registry swept.
class McpServerHost {
  McpServerHost({
    required McpToolExecutor executor,
    required McpDiscoveryFileStore discovery,
    required String appVersion,
    int Function()? pidProvider,
    DateTime Function()? clock,
    Duration sessionIdleTimeout = McpServerDefaults.sessionIdleTimeout,
    int maxSessions = McpServerDefaults.maxSessions,
  }) : _discovery = discovery,
       _appVersion = appVersion,
       _pidProvider = pidProvider ?? (() => pid),
       _clock = clock ?? DateTime.now {
    _registry = McpSessionRegistry(
      createServer: (channel, session) => McpLauncherServer.fromStreamChannel(
        channel,
        executor: executor,
        sessionId: session.id,
        appVersion: appVersion,
        signalFor: session.signalFor,
        onClientInfo: session.attachClientInfo,
      ),
      idleTimeout: sessionIdleTimeout,
      maxSessions: maxSessions,
      clock: _clock,
    );
  }

  static const String _logTag = 'McpServer';
  static const Duration _sweepInterval = Duration(minutes: 1);

  final McpDiscoveryFileStore _discovery;
  final String _appVersion;
  final int Function() _pidProvider;
  final DateTime Function() _clock;

  late final McpSessionRegistry _registry;

  HttpServer? _server;
  McpStreamableHttpTransport? _transport;
  Timer? _sweepTimer;
  String _token = '';

  bool get isListening => _server != null;

  int? get port => _server?.port;

  Uri? get endpoint {
    final boundPort = port;
    if (boundPort == null) {
      return null;
    }
    return Uri(
      scheme: 'http',
      host: McpServerDefaults.loopbackHost,
      port: boundPort,
      path: McpServerDefaults.endpointPath,
    );
  }

  List<McpSessionSummary> get sessions => _registry.summaries;

  Stream<List<McpSessionSummary>> get sessionChanges => _registry.changes;

  /// Pass `port: 0` to let the OS pick a free port and read it back from
  /// [port]; the discovery file always carries the port that was actually
  /// bound.
  Future<void> start({required int port, required String token}) async {
    if (_server != null) {
      await stop();
    }
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException catch (error) {
      throw McpHostBindException(port, error);
    }
    _token = token;
    _server = server;
    final transport = McpStreamableHttpTransport(
      sessions: _registry,
      authenticator: McpBearerAuthenticator(() => _token),
    );
    _transport = transport;
    unawaited(_accept(server, transport));
    await _discovery.write(
      McpDiscoveryDocument(
        port: server.port,
        pid: _pidProvider(),
        startedAt: _clock().toUtc(),
        token: token,
        protocolVersions: [
          for (final version in mcp.ProtocolVersion.values)
            if (version.isSupported) version.versionString,
        ],
        appVersion: _appVersion,
      ),
    );
    _sweepTimer = Timer.periodic(_sweepInterval, (_) => _registry.sweepIdle());
    PortableLogger.d('MCP server listening on ${endpoint!}', _logTag);
  }

  Future<void> stop() async {
    _sweepTimer?.cancel();
    _sweepTimer = null;
    await _registry.closeAll();
    final transport = _transport;
    _transport = null;
    await transport?.shutdown();
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    _token = '';
    await _discovery.delete();
  }

  Future<void> _accept(
    HttpServer server,
    McpStreamableHttpTransport transport,
  ) async {
    await for (final request in server) {
      unawaited(_handle(transport, request));
    }
  }

  Future<void> _handle(
    McpStreamableHttpTransport transport,
    HttpRequest request,
  ) async {
    try {
      await transport.handle(request);
    } catch (error, stackTrace) {
      PortableLogger.e(
        'MCP request ${request.method} failed',
        error,
        stackTrace,
        _logTag,
      );
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } on StateError {
        // The response was already committed or detached; nothing to send.
      }
    }
  }
}
