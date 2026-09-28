import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Writes crash-startup diagnostics independently of the optional app log file.
class FatalDiagnostics {
  static const int maxStoredFiles = 20;
  static const int maxFileCharacters = 256 * 1024;
  static const Duration retention = Duration(days: 30);

  static Directory? _directory;

  static Future<void> initialize({Directory? directory}) async {
    final resolved = directory ?? await _resolveDefaultDirectory();
    await resolved.create(recursive: true);
    _directory = resolved;
    _prune(resolved, DateTime.now());
  }

  static File? writeSync(
    Object error,
    StackTrace stackTrace, {
    required String source,
    String? context,
    bool fatal = false,
    DateTime? timestamp,
  }) {
    try {
      final now = timestamp ?? DateTime.now();
      final dir = _directory ?? _fallbackDirectory();
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final prefix = fatal ? 'fatal' : 'unhandled';
      final file = File(
        path.join(dir.path, '${prefix}_${_formatTimestamp(now)}.log'),
      );
      final rawContent = [
        'timestamp: ${now.toIso8601String()}',
        'source: $source',
        'fatal: $fatal',
        if (context != null && context.isNotEmpty) 'context: $context',
        'errorType: ${error.runtimeType}',
        'error: $error',
        'stackTrace:',
        stackTrace.toString(),
        '',
      ].join('\n');
      final wasTruncated = rawContent.length > maxFileCharacters;
      final boundedContent = wasTruncated
          ? rawContent.substring(0, maxFileCharacters)
          : rawContent;
      final redactedContent = redactSensitiveText(boundedContent);
      final content = wasTruncated
          ? '$redactedContent\n[TRUNCATED DIAGNOSTIC]'
          : redactedContent;

      file.writeAsStringSync(content, encoding: utf8, flush: true);
      _prune(dir, now);
      return file;
    } catch (_) {
      // Crash reporting must never throw while handling an existing failure.
      return null;
    }
  }

  static Future<Directory> _resolveDefaultDirectory() async {
    final loggerDirectory = AppLogger.logDirectory;
    if (loggerDirectory != null && loggerDirectory.isNotEmpty) {
      return Directory(path.join(loggerDirectory, 'crash_diagnostics'));
    }

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      return Directory(
        path.join(
          documentsDir.path,
          'NAI_Launcher',
          'logs',
          'crash_diagnostics',
        ),
      );
    } catch (_) {
      // Path provider can fail before Flutter desktop services settle.
      return _fallbackDirectory();
    }
  }

  static Directory _fallbackDirectory() {
    return Directory(
      path.join(Directory.systemTemp.path, 'NAI_Launcher', 'crash_diagnostics'),
    );
  }

  static void _prune(Directory directory, DateTime now) {
    try {
      final files = directory
          .listSync(followLinks: false)
          .whereType<File>()
          .where((file) {
            final name = path.basename(file.path);
            return (name.startsWith('fatal_') ||
                    name.startsWith('unhandled_')) &&
                name.endsWith('.log');
          })
          .toList();
      files.sort(
        (left, right) =>
            right.lastModifiedSync().compareTo(left.lastModifiedSync()),
      );
      for (var index = 0; index < files.length; index++) {
        final file = files[index];
        final expired = now.difference(file.lastModifiedSync()) > retention;
        if (index >= maxStoredFiles || expired) {
          file.deleteSync();
        }
      }
    } on Object {
      // Diagnostic retention must never interfere with crash handling.
    }
  }

  static String _formatTimestamp(DateTime value) {
    return '${value.year}${_pad(value.month)}${_pad(value.day)}_'
        '${_pad(value.hour)}${_pad(value.minute)}${_pad(value.second)}_'
        '${value.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String redactSensitiveText(String text) {
    final secrets = <String>{};

    void collect(RegExp pattern, int group) {
      for (final match in pattern.allMatches(text)) {
        final value = match.group(group);
        if (value != null && value.length >= 4) {
          secrets.add(value);
        }
      }
    }

    collect(
      RegExp(
        r'\bauthorization\s*[:=]\s*(?:basic|bearer)\s+([^\s,;]+)',
        caseSensitive: false,
      ),
      1,
    );
    collect(
      RegExp(r'\bbearer\s+([A-Za-z0-9._~+/=-]{6,})', caseSensitive: false),
      1,
    );
    collect(
      RegExp(
        r'\b(token|api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret|private[_-]?key|cookies?|session(?:id|[_-]?(?:token|key))?)\s*[:=]\s*([^&\s,;}]+)',
        caseSensitive: false,
      ),
      2,
    );

    var redacted = text
        .replaceAll(
          RegExp(
            r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----.*?(?:-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----|$)',
            caseSensitive: false,
            dotAll: true,
          ),
          '[REDACTED PRIVATE KEY]',
        )
        .replaceAllMapped(
          RegExp(
            r'\b(?:set-cookie|cookies?)\s*:\s*[^\r\n]*',
            caseSensitive: false,
          ),
          (match) => '${match.group(0)!.split(':').first}: [REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'\bauthorization\s*[:=]\s*(?:(?:basic|bearer)\s+)?[^\s,;]+',
            caseSensitive: false,
          ),
          (match) {
            final raw = match.group(0)!;
            final separator = raw.contains(':') ? ':' : '=';
            final name = raw.split(RegExp(r'[:=]')).first.trim();
            return '$name$separator [REDACTED]';
          },
        )
        .replaceAllMapped(
          RegExp(r'\bbearer\s+[A-Za-z0-9._~+/=-]{6,}', caseSensitive: false),
          (_) => 'Bearer [REDACTED]',
        )
        .replaceAllMapped(
          RegExp(
            r'\b(token|api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret|client[_-]?secret|private[_-]?key|cookies?|session(?:id|[_-]?(?:token|key))?)\s*[:=]\s*[^&\s,;}]+',
            caseSensitive: false,
          ),
          (match) {
            final raw = match.group(0)!;
            final separator = raw.contains(':') ? ':' : '=';
            final name = raw.split(RegExp(r'[:=]')).first.trim();
            return '$name$separator [REDACTED]';
          },
        )
        .replaceAll(
          RegExp(
            r'\b(?:pst-[A-Za-z0-9_-]{10,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|hf_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b',
          ),
          '[REDACTED]',
        )
        .replaceAll(
          RegExp(
            r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b',
          ),
          '[REDACTED]',
        );

    if (redacted.contains('://')) {
      redacted = redacted.replaceAllMapped(
        RegExp(
          r'([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^@\s/]+@',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}[REDACTED]@',
      );
    }

    for (final secret in secrets) {
      redacted = redacted.replaceAll(secret, '[REDACTED]');
    }

    return redacted;
  }
}
