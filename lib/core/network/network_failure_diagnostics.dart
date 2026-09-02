import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';

/// Adds failure diagnostics without logging request credentials or query data.
void addNetworkFailureDiagnostics(Dio dio, {required String scope}) {
  dio.interceptors.add(_NetworkFailureLogInterceptor(scope));
}

@visibleForTesting
String formatNetworkFailureDiagnostic({
  required String scope,
  required DioException error,
}) {
  final request = error.requestOptions;
  final origin = '${request.uri.scheme}://${request.uri.host}';
  final cause = error.error;
  final causeDetails = switch (cause) {
    final SocketException socket =>
      '${socket.runtimeType}: ${socket.message}'
          '${socket.osError == null ? '' : ' (${socket.osError})'}',
    final HandshakeException handshake =>
      '${handshake.runtimeType}: ${handshake.message}',
    final HttpException http => '${http.runtimeType}: ${http.message}',
    _ => cause?.runtimeType.toString() ?? 'none',
  };
  return '$scope request failed: method=${request.method}, origin=$origin, '
      'type=${error.type.name}, status=${error.response?.statusCode}, '
      'cause=$causeDetails';
}

class _NetworkFailureLogInterceptor extends Interceptor {
  const _NetworkFailureLogInterceptor(this.scope);

  final String scope;

  @override
  void onError(DioException error, ErrorInterceptorHandler handler) {
    AppLogger.w(
      formatNetworkFailureDiagnostic(scope: scope, error: error),
      'NETWORK',
    );
    handler.next(error);
  }
}
