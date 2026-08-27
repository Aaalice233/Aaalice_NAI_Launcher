import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'safe_web_reader.dart';

/// Creates an isolated Dio transport whose proxy behavior follows the current
/// application setting instead of the process-wide [HttpOverrides] snapshot.
Dio createWebAccessDio({
  required BaseOptions options,
  String? proxyAddress,
  bool protectPublicTargetsAtConnect = false,
  WebAddressResolver? resolveAddresses,
}) {
  final normalizedProxy = proxyAddress?.trim();
  final dio = Dio(options);
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()
        ..findProxy = (_) => normalizedProxy == null || normalizedProxy.isEmpty
            ? 'DIRECT'
            : 'PROXY $normalizedProxy';
      if (protectPublicTargetsAtConnect) {
        client.connectionFactory = SafeWebConnectionFactory(
          resolveAddresses: resolveAddresses,
        ).connect;
      }
      return client;
    },
  );
  return dio;
}

/// Pins direct requests to the same checked addresses used to open the socket.
/// Proxy connections are opened explicitly and leave hostname resolution to
/// that user-selected proxy.
class SafeWebConnectionFactory {
  SafeWebConnectionFactory({WebAddressResolver? resolveAddresses})
    : _resolveAddresses =
          resolveAddresses ?? ((hostname) => InternetAddress.lookup(hostname));

  final WebAddressResolver _resolveAddresses;

  Future<ConnectionTask<Socket>> connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null) {
      if (proxyPort == null || proxyPort <= 0) {
        throw SocketException('Invalid proxy port for $proxyHost.');
      }
      return Socket.startConnect(proxyHost, proxyPort);
    }

    final addresses = await SafeWebReader.resolvePublicAddresses(
      uri.host,
      resolveAddresses: _resolveAddresses,
    );
    final attempt = _PinnedSocketAttempt(uri, addresses);
    return ConnectionTask.fromSocket(attempt.connect(), attempt.cancel);
  }
}

class _PinnedSocketAttempt {
  _PinnedSocketAttempt(this.uri, this.addresses);

  final Uri uri;
  final List<InternetAddress> addresses;

  ConnectionTask<Socket>? _activeTask;
  Socket? _activeSocket;
  bool _cancelled = false;

  int get _port => uri.port > 0
      ? uri.port
      : uri.scheme == 'https'
      ? 443
      : 80;

  Future<Socket> connect() async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final address in addresses) {
      Socket? socket;
      try {
        _throwIfCancelled();
        final task = await Socket.startConnect(address, _port);
        _activeTask = task;
        socket = await task.socket;
        _activeSocket = socket;
        _throwIfCancelled();
        if (uri.scheme == 'https') {
          final secureSocket = await SecureSocket.secure(
            socket,
            host: uri.host,
          );
          _activeSocket = secureSocket;
          _throwIfCancelled();
          return secureSocket;
        }
        return socket;
      } catch (error, stackTrace) {
        socket?.destroy();
        _activeSocket = null;
        _activeTask = null;
        if (_cancelled) {
          throw _cancelledError();
        }
        lastError = error;
        lastStackTrace = stackTrace;
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  void cancel() {
    _cancelled = true;
    _activeTask?.cancel();
    _activeSocket?.destroy();
  }

  void _throwIfCancelled() {
    if (_cancelled) throw _cancelledError();
  }

  SocketException _cancelledError() =>
      SocketException('Connection to ${uri.host}:$_port was cancelled.');
}
