import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';

/// Writes crash-startup diagnostics independently of the optional app log file.
class FatalDiagnostics {
  static Directory? _directory;

  static Future<void> initialize({Directory? directory}) async {
    final resolved = directory ?? await _resolveDefaultDirectory();
    await resolved.create(recursive: true);
    _directory = resolved;
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
      final content = redactSensitiveText(
        [
          'timestamp: ${now.toIso8601String()}',
          'source: $source',
          'fatal: $fatal',
          if (context != null && context.isNotEmpty) 'context: $context',
          'errorType: ${error.runtimeType}',
          'error: $error',
          'stackTrace:',
          stackTrace.toString(),
          '',
        ].join('\n'),
      );

      file.writeAsStringSync(content, encoding: utf8, flush: true);
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
        r'\bauthorization\s*[:=]\s*bearer\s+([^\s,;]+)',
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
        r'\b(token|api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[:=]\s*([^&\s,;}]+)',
        caseSensitive: false,
      ),
      2,
    );

    var redacted = text
        .replaceAllMapped(
          RegExp(
            r'\bauthorization\s*[:=]\s*(bearer\s+)?[^\s,;]+',
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
            r'\b(token|api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[:=]\s*[^&\s,;}]+',
            caseSensitive: false,
          ),
          (match) {
            final raw = match.group(0)!;
            final separator = raw.contains(':') ? ':' : '=';
            final name = raw.split(RegExp(r'[:=]')).first.trim();
            return '$name$separator [REDACTED]';
          },
        );

    for (final secret in secrets) {
      redacted = redacted.replaceAll(secret, '[REDACTED]');
    }

    return redacted;
  }
}
