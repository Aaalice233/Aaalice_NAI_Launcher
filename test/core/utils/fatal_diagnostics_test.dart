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
          'token=raw-query-token api_key=raw-api-key password=raw-password\n'
          'Cookie: sessionid=raw-session-cookie\n'
          'cookie=raw-cookie-field session_key=raw-session-key\n'
          '-----BEGIN PGP PRIVATE KEY BLOCK-----\n'
          'raw-private-key-body\n'
          '-----END PGP PRIVATE KEY BLOCK-----',
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
      expect(content, isNot(contains('raw-session-cookie')));
      expect(content, isNot(contains('raw-cookie-field')));
      expect(content, isNot(contains('raw-session-key')));
      expect(content, isNot(contains('raw-private-key-body')));
    },
  );

  test('truncates unusually large crash diagnostics', () async {
    await FatalDiagnostics.initialize(directory: tempDir);
    final oversized = List.filled(
      FatalDiagnostics.maxFileCharacters + 100,
      'x',
    ).join();

    final file = FatalDiagnostics.writeSync(
      oversized,
      StackTrace.empty,
      source: 'test',
      fatal: true,
    );

    expect(file, isNotNull);
    final content = await file!.readAsString();
    expect(content, contains('[TRUNCATED DIAGNOSTIC]'));
    expect(content.length, lessThan(FatalDiagnostics.maxFileCharacters + 100));
  });

  test('retains only recent bounded crash diagnostics', () async {
    final now = DateTime.now();
    for (var index = 0; index < 22; index++) {
      final file = await File(
        '${tempDir.path}${Platform.pathSeparator}fatal_$index.log',
      ).writeAsString('diagnostic $index');
      await file.setLastModified(now.subtract(Duration(minutes: index)));
    }
    final expired = await File(
      '${tempDir.path}${Platform.pathSeparator}unhandled_expired.log',
    ).writeAsString('expired');
    await expired.setLastModified(
      now.subtract(FatalDiagnostics.retention + const Duration(days: 1)),
    );

    await FatalDiagnostics.initialize(directory: tempDir);

    final retained = await tempDir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .toList();
    expect(retained, hasLength(FatalDiagnostics.maxStoredFiles));
    expect(await expired.exists(), isFalse);
  });
}
