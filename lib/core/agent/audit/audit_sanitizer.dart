abstract final class AgentAuditSanitizer {
  static String sanitize(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAllMapped(
      _bearerToken,
      (match) => '${match.group(1)}[REDACTED_TOKEN]',
    );
    sanitized = sanitized.replaceAllMapped(
      _namedToken,
      (match) => '${match.group(1)}[REDACTED_TOKEN]',
    );
    sanitized = sanitized.replaceAll(_providerToken, '[REDACTED_TOKEN]');
    sanitized = sanitized.replaceAll(_jwt, '[REDACTED_TOKEN]');
    sanitized = sanitized.replaceAll(_absoluteWindowsPath, '[REDACTED_PATH]');
    sanitized = sanitized.replaceAll(_absoluteUnixPath, '[REDACTED_PATH]');
    sanitized = sanitized.replaceAllMapped(
      _base64DataUri,
      (match) => '${match.group(1)}[REDACTED_BASE64]',
    );
    return sanitized.replaceAll(_base64Blob, '[REDACTED_BASE64]');
  }

  static final RegExp _bearerToken = RegExp(
    r'(\bBearer\s+)[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _namedToken = RegExp(
    r'''("?\b(?:api[_-]?key|access[_-]?token|auth[_-]?token|token)"?\s*[:=]\s*["']?)[^\s,"']+''',
    caseSensitive: false,
  );
  static final RegExp _providerToken = RegExp(
    r'\b(?:sk|nai|pst|ghp|github_pat)-[A-Za-z0-9_-]{12,}\b',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}(?:\.[A-Za-z0-9_-]+)?\b',
  );
  static final RegExp _absoluteWindowsPath = RegExp(
    r'''(?:[A-Z]:[\\/]|\\\\)[^\s"'<>|]+''',
    caseSensitive: false,
  );
  static final RegExp _absoluteUnixPath = RegExp(
    r'''(?<![A-Za-z0-9:])/(?:Users|home|root|tmp|var|etc|opt|private)(?:/[^\s"'<>|]*)?''',
    caseSensitive: false,
  );
  static final RegExp _base64DataUri = RegExp(
    r'(\bdata:[^;,\s]+;base64,)[A-Za-z0-9+/=]{16,}',
    caseSensitive: false,
  );
  static final RegExp _base64Blob = RegExp(
    r'(?<![A-Za-z0-9+/=])[A-Za-z0-9+/]{32,}={0,2}(?![A-Za-z0-9+/=])',
  );
}
