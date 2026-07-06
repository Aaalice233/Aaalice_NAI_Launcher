import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_error_reporter.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/core/utils/fatal_diagnostics.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('fatal_diagnostics_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'persists fatal diagnostics when normal file logging is disabled and redacts secrets',
    () async {
      await AppLogger.initialize(
        isTestEnvironment: true,
        enableFileLogging: false,
      );
      expect(AppLogger.fileLoggingEnabled, isFalse);

      await FatalDiagnostics.initialize(directory: tempDir);

      AppErrorReporter.reportError(
        Exception(
          'Authorization: Bearer raw-bearer-token '
          'token=raw-query-token api_key=raw-api-key password=raw-password',
        ),
        StackTrace.fromString('stack includes raw-bearer-token'),
        source: 'runZonedGuarded',
        context: 'startup token=raw-context-token',
        fatal: true,
      );

      final files = await tempDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();

      expect(files, hasLength(1));

      final content = await files.single.readAsString();
      expect(content, contains('source: runZonedGuarded'));
      expect(content, contains('fatal: true'));
      expect(content, contains('[REDACTED]'));
      expect(content, isNot(contains('raw-bearer-token')));
      expect(content, isNot(contains('raw-query-token')));
      expect(content, isNot(contains('raw-api-key')));
      expect(content, isNot(contains('raw-password')));
      expect(content, isNot(contains('raw-context-token')));
    },
  );
}
