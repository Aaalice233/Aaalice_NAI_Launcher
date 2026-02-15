import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';

class ApiErrorMapper {
  const ApiErrorMapper._();

  static String formatDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final serverMessage = _extractServerMessage(e.response?.data);

    final statusCodeError = switch (statusCode) {
      400 => 'API_ERROR_400|${serverMessage ?? "Bad request"}',
      429 => 'API_ERROR_429|${serverMessage ?? "Too many requests"}',
      401 => 'API_ERROR_401|${serverMessage ?? "Unauthorized"}',
      402 => 'API_ERROR_402|${serverMessage ?? "Payment required"}',
      500 => 'API_ERROR_500|${serverMessage ?? "Server error"}',
      503 => 'API_ERROR_503|${serverMessage ?? "Service unavailable"}',
      _ => null,
    };

    if (statusCodeError != null) {
      return statusCodeError;
    }

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'API_ERROR_TIMEOUT|${e.message ?? "Timeout"}',
      DioExceptionType.connectionError =>
        'API_ERROR_NETWORK|${e.message ?? "Connection error"}',
      _ when statusCode != null =>
        'API_ERROR_HTTP_$statusCode|${e.message ?? "Unknown error"}',
      _ => 'API_ERROR_UNKNOWN|${e.message ?? "Unknown error"}',
    };
  }

  static String? _extractServerMessage(dynamic data) {
    try {
      return switch (data) {
        Map() => data['message']?.toString() ?? data['error']?.toString(),
        String() when data.isNotEmpty => data,
        Uint8List() => _extractServerMessageFromBytes(data),
        List<int>() => _extractServerMessageFromBytes(Uint8List.fromList(data)),
        _ => null,
      };
    } catch (error) {
      AppLogger.w('Failed to extract error message from response: $error', 'Utils');
      return null;
    }
  }

  static String _extractServerMessageFromBytes(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    try {
      final json = jsonDecode(text);
      if (json is Map) {
        return json['message']?.toString() ?? json['error']?.toString() ?? text;
      }
      return text;
    } catch (jsonError) {
      AppLogger.w('Failed to parse error response JSON: $jsonError', 'Utils');
      return text;
    }
  }
}
