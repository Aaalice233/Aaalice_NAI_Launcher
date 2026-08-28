import 'dart:convert';

import 'package:dio/dio.dart';

import 'web_access_models.dart';

String normalizeWebText(Object? value, {int maxCharacters = 1200}) {
  if (value is! String) return '';
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return truncateWebText(normalized, maxCharacters);
}

String truncateWebText(String value, int maxCharacters) {
  if (value.runes.length <= maxCharacters) return value;
  return '${String.fromCharCodes(value.runes.take(maxCharacters))}...';
}

Uri? parseHttpWebUri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

bool matchesWebDomainFilters(
  String hostname,
  Iterable<String> included,
  Iterable<String> excluded,
) {
  final host = hostname.toLowerCase();
  bool matches(String domain) => host == domain || host.endsWith('.$domain');
  if (included.isNotEmpty && !included.any(matches)) return false;
  return !excluded.any(matches);
}

String? normalizeWebDomain(Object? value) {
  if (value is! String) return null;
  var input = value.trim().toLowerCase();
  if (input.isEmpty) return null;
  try {
    final uri = Uri.parse(input.contains('://') ? input : 'https://$input');
    input = uri.host.toLowerCase();
  } catch (_) {
    return null;
  }
  input = input.replaceAll(RegExp(r'^\.+|\.+$'), '');
  if (!RegExp(r'^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$').hasMatch(input)) {
    return null;
  }
  return input.contains('.') ? input : null;
}

Map<String, dynamic> decodeJsonObject(Object? data, String source) {
  final Object? decoded;
  if (data is String) {
    decoded = jsonDecode(data);
  } else {
    decoded = data;
  }
  if (decoded is! Map) {
    throw WebAccessException(
      WebAccessErrorKind.invalidResponse,
      '$source returned a non-object JSON response.',
    );
  }
  return decoded.cast<String, dynamic>();
}

WebAccessException mapWebDioException(
  DioException error,
  WebSearchBackend backend, {
  String service = 'Web service',
}) {
  final cause = error.error;
  if (cause is WebAccessException) {
    return cause;
  }
  if (CancelToken.isCancel(error)) {
    return WebAccessException(
      WebAccessErrorKind.aborted,
      'Web request was cancelled.',
      backend: backend,
    );
  }
  final status = error.response?.statusCode;
  if (status == 401 || status == 403) {
    return WebAccessException(
      WebAccessErrorKind.authentication,
      '$service rejected the credentials (HTTP $status).',
      backend: backend,
      statusCode: status,
    );
  }
  if (status == 429) {
    return WebAccessException(
      WebAccessErrorKind.rateLimited,
      '$service rate limit reached (HTTP 429).',
      backend: backend,
      statusCode: status,
    );
  }
  return WebAccessException(
    WebAccessErrorKind.network,
    status == null
        ? '$service request failed: ${error.message ?? error.type.name}.'
        : '$service request failed (HTTP $status).',
    backend: backend,
    statusCode: status,
  );
}
