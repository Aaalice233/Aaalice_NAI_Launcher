import 'dart:convert';
import 'dart:typed_data';

/// Extracts a useful server error from JSON, UTF-8 bytes, or plain text.
///
/// Dio keeps error bodies as bytes when the successful response is expected to
/// be an image archive. Third-party APIs commonly return JSON in that case.
String? parseDioErrorResponseDetails(Object? data) {
  final decoded = _decodeDioErrorResponse(data);
  if (decoded == null) return null;

  if (decoded is String) {
    final text = decoded.trim();
    return text.isEmpty ? null : text;
  }
  if (decoded is! Map) return null;

  final nestedError = decoded['error'];
  final nestedMap = nestedError is Map ? nestedError : null;
  final message = _firstNonEmpty([
    decoded['message'],
    decoded['detail'],
    nestedMap?['message'],
    nestedError is String ? nestedError : null,
  ]);
  final code = _firstNonEmpty([decoded['code'], nestedMap?['code']]);
  final requestId = _firstNonEmpty([
    decoded['request_id'],
    decoded['requestId'],
    nestedMap?['request_id'],
    nestedMap?['requestId'],
  ]);

  var details = message ?? code;
  if (details == null) return null;
  if (code != null && code != details && !details.contains(code)) {
    details = '$details (code: $code)';
  }
  if (requestId != null) {
    details = '$details [request_id: $requestId]';
  }
  return details;
}

String formatDioErrorResponseDataForLog(Object? data) {
  final decoded = _decodeDioErrorResponse(data);
  final text = decoded is String
      ? decoded.trim()
      : decoded == null
      ? data?.runtimeType.toString() ?? 'null'
      : _encodeDioErrorResponseForLog(decoded);
  const maximumLength = 4096;
  if (text.length <= maximumLength) return text;
  return '${text.substring(0, maximumLength)}… [truncated]';
}

String _encodeDioErrorResponseForLog(Object decoded) {
  if (decoded is Map || decoded is List || decoded is num || decoded is bool) {
    try {
      return jsonEncode(decoded);
    } on JsonUnsupportedObjectError {
      // Fall through to the safe object representation.
    }
  }
  return decoded.toString();
}

Object? _decodeDioErrorResponse(Object? data) {
  Object? decoded = data;
  if (data is Uint8List) {
    try {
      decoded = utf8.decode(data);
    } on FormatException {
      return null;
    }
  } else if (data is List<int>) {
    try {
      decoded = utf8.decode(data);
    } on FormatException {
      return null;
    }
  }

  if (decoded is! String) return decoded;
  final text = decoded.trim();
  if (text.isEmpty) return null;
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

String? _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}
