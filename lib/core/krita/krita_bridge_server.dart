import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../platform/launcher_discovery_directory.dart';
import '../utils/app_logger.dart';
import 'krita_bridge_models.dart';
import 'krita_bridge_protocol.dart';

typedef KritaBridgeSecretGenerator = String Function();
typedef KritaBridgePidProvider = int Function();
typedef KritaBridgeClock = DateTime Function();

class KritaBridgeServer {
  KritaBridgeServer({
    Directory? discoveryDirectory,
    KritaBridgeSecretGenerator? secretGenerator,
    KritaBridgePidProvider? pidProvider,
    KritaBridgeClock? clock,
    this.maxTextFrameBytes = KritaBridgeProtocol.defaultMaxTextFrameBytes,
  })  : _discoveryDirectory =
            discoveryDirectory ?? _defaultDiscoveryDirectory(),
        _secretGenerator = secretGenerator ?? _generateSecret,
        _pidProvider = pidProvider ?? (() => pid),
        _clock = clock ?? DateTime.now;

  static const String discoveryFileName = 'krita-bridge.json';
  static const String _logTag = 'KritaBridge';

  final Directory _discoveryDirectory;
  final KritaBridgeSecretGenerator _secretGenerator;
  final KritaBridgePidProvider _pidProvider;
  final KritaBridgeClock _clock;
  final int maxTextFrameBytes;

  final StreamController<KritaBridgeMessage> _messageController =
      StreamController<KritaBridgeMessage>.broadcast();
  final StreamController<bool> _authenticationController =
      StreamController<bool>.broadcast();

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
    final client = _client;
    _client = null;
    _clientAuthenticated = false;
    _connectedClientLabel = null;
    if (!_authenticationController.isClosed) {
      _authenticationController.add(false);
    }

    if (client != null) {
      await client.close();
    }

    final server = _server;
    _server = null;
    _secret = null;
    _startedAt = null;
    if (server != null) {
      await server.close(force: true);
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
      AppLogger.i('Incoming WebSocket connection', _logTag);
      unawaited(_handleSocket(socket, clientLabel: clientLabel));
    }
  }

  Future<void> _handleSocket(
    WebSocket socket, {
    required String clientLabel,
  }) async {
    var socketAuthenticated = false;

    try {
      await for (final data in socket) {
        if (data is! String) {
          _sendError(
            socket,
            const KritaBridgeError(
              code: KritaBridgeErrorCode.invalidRequest,
              message: 'Only JSON text frames are supported in V1',
            ),
          );
          continue;
        }

        final result = KritaBridgeProtocol.decodeIncoming(
          data,
          sessionSecret: _secret ?? '',
          authenticated: socketAuthenticated,
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
          continue;
        }

        final message = result.message;
        if (message == null) {
          continue;
        }

        if (message is KritaUnsupportedPingVersionMessage) {
          socket.add(
            jsonEncode(
              KritaBridgeProtocol.encodePong(
                supportedVersions: message.supportedVersions,
              ),
            ),
          );
          AppLogger.w(
            'Rejected ping version: ${message.requestedVersion}',
            _logTag,
          );
          continue;
        }

        if (message is KritaPingMessage) {
          await _authenticateSocket(socket, clientLabel: clientLabel);
          socketAuthenticated = true;
          socket.add(jsonEncode(KritaBridgeProtocol.encodePong()));
          AppLogger.i('Bridge client authenticated', _logTag);
          continue;
        }

        if (!identical(_client, socket)) {
          AppLogger.w(
            'Dropped message from replaced client'
            '${message.id == null ? '' : ' id=${message.id}'}',
            _logTag,
          );
          continue;
        }

        _messageController.add(message);
      }
    } finally {
      if (identical(_client, socket)) {
        _client = null;
        _clientAuthenticated = false;
        _connectedClientLabel = null;
        if (!_authenticationController.isClosed) {
          _authenticationController.add(false);
        }
      }
    }
  }

  Future<void> _authenticateSocket(
    WebSocket socket, {
    required String clientLabel,
  }) async {
    final previousClient = _client;
    if (previousClient != null && !identical(previousClient, socket)) {
      unawaited(previousClient.close());
    }

    _client = socket;
    _clientAuthenticated = true;
    _connectedClientLabel = clientLabel;
    _authenticationController.add(true);
    AppLogger.i('Authenticated client is active', _logTag);
  }

  void _sendError(WebSocket socket, KritaBridgeError error) {
    socket.add(jsonEncode(KritaBridgeProtocol.encodeError(error)));
  }

  Future<void> _writeDiscoveryFile() async {
    await _discoveryDirectory.create(recursive: true);

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

    try {
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
