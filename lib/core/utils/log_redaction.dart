import 'log_url_redaction.dart';

final _authorizationValue = RegExp(
  r'\bauthorization\s*[:=]\s*(?:basic|bearer)\s+([^\s,;]+)',
  caseSensitive: false,
);
final _authorizationField = RegExp(
  r'\b(authorization)\s*([:=])\s*(?:(?:basic|bearer)\s+)?[^\s,;]+',
  caseSensitive: false,
);
final _bearerToken = RegExp(
  r'\bbearer\s+([A-Za-z0-9._~+/=-]{6,})',
  caseSensitive: false,
);
final _credentialField = RegExp(
  r'\b(token|api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret|private[_-]?key|cookies?|session(?:id|[_-]?(?:token|key))?)\s*([:=])\s*([^&\s,;}]+)',
  caseSensitive: false,
);
final _privateKey = RegExp(
  r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----.*?(?:-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----|$)',
  caseSensitive: false,
  dotAll: true,
);
final _cookieHeader = RegExp(
  r'\b(set-cookie|cookies?)\s*:\s*[^\r\n]*',
  caseSensitive: false,
);
final _knownToken = RegExp(
  r'\b(?:pst-[A-Za-z0-9_-]{10,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|hf_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b',
);
final _jwt = RegExp(
  r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
);

String redactLogText(String text) {
  final secrets = <String>{};

  void collect(RegExp pattern, int group) {
    for (final match in pattern.allMatches(text)) {
      final value = match.group(group)!;
      if (value.length >= 4) secrets.add(value);
    }
  }

  // 查询串可能是日志中唯一标出凭据值的位置。
  collect(_authorizationValue, 1);
  collect(_bearerToken, 1);
  collect(_credentialField, 3);

  var redacted = redactUrlsInLogText(text)
      .replaceAll(_privateKey, '[REDACTED PRIVATE KEY]')
      .replaceAllMapped(
        _cookieHeader,
        (match) => '${match.group(1)}: [REDACTED]',
      )
      .replaceAllMapped(_authorizationField, _redactField)
      .replaceAll(_bearerToken, 'Bearer [REDACTED]')
      .replaceAllMapped(_credentialField, _redactField)
      .replaceAll(_knownToken, '[REDACTED]')
      .replaceAll(_jwt, '[REDACTED]');

  for (final secret in secrets) {
    redacted = redacted.replaceAll(secret, '[REDACTED]');
  }
  return redacted;
}

String _redactField(Match match) =>
    '${match.group(1)}${match.group(2)} [REDACTED]';
