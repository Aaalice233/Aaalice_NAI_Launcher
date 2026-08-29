import 'dart:convert';

/// Presentation-safe projection of tool protocol text.
///
/// Tool results intentionally retain their structured JSON for auditability,
/// but the transcript should lead with a human-readable outcome instead of
/// exposing that wire format by default.
abstract final class AgentToolPresentation {
  static String summary(String raw, {required String fallback}) {
    final text = raw.trim();
    if (text.isEmpty) return fallback;
    final decoded = _tryDecode(text);
    if (decoded is Map) {
      for (final key in const [
        'summary',
        'message',
        'error',
        'status_message',
        'statusMessage',
        'title',
      ]) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return _bounded(value.trim(), fallback: fallback);
        }
      }
      return fallback;
    }
    if (decoded is List) return fallback;
    return _bounded(text.replaceAll(RegExp(r'\s+'), ' '), fallback: fallback);
  }

  static String formattedDetails(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final decoded = _tryDecode(text);
    if (decoded == null) return text;
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static String formattedValue(Object? value) {
    if (value == null) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } on JsonUnsupportedObjectError {
      return value.toString();
    }
  }

  static Object? _tryDecode(String text) {
    if (!(text.startsWith('{') && text.endsWith('}')) &&
        !(text.startsWith('[') && text.endsWith(']'))) {
      return null;
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static String _bounded(String value, {required String fallback}) {
    if (value.isEmpty) return fallback;
    return value.length <= 96 ? value : '${value.substring(0, 96)}…';
  }
}
