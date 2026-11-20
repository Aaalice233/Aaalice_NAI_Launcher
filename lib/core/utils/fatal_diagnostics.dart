import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_logger.dart';
import 'log_redaction.dart';

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
      final redactedContent = redactLogText(boundedContent);
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
}
