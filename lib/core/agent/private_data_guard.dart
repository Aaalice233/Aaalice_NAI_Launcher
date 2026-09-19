import 'dart:convert';
import 'dart:typed_data';

class PrivateDataGuard {
  const PrivateDataGuard._();

  static final RegExp _fileUriPattern = RegExp(
    r'\bfile:(?://(?:localhost)?/|//[^/\s]+/)[^\s"\x27`<>]*',
    caseSensitive: false,
  );
  static final RegExp _windowsPathPattern = RegExp(
    r'(?:^|[^A-Za-z0-9])(?:[a-z]:[\\/])[^\s"\x27`<>]*',
    caseSensitive: false,
    multiLine: true,
  );
  static final RegExp _backslashUncPattern = RegExp(
    r'(?:^|[^A-Za-z0-9])\\\\[^\\/\s]+[\\/][^\s"\x27`<>]+',
    multiLine: true,
  );
  static final RegExp _slashUncPattern = RegExp(
    r'(?:^|[\s"\x27`(=\[\]{},])//[^/\s:]+/[^\s"\x27`<>]+',
    multiLine: true,
  );
  static final RegExp _unixPathPattern = RegExp(
    r'(?:^|[^A-Za-z0-9])/(?:Users|home|root|srv|var|tmp|opt|etc|mnt|media|Volumes|workspace|workspaces|usr|bin|sbin|lib|lib64|dev|run|proc|sys|boot|data|storage|sdcard)(?:/[^\s"\x27`<>]*)?',
    caseSensitive: false,
    multiLine: true,
  );

  // 赋值右侧是引用或表达式而不是字面量，取到的是名字不是密钥本身。
  static final RegExp _referenceValuePattern = RegExp(
    r'^(?:[$%<{\[]|[A-Za-z_][\w.]*\s*[(\[]|process\.env\b|Deno\.env\b)',
    caseSensitive: false,
  );
  static final RegExp _placeholderValuePattern = RegExp(
    r'^(?:your[\w-]*|changeme|placeholder|todo|x{3,}|\*{3,}|\.{3,}|-{3,}'
    r'|(?:null|none|undefined|nil)$)',
    caseSensitive: false,
  );
  static final RegExp _valueTrimPattern = RegExp(
    '^["\x27]+|["\x27,;:)}\\]]+\$',
  );

  // 类型标注的右侧是类型名，不是密钥。
  static final RegExp _typeNameValuePattern = RegExp(
    r'^(?:str|string|int|integer|bool|boolean|bytes|float|double|number|'
    r'any|object|dict|map|list|array|text|self|cls|var|let|const|final)$',
    caseSensitive: false,
  );

  static final RegExp _bearerPattern = RegExp(
    r'\b(bearer)\s+(\S+)',
    caseSensitive: false,
  );
  static final RegExp _credentialAssignmentPattern = RegExp(
    r'\b((?:api[_-]?key|access[_-]?token|refresh[_-]?token|auth(?:orization)?|'
    r'password|passwd|client[_-]?secret|private[_-]?key|token|cookies?|'
    r'session(?:id|[_-]?(?:token|key))?))\b["\x27]?\s*[:=]\s*(\S+)',
    caseSensitive: false,
  );
  static final RegExp _cookieHeaderPattern = RegExp(
    r'\b(set-cookie|cookies?)\s*:\s*(\S+)',
    caseSensitive: false,
  );
  static final RegExp _secretAssignmentPattern = RegExp(
    r'\b(secret|credentials?)\b["\x27]?\s*[:=]\s*["\x27]?'
    r'([A-Za-z0-9_+/.=-]{8,})',
    caseSensitive: false,
  );

  static String _identity(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[_-]'), '');

  static bool _assignsLiteralSecret(String text, RegExp pattern) {
    for (final match in pattern.allMatches(text)) {
      final value = match.group(2)!.replaceAll(_valueTrimPattern, '');
      if (value.isEmpty ||
          _referenceValuePattern.hasMatch(value) ||
          _placeholderValuePattern.hasMatch(value) ||
          _typeNameValuePattern.hasMatch(value) ||
          // 值就是键自己的名字，说明传的是变量而不是字面量。
          _identity(value) == _identity(match.group(1)!)) {
        continue;
      }
      return true;
    }
    return false;
  }

  static String? detect(String value, {bool absolutePaths = true}) {
    if (RegExp(
      r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----',
      caseSensitive: false,
    ).hasMatch(value)) {
      return 'private key';
    }
    if (_assignsLiteralSecret(value, _bearerPattern)) {
      return 'authorization token';
    }
    if (_assignsLiteralSecret(value, _credentialAssignmentPattern) ||
        _assignsLiteralSecret(value, _cookieHeaderPattern) ||
        _assignsLiteralSecret(value, _secretAssignmentPattern)) {
      return 'credential';
    }
    if (RegExp(
      r'\b(?:pst-[A-Za-z0-9_-]{10,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|hf_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b',
    ).hasMatch(value)) {
      return 'credential';
    }
    if (RegExp(
      r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
    ).hasMatch(value)) {
      return 'credential';
    }
    if (absolutePaths && _containsAbsolutePath(value)) {
      return 'absolute path';
    }
    return null;
  }

  static String redactAbsolutePaths(String value) {
    var redacted = value;
    for (final pattern in [
      _fileUriPattern,
      _backslashUncPattern,
      _slashUncPattern,
      _windowsPathPattern,
      _unixPathPattern,
    ]) {
      redacted = redacted.replaceAllMapped(pattern, (match) {
        final text = match.group(0)!;
        final prefix = text.isNotEmpty && _isDelimiter(text.codeUnitAt(0))
            ? text[0]
            : '';
        return '$prefix[absolute path]';
      });
    }
    return redacted;
  }

  static bool isSensitiveSkillPath(String relativePath) {
    final segments = relativePath
        .replaceAll('\\', '/')
        .toLowerCase()
        .split('/');
    if (segments.any((part) => part == '.git' || part == 'node_modules')) {
      return true;
    }
    final name = segments.last;
    return name == '.env' ||
        name.startsWith('.env.') ||
        name == '.npmrc' ||
        name == '.pypirc' ||
        name == '.netrc' ||
        name == 'id_rsa' ||
        name == 'id_ed25519' ||
        name.endsWith('.pem') ||
        name.endsWith('.key') ||
        name.contains('credential') ||
        name.contains('secret') ||
        name.contains('token');
  }

  static void rejectPrivateText(
    String relativePath,
    Uint8List bytes, {
    bool allowAbsolutePaths = false,
  }) {
    late String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return;
    }
    final kind = detect(text, absolutePaths: !allowAbsolutePaths);
    if (kind != null) {
      throw FormatException('$relativePath contains a non-portable $kind.');
    }
  }

  static bool _containsAbsolutePath(String value) =>
      _fileUriPattern.hasMatch(value) ||
      _backslashUncPattern.hasMatch(value) ||
      _slashUncPattern.hasMatch(value) ||
      _windowsPathPattern.hasMatch(value) ||
      _unixPathPattern.hasMatch(value);

  static bool _isDelimiter(int codeUnit) =>
      !(codeUnit >= 0x30 && codeUnit <= 0x39) &&
      !(codeUnit >= 0x41 && codeUnit <= 0x5a) &&
      !(codeUnit >= 0x61 && codeUnit <= 0x7a);
}
