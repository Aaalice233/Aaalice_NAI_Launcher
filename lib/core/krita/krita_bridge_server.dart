import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../platform/launcher_discovery_directory.dart';
import '../platform/owner_only_permissions.dart';
import '../utils/app_logger.dart';
import 'krita_bridge_models.dart';
import 'krita_bridge_protocol.dart';

typedef KritaBridgeSecretGenerator = String Function();
typedef KritaBridgePidProvider = int Function();
typedef KritaBridgeClock = DateTime Function();
typedef KritaBridgeLateFramesObserver = void Function();

class KritaBridgeServer {
  KritaBridgeServer({
    Directory? discoveryDirectory,
    KritaBridgeSecretGenerator? secretGenerator,
    KritaBridgePidProvider? pidProvider,
    KritaBridgeClock? clock,
    OwnerOnlyPermissionGuard? restrictToOwner,
    KritaBridgeLateFramesObserver? onLateFramesDropped,
    this.maxTextFrameBytes = KritaBridgeProtocol.defaultMaxTextFrameBytes,
    this.closeGracePeriod = defaultCloseGracePeriod,
  })  : _discoveryDirectory =
            discoveryDirectory ?? _defaultDiscoveryDirectory(),
        _secretGenerator = secretGenerator ?? _generateSecret,
        _pidProvider = pidProvider ?? (() => pid),
        _clock = clock ?? DateTime.now,
        _restrictToOwner = restrictToOwner ?? restrictPathToOwner,
        _onLateFramesDropped = onLateFramesDropped;

  static const String discoveryFileName = 'krita-bridge.json';
  static const Duration defaultCloseGracePeriod = Duration(seconds: 2);
  static const String _logTag = 'KritaBridge';

  final Directory _discoveryDirectory;
  final KritaBridgeSecretGenerator _secretGenerator;
  final KritaBridgePidProvider _pidProvider;
  final KritaBridgeClock _clock;
  final OwnerOnlyPermissionGuard _restrictToOwner;
  final KritaBridgeLateFramesObserver? _onLateFramesDropped;
  final int maxTextFrameBytes;
  final Duration closeGracePeriod;

  final StreamController<KritaBridgeMessage> _messageController =
      StreamController<KritaBridgeMessage>.broadcast();
  final StreamController<bool> _authenticationController =
      StreamController<bool>.broadcast();

  final Set<WebSocket> _connections = <WebSocket>{};

  HttpServer? _server;
  WebSocket? _client;
  bool _clientAuthenticated = false;
  String? _connectedClientLabel;
  String? _secret;
  DateTime? _startedAt;

  Stream<KritaBridgeMessage> get messages => _messageController.stream;

  Stream<bool> get authenticationChanges => _authenticationController.stream;

  int? get port => _server?.port;

  String? get secret => _secret;

  bool get isListening => _server != null;

  bool get isClientAuthenticated => _clientAuthenticated;

  String? get connectedClientLabel => _connectedClientLabel;

  File get discoveryFile =>
      File(_join(_discoveryDirectory.path, discoveryFileName));

