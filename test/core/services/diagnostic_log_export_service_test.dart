import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/diagnostic_log_export_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'diagnostic_log_export_service_test_',
    );
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      tempDirectory.path,
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('exports a ZIP with sanitized logs and diagnostics metadata', () async {
    final logFile = await File(p.join(tempDirectory.path, 'app.log'))
        .writeAsString(
          'Authorization: Basic dXNlcjpwYXNz\n'
          'Bearer secret-token-value\n'
          'api_key=secret-api-key\n'
          'Cookie: sessionid=live-session-secret\n'
          'cookie=raw-cookie-value session_key=raw-session-key\n'
          'unlabelled=ghp_12345678901234567890\n'
          '-----BEGIN PGP PRIVATE KEY BLOCK-----\n'
          'MIIEvQIBADANBgkqhkiG9w0BAQEFA\n'
          '-----END PGP PRIVATE KEY BLOCK-----\n'
          r'file=[C:\Users\Alice\private\image.png]'
          '\n'
          r'unc=[\\private-server\alice\secret.txt]'
          '\npaths=[//private-server/alice/secret.txt]\n'
          'paths=[/Users/Alice/private/image.png]\n'
          'file=/storage/emulated/0/DCIM/private/image.png\n'
          'request failed\n',
        );
    late Uint8List exportedBytes;
    var flushed = false;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => [logFile],
      loadCrashFiles: () async => const [],
      flushLogs: () async => flushed = true,
      exportArchive: (sourcePath, fileName, dialogTitle) async {
        expect(fileName, 'nai-launcher-diagnostics-20260221-123456.zip');
        expect(dialogTitle, 'Export logs');
        exportedBytes = await File(sourcePath).readAsBytes();
        return true;
      },
      now: () => DateTime(2026, 2, 21, 12, 34, 56),
      diagnosticsMetadata: () => 'app=test\nplatform=test',
    );

    final result = await service.export(dialogTitle: 'Export logs');

    expect(flushed, isTrue);
    expect(result.status, DiagnosticLogExportStatus.exported);
    final archive = ZipDecoder().decodeBytes(exportedBytes);
    expect(
      archive.files.map((file) => file.name),
      containsAll(['logs/app.log', 'diagnostics.json']),
    );
    final exportedLog = utf8.decode(
      archive.findFile('logs/app.log')!.content as List<int>,
    );
    expect(exportedLog, contains('request failed'));
    expect(exportedLog, contains('[absolute path]'));
    expect(exportedLog, isNot(contains('dXNlcjpwYXNz')));
    expect(exportedLog, isNot(contains('secret-token-value')));
    expect(exportedLog, isNot(contains('secret-api-key')));
    expect(exportedLog, isNot(contains('live-session-secret')));
    expect(exportedLog, isNot(contains('raw-cookie-value')));
    expect(exportedLog, isNot(contains('raw-session-key')));
    expect(exportedLog, isNot(contains('ghp_12345678901234567890')));
    expect(exportedLog, isNot(contains('MIIEvQIBADANBgkqhkiG9w0BAQEFA')));
    expect(exportedLog, isNot(contains(r'C:\Users\Alice')));
    expect(exportedLog, isNot(contains('private-server')));
    expect(exportedLog, isNot(contains('/Users/Alice')));
    expect(exportedLog, isNot(contains('/storage/emulated/0/DCIM')));
    expect(await logFile.readAsString(), contains('secret-api-key'));

    final metadata =
        jsonDecode(
              utf8.decode(
                archive.findFile('diagnostics.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(metadata['schemaVersion'], 1);
    expect(metadata['environment'], 'app=test\nplatform=test');
    expect(metadata['logs'], ['app.log']);
  });

  test('bounds exported bytes and keeps the newest tail of each log', () async {
    final newer = File(p.join(tempDirectory.path, 'app_newer.log'));
    final older = File(p.join(tempDirectory.path, 'app_older.log'));
    await newer.writeAsString(
      '${List.filled(5, 'NNNNNNNNNNNNNNNNNNNN').join('\n')}\nnewest-tail',
    );
    await older.writeAsString(
      '${List.filled(5, 'OOOOOOOOOOOOOOOOOOOO').join('\n')}\nolder-tail',
    );
    await newer.setLastModified(DateTime(2026, 2, 3));
    await older.setLastModified(DateTime(2026, 2, 2));

    late String archivePath;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => [older, newer],
      loadCrashFiles: () async => const [],
      flushLogs: () async {},
      exportArchive: (sourcePath, _, _) async {
        archivePath = p.join(tempDirectory.path, 'bounded.zip');
        await File(sourcePath).copy(archivePath);
        return true;
      },
      diagnosticsMetadata: () => 'app=test',
      maxPerFileBytes: 64,
      maxTotalSourceBytes: 96,
    );

    final result = await service.export(dialogTitle: 'Export');

    expect(result.status, DiagnosticLogExportStatus.exported);
    final archive = ZipDecoder().decodeBytes(
      await File(archivePath).readAsBytes(),
    );
    final newerLog = utf8.decode(
      archive.findFile('logs/app_newer.log')!.content as List<int>,
    );
    final olderLog = utf8.decode(
      archive.findFile('logs/app_older.log')!.content as List<int>,
    );
    expect(newerLog, startsWith('[OLDER LOG CONTENT OMITTED]'));
    expect(newerLog, endsWith('newest-tail\n'));
    expect(olderLog, startsWith('[OLDER LOG CONTENT OMITTED]'));
    expect(olderLog, endsWith('older-tail\n'));

    final metadata =
        jsonDecode(
              utf8.decode(
                archive.findFile('diagnostics.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(
      metadata['truncatedLogs'],
      containsAll(['app_newer.log', 'app_older.log']),
    );
  });

  test(
    'drops a partial first line before sanitizing a retained tail',
    () async {
      final source = File(p.join(tempDirectory.path, 'app_partial.log'));
      await source.writeAsString('password=super-secret-value\nsafe-line');

      late String archivePath;
      final service = DiagnosticLogExportService(
        loadLogFiles: () async => [source],
        loadCrashFiles: () async => const [],
        flushLogs: () async {},
        exportArchive: (sourcePath, _, _) async {
          archivePath = p.join(tempDirectory.path, 'partial-tail.zip');
          await File(sourcePath).copy(archivePath);
          return true;
        },
        diagnosticsMetadata: () => 'app=test',
        maxPerFileBytes: 20,
        maxTotalSourceBytes: 20,
      );

      await service.export(dialogTitle: 'Export');

      final archive = ZipDecoder().decodeBytes(
        await File(archivePath).readAsBytes(),
      );
      final exportedLog = utf8.decode(
        archive.findFile('logs/app_partial.log')!.content as List<int>,
      );
      expect(exportedLog, isNot(contains('secret-value')));
      expect(exportedLog, contains('safe-line'));
    },
  );

  test(
    'does not leak a private key when a retained tail starts inside it',
    () async {
      final source = File(p.join(tempDirectory.path, 'app_private_key.log'));
      await source.writeAsString(
        '${List.filled(30, '前').join()}\n'
        '-----BEGIN PGP PRIVATE KEY BLOCK-----\n'
        '${List.filled(120, 'K').join()}\n'
        '-----END PGP PRIVATE KEY BLOCK-----\n'
        'recent-safe-line',
      );

      late String archivePath;
      final service = DiagnosticLogExportService(
        loadLogFiles: () async => [source],
        loadCrashFiles: () async => const [],
        flushLogs: () async {},
        exportArchive: (sourcePath, _, _) async {
          archivePath = p.join(tempDirectory.path, 'private-key-tail.zip');
          await File(sourcePath).copy(archivePath);
          return true;
        },
        diagnosticsMetadata: () => 'app=test',
        maxPerFileBytes: 64,
        maxTotalSourceBytes: 64,
      );

      await service.export(dialogTitle: 'Export');

      final archive = ZipDecoder().decodeBytes(
        await File(archivePath).readAsBytes(),
      );
      final exportedLog = utf8.decode(
        archive.findFile('logs/app_private_key.log')!.content as List<int>,
      );
      expect(exportedLog, isNot(contains('KKKK')));
      expect(exportedLog, contains('recent-safe-line'));
    },
  );

  test(
    'startup cleanup removes only stale diagnostic export artifacts',
    () async {
      final exportDirectory = await Directory(
        p.join(tempDirectory.path, 'exports'),
      ).create();
      final oldArchive = await File(
        p.join(exportDirectory.path, '1_nai-launcher-diagnostics-old.zip'),
      ).writeAsString('old');
      final oldStaging = await Directory(
        '${oldArchive.path}.contents',
      ).create();
      final unrelated = await File(
        p.join(exportDirectory.path, 'other-export.zip'),
      ).writeAsString('keep');
      final now = DateTime.now().add(const Duration(days: 3));
      await oldArchive.setLastModified(now.subtract(const Duration(days: 2)));
      await unrelated.setLastModified(now.subtract(const Duration(days: 2)));

      await DiagnosticLogExportService.cleanupStaleTemporaryFiles(
        minimumAge: const Duration(days: 1),
        now: now,
      );

      expect(await oldArchive.exists(), isFalse);
      expect(await oldStaging.exists(), isFalse);
      expect(await unrelated.exists(), isTrue);
    },
  );

  test('does not open an exporter when there are no logs', () async {
    var exporterCalled = false;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => const [],
      loadCrashFiles: () async => const [],
      flushLogs: () async {},
      exportArchive: (sourcePath, fileName, dialogTitle) async {
        exporterCalled = true;
        return true;
      },
    );

    final result = await service.export(dialogTitle: 'Export logs');

    expect(result.status, DiagnosticLogExportStatus.noLogs);
    expect(exporterCalled, isFalse);
  });

  test('reports cancellation from the platform exporter', () async {
    final logFile = await File(
      p.join(tempDirectory.path, 'app.log'),
    ).writeAsString('safe log');
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => [logFile],
      loadCrashFiles: () async => const [],
      flushLogs: () async {},
      exportArchive: (sourcePath, fileName, dialogTitle) async => false,
      diagnosticsMetadata: () => 'test',
    );

    final result = await service.export(dialogTitle: 'Export logs');

    expect(result.status, DiagnosticLogExportStatus.cancelled);
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}