  Future<void> start({int preferredPort = 0}) async {
    if (_server != null) {
      await stop();
    }

    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      preferredPort,
    );
    _server = server;
    try {
      _secret = _secretGenerator();
      _startedAt = _clock().toUtc();
      unawaited(_acceptRequests(server));
      await _writeDiscoveryFile();
    } catch (_) {
      // Publishing failed, so the discovery file is not ours to delete.
      await _releaseListener();
      rethrow;
    }
    AppLogger.i('Bridge listening on 127.0.0.1:$port', _logTag);
  }

  Future<void> stop() async {
    await _releaseListener();
    await _deleteDiscoveryFile();
    AppLogger.i('Bridge stopped', _logTag);
  }

  Future<void> _releaseListener() async {
    _client = null;
    _clientAuthenticated = false;
    _connectedClientLabel = null;
    if (!_authenticationController.isClosed) {
      _authenticationController.add(false);
    }

    final server = _server;
    _server = null;
    _secret = null;
    _startedAt = null;

    // Upgraded sockets are detached, so server.close(force) cannot reach them.
    final closing = _closeConnections();
    if (server != null) {
      await server.close(force: true);
    }
    await closing;
  }

  Future<void> _closeConnections() async {
    final connections = List<WebSocket>.of(_connections);
    if (connections.isEmpty) {
      return;
    }
    try {
      await Future.wait(connections.map(_closeConnection))
          .timeout(closeGracePeriod);
    } on TimeoutException {
      // close() only completes once a peer reads all queued output.
      AppLogger.w('Gave up waiting for bridge connections to close', _logTag);
    }
  }

  Future<void> _closeConnection(WebSocket socket) async {
    _connections.remove(socket);
    try {
      await socket.close();
    } on IOException catch (error) {
      AppLogger.w(
        'Closing bridge connection failed: ${error.runtimeType}',
        _logTag,
      );
    }
  }

  Future<void> _deleteDiscoveryFile() async {
    final file = discoveryFile;
    if (await file.exists()) {
      await file.delete();
      AppLogger.i('Discovery file deleted: ${file.path}', _logTag);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _messageController.close();
    await _authenticationController.close();
  }

  void send(Map<String, dynamic> message) {
    final client = _client;
    if (client == null || !_clientAuthenticated) {
      return;
    }

    client.add(jsonEncode(message));
  }

  void sendBinary(Uint8List bytes) {
    final client = _client;
    if (client == null || !_clientAuthenticated) {
      return;
    }

    client.add(bytes);
  }

  Future<void> _acceptRequests(HttpServer server) async {
    await for (final request in server) {
      if (request.uri.path != '/krita' ||
          !WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        continue;
      }

      final clientLabel = _clientLabelFor(request);
      final socket = await WebSocketTransformer.upgrade(request);
      if (!identical(_server, server)) {
        unawaited(_closeConnection(socket));
        continue;
      }
      _connections.add(socket);
      AppLogger.i('Incoming WebSocket connection', _logTag);
      unawaited(_handleSocket(socket, clientLabel: clientLabel));
    }
  }

  Future<void> _handleSocket(
    WebSocket socket, {
    required String clientLabel,
  }) async {
    var socketAuthenticated = false;
    var droppedLateFrames = false;

    try {
      await for (final data in socket) {
        if (!_connections.contains(socket)) {
          // Closed by this server; replying to late frames would throw.
          if (!droppedLateFrames) {
            droppedLateFrames = true;
            AppLogger.w(
              'Dropped late frames from a closed connection',
              _logTag,
            );
            _onLateFramesDropped?.call();
          }
          continue;
        }

        final message = _decodeFrame(
          socket,
          data,
          authenticated: socketAuthenticated,
        );
        switch (message) {
          case null:
            break;
          case KritaUnsupportedPingVersionMessage():
            _rejectPingVersion(socket, message);
          case KritaPingMessage():
            _authenticateSocket(socket, clientLabel: clientLabel);
            socketAuthenticated = true;
          default:
            _messageController.add(message);
        }
      }
    } finally {
      _forgetSocket(socket);
    }
  }

  KritaBridgeMessage? _decodeFrame(
    WebSocket socket,
    Object? data, {
    required bool authenticated,
  }) {
    if (data is! String) {
      _sendError(
        socket,
        const KritaBridgeError(
          code: KritaBridgeErrorCode.invalidRequest,
          message: 'Only JSON text frames are supported in V1',
        ),
      );
      return null;
    }

    final result = KritaBridgeProtocol.decodeIncoming(
      data,
      sessionSecret: _secret,
      authenticated: authenticated,
      maxTextFrameBytes: maxTextFrameBytes,
    );
    final error = result.error;
    if (error != null) {
      AppLogger.w(
        'Rejected message: ${error.code.value}'
        '${error.id == null ? '' : ' id=${error.id}'}',
        _logTag,
      );
      _sendError(socket, error);
      return null;
    }
    return result.message;
  }

  void _rejectPingVersion(
    WebSocket socket,
    KritaUnsupportedPingVersionMessage message,
  ) {
    socket.add(
      jsonEncode(
        KritaBridgeProtocol.encodePong(
          supportedVersions: message.supportedVersions,
        ),
      ),
    );
    AppLogger.w('Rejected ping version: ${message.requestedVersion}', _logTag);
  }

  void _authenticateSocket(
    WebSocket socket, {
    required String clientLabel,
  }) {
    final previousClient = _client;
    if (previousClient != null && !identical(previousClient, socket)) {
      unawaited(_closeConnection(previousClient));
    }

    _client = socket;
    _clientAuthenticated = true;
    _connectedClientLabel = clientLabel;
    _authenticationController.add(true);
    socket.add(jsonEncode(KritaBridgeProtocol.encodePong()));
    AppLogger.i('Bridge client authenticated', _logTag);
  }

  void _forgetSocket(WebSocket socket) {
    _connections.remove(socket);
    if (!identical(_client, socket)) {
      return;
    }
    _client = null;
    _clientAuthenticated = false;
    _connectedClientLabel = null;
    if (!_authenticationController.isClosed) {
      _authenticationController.add(false);
    }
  }

  void _sendError(WebSocket socket, KritaBridgeError error) {
    socket.add(jsonEncode(KritaBridgeProtocol.encodeError(error)));
  }

  Future<void> _writeDiscoveryFile() async {
    await _discoveryDirectory.create(recursive: true);
    await _restrictToOwner(_discoveryDirectory.path, '700');

    final target = discoveryFile;
    final temp = File(
      _join(
        _discoveryDirectory.path,
        '$discoveryFileName.${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );

    final data = <String, dynamic>{
      'port': port,
      'pid': _pidProvider(),
      'version': KritaBridgeProtocol.version,
      'secret': _secret,
      'started_at': _startedAt?.toIso8601String(),
    };

    await temp.create(exclusive: true);
    try {
      await _restrictToOwner(temp.path, '600');
      await temp.writeAsString(jsonEncode(data), flush: true);
      // rename replaces the target; an extra delete only blanks it for Krita.
      await temp.rename(target.path);
    } catch (_) {
      await _discardTemp(temp);
      rethrow;
    }
    AppLogger.i('Discovery file written: ${target.path}', _logTag);
  }

  Future<void> _discardTemp(File temp) async {
    try {
      if (await temp.exists()) {
        await temp.delete();
      }
    } on FileSystemException {
      // Cleanup must not mask the write failure the caller is about to see.
    }
  }

  static Directory _defaultDiscoveryDirectory() =>
      resolveLauncherDiscoveryDirectory();

  static String _generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _clientLabelFor(HttpRequest request) {
    final address =
        request.connectionInfo?.remoteAddress.address ?? 'unknown client';
    final userAgent = request.headers.value(HttpHeaders.userAgentHeader);
    if (userAgent == null || userAgent.isEmpty) {
      return address;
    }

    final safeUserAgent =
        userAgent.length > 80 ? '${userAgent.substring(0, 80)}...' : userAgent;
    return '$address ($safeUserAgent)';
  }

  static String _join(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
