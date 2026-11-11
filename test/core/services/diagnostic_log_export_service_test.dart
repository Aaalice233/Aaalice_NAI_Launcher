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
          'https://cdn.discordapp.com/attachments/111/222/image.png'
          '?ex=6a1b2c3d&is=6a1a0000&hm=0123456789abcdef#frag\n'
          'https://danbooru.donmai.us/posts.json'
          '?api_key=xyz&login=bob&tags=secret\n'
          'https://api.example.test/items?api_key=archive-fixture-key&limit=1 '
          'repeated archive-fixture-key\n'
          'https://legacy.example.test/posts.json'
          '?api_key= [REDACTED]&login=old-login&tags=old-tag#old-fragment '
          'status=429\n'
          'https://legacy.example.test/about?api_key= [REDACTED], status=401\n'
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
      loadUpdaterFiles: () async => const [],
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
    expect(
      exportedLog,
      contains('https://cdn.discordapp.com/attachments/111/222/image.png'),
    );
    expect(exportedLog, contains('https://danbooru.donmai.us/posts.json'));
    expect(
      exportedLog,
      contains('https://api.example.test/items repeated [REDACTED]\n'),
    );
    expect(exportedLog, isNot(contains('archive-fixture-key')));
    expect(
      exportedLog,
      contains('https://legacy.example.test/posts.json status=429\n'),
    );
    expect(
      exportedLog,
      contains('https://legacy.example.test/about, status=401\n'),
    );
    expect(exportedLog, isNot(contains('ex=')));
    expect(exportedLog, isNot(contains('hm=')));
    expect(exportedLog, isNot(contains('xyz')));
    expect(exportedLog, isNot(contains('bob')));
    expect(exportedLog, isNot(contains('secret')));
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

  Future<(String, String)> exportSanitized(
    String text, {
    String fileName = 'paths.log',
  }) async {
    final source = await File(
      p.join(tempDirectory.path, fileName),
    ).writeAsString(text);
    late Uint8List bytes;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => [source],
      loadCrashFiles: () async => const [],
      loadUpdaterFiles: () async => const [],
      loadAgentAuditFile: () async => null,
      loadMcpAuditFile: () async => null,
      flushLogs: () async {},
      diagnosticsMetadata: () => text,
      exportArchive: (path, _, _) async {
        bytes = await File(path).readAsBytes();
        return true;
      },
    );

    final result = await service.export(dialogTitle: 'Export');
    expect(result.status, DiagnosticLogExportStatus.exported);
    final archive = ZipDecoder().decodeBytes(bytes);
    final log = utf8.decode(
      archive.findFile('logs/$fileName')!.content as List<int>,
    );
    final metadata =
        jsonDecode(
              utf8.decode(
                archive.findFile('diagnostics.json')!.content as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(await source.readAsString(), text);
    return (log, metadata['environment'] as String);
  }

  group('export path redaction', () {
    final cases = <(String, String)>[
      (
        r'file=C:\Users\John Smith\OneDrive Personal\secret file.png done'
            '\n',
        'file=[absolute path]\n',
      ),
      (
        r'Deleted: C:\x.png (1/2)'
            '\n',
        'Deleted: [absolute path]\n',
      ),
      (
        r'C:\Users\Alice\private(2026)'
            '\n',
        '[absolute path]\n',
      ),
      (
        r'C:\Users\A B\private.v1 copy'
            '\n',
        '[absolute path]\n',
      ),
      (
        r'C:\Users\张 三\日本語 フォルダ\画像 名前.png'
            '\n',
        '[absolute path]\n',
      ),
      (
        r"FileSystemException: msg, path = 'C:\Users\A B\x.png' "
            '(OS Error: 拒绝访问。, errno = 5)\n',
        "FileSystemException: msg, path = '[absolute path]' "
            '(OS Error: 拒绝访问。, errno = 5)\n',
      ),
      (
        r"'C:\Users\O' Connor\a.png' done"
            '\n',
        "'[absolute path]' done\n",
      ),
      ('''"C:\\Users\\O'Connor\\a.png" done\n''', '"[absolute path]" done\n'),
      (
        r"`C:\Users\O'Connor\a.png` done"
            '\n',
        '`[absolute path]` done\n',
      ),
      (
        r'from "C:\Users\A B\x.png" to "D:\private folder\y.png" done'
            '\n',
        'from "[absolute path]" to "[absolute path]" done\n',
      ),
      (
        r'\\host\private share\name file.png'
            '\n',
        '[absolute path]\n',
      ),
      ('//host/private share/name file.png\n', '[absolute path]\n'),
      ('file:///C:/Users/A B/name file.png\n', '[absolute path]\n'),
      ('/home/A B/name file.png\n', '[absolute path]\n'),
      ('/private/var/folders/A B/a.png\n', '[absolute path]\n'),
      (
        '/Applications/Example App.app/Contents/MacOS/Example\n',
        '[absolute path]\n',
      ),
      ('/storage/emulated/0/private folder/a.png\n', '[absolute path]\n'),
      (
        r'file=C:\Users\A B\x.png done'
            '\nnext line stays\n',
        'file=[absolute path]\nnext line stays\n',
      ),
      (
        'GET https://host/Users/x 200 12:30 package:lib/a.dart\n',
        'GET https://host/Users/x 200 12:30 package:lib/a.dart\n',
      ),
      ('GET /users.json 404\n', 'GET /users.json 404\n'),
      (
        'file=/private/A B/a.png '
            'url=https://reader:pass@host/Users/x?tags=secret，状态码=429\n',
        'file=[absolute path] url=https://host/Users/x，状态码=429\n',
      ),
      (
        'Failed to persist cloud sync secret: PlatformException\n',
        'Failed to persist cloud sync secret: [REDACTED]\n',
      ),
      (
        r'"C:\Users\A B\x.png done'
            '\n',
        '"[absolute path]\n',
      ),
      (
        r'`C:\Users\A B\x.png done'
            '\n',
        '`[absolute path]\n',
      ),
      (
        r"'C:\Users\A B\x.png done"
            '\n',
        "'[absolute path]\n",
      ),
      (
        r"from 'C:\a.png' to 'D:\b.png' done"
            '\n',
        "from '[absolute path]' done\n",
      ),
      (
        'from "file:///C:/Users/A B/a.png" to "/home/A B/b.png" done\n',
        'from "[absolute path]" to "[absolute path]" done\n',
      ),
    ];
    for (var index = 0; index < cases.length; index++) {
      final (input, expected) = cases[index];
      test('sanitizes log and multiline metadata case $index', () async {
        final (log, environment) = await exportSanitized(input);
        expect(log, expected);
        expect(environment, expected);
      });
    }

    test(
      'preserves metadata line separators and a final unterminated line',
      () async {
        final (log, environment) = await exportSanitized(
          r'file=C:\Users\A B\x.png done'
          '\r\nnext line stays\rfinal line',
        );
        expect(log, 'file=[absolute path]\nnext line stays\nfinal line\n');
        expect(
          environment,
          'file=[absolute path]\r\nnext line stays\rfinal line',
        );
      },
    );

    test('redacts thousands of quoted paths in one line', () async {
      final input =
          '${List.generate(3000, (index) => '"C:\\Users\\A B\\$index.png" done').join(' | ')}\n';
      final expected =
          '${List.filled(3000, '"[absolute path]" done').join(' | ')}\n';
      final (log, environment) = await exportSanitized(input);
      expect(log, expected);
      expect(environment, expected);
    });
  });

  test(
    'redacts nested string values while preserving exported JSON types',
    () async {
      final (exported, _) = await exportSanitized(
        jsonEncode({
          'asset': {
            'downloadUrl':
                'https://host/package.zip?token=fixture-secret '
                'copy=fixture-secret',
            'token': 'opaque-fixture',
          },
          'details': [r'C:\QA\App Folder\installer.log', 15, false, null],
        }),
        fileName: 'pending_update.json',
      );
      expect(jsonDecode(exported), {
        'asset': {
          'downloadUrl': 'https://host/package.zip copy=[REDACTED]',
          'token': '[REDACTED SENSITIVE LOG LINE]',
        },
        'details': ['[absolute path]', 15, false, null],
      });
    },
  );

  test('uses line redaction for malformed JSON in the ZIP', () async {
    final (exported, _) = await exportSanitized(
      r'{"message":"C:\QA\App Folder'
      '\nnext line\n',
      fileName: 'update_incomplete.json',
    );
    expect(exported, '{"message":"[absolute path]\nnext line\n');
  });

  test(
    'exports only projected audit events from the support directory',
    () async {
      final agentDirectory = await Directory(
        p.join(tempDirectory.path, 'agent'),
      ).create();
      final audit = File(p.join(agentDirectory.path, 'audit-v1.jsonl'));
      await audit.writeAsString(
        '${jsonEncode({
          'id': 'call.secret-user-text.result',
          'timestamp': '2026-09-06T13:37:00Z',
          'result': 'allow',
          'summary': 'interrogate_image completed',
          'error': r'Lists and byte payloads are not allowed at $.references '
              'Bearer secret-token C:/Users/private/image.png private chat text',
          'messages': ['private chat text'],
          'image': 'private image bytes',
        })}\n{"partial":"secret-token',
      );
      await File(
        p.join(agentDirectory.path, 'session.jsonl'),
      ).writeAsString('private chat text');
      late Uint8List bytes;
      final service = DiagnosticLogExportService(
        loadLogFiles: () async => [],
        loadCrashFiles: () async => const [],
        loadUpdaterFiles: () async => const [],
        flushLogs: () async {},
        diagnosticsMetadata: () => 'test',
        exportArchive: (path, _, _) async {
          bytes = await File(path).readAsBytes();
          return true;
        },
      );
      expect(
        (await service.export(dialogTitle: 'Export')).status,
        DiagnosticLogExportStatus.exported,
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      expect(
        archive.files.map((file) => file.name),
        unorderedEquals(['logs/audit-v1.jsonl', 'diagnostics.json']),
      );
      final text = utf8.decode(
        archive.findFile('logs/audit-v1.jsonl')!.content as List<int>,
      );
      final records = const LineSplitter()
          .convert(text)
          .map(jsonDecode)
          .toList();
      expect(records.first['summary'], 'interrogate_image completed');
      expect(records.first['result'], 'allow');
      expect(records.first['errorCategory'], 'resource_reference');
      expect(records.last['diagnostic'], 'invalid_or_incomplete_audit_record');
      for (final secret in [
        'secret-user-text',
        'secret-token',
        'private',
        'messages',
      ]) {
        expect(text, isNot(contains(secret)));
      }
      expect(await audit.readAsString(), contains('secret-token'));
    },
  );

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
      loadUpdaterFiles: () async => const [],
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
        loadUpdaterFiles: () async => const [],
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
        loadUpdaterFiles: () async => const [],
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

  test('does not open an exporter when there are no logs', () async {
    var exporterCalled = false;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => const [],
      loadCrashFiles: () async => const [],
      loadUpdaterFiles: () async => const [],
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

  test('includes updater evidence and leaves update packages out', () async {
    final updateDirectory = Directory(
      p.join(tempDirectory.path, 'nai_launcher_updates'),
    )..createSync();
    await File(
      p.join(updateDirectory.path, 'update_4.2.1.log'),
    ).writeAsString('[2026-09-27] Installer exited with code 3.\n');
    await File(
      p.join(updateDirectory.path, 'update_result.json'),
    ).writeAsString(
      jsonEncode({
        'success': false,
        'version': '4.2.1',
        'message':
            r'Stdio proxy processes in C:\QA\App Folder did not exit within 15 seconds.',
        'logPath': r'C:\Users\Test User\AppData\Local\Temp\update_4.2.1.log',
      }),
    );
    await File(
      p.join(updateDirectory.path, 'update_started.json'),
    ).writeAsString('{"version":"4.2.1","appPid":1234}');
    // 同目录的安装包体积可达几百 MB，绝不能进诊断包。
    await File(
      p.join(updateDirectory.path, 'setup.exe'),
    ).writeAsBytes(List<int>.filled(4096, 7));
    await File(
      p.join(updateDirectory.path, 'setup.exe.part'),
    ).writeAsBytes(List<int>.filled(4096, 7));

    late Uint8List exportedBytes;
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => const [],
      loadCrashFiles: () async => const [],
      loadUpdaterFiles: () async => updateDirectory
          .listSync()
          .whereType<File>()
          .where(
            (file) => const {
              '.log',
              '.json',
            }.contains(p.extension(file.path)),
          )
          .toList(),
      flushLogs: () async {},
      exportArchive: (sourcePath, fileName, dialogTitle) async {
        exportedBytes = await File(sourcePath).readAsBytes();
        return true;
      },
      diagnosticsMetadata: () => 'test',
    );

    final result = await service.export(dialogTitle: 'Export logs');

    expect(result.status, DiagnosticLogExportStatus.exported);
    final archive = ZipDecoder().decodeBytes(exportedBytes);
    final names = archive.files.map((file) => file.name);
    expect(
      names,
      containsAll([
        'logs/update_4.2.1.log',
        'logs/update_result.json',
        'logs/update_started.json',
      ]),
    );
    expect(names, isNot(contains('logs/setup.exe')));
    expect(names, isNot(contains('logs/setup.exe.part')));
    final updateResult =
        jsonDecode(
              utf8.decode(
                archive.findFile('logs/update_result.json')!.content
                    as List<int>,
              ),
            )
            as Map<String, dynamic>;
    expect(updateResult['success'], isFalse);
    expect(updateResult['version'], '4.2.1');
    expect(
      updateResult['message'],
      'Stdio proxy processes in [absolute path] did not exit within 15 seconds.',
    );
    expect(updateResult['logPath'], '[absolute path]');
  });

  test('reports cancellation from the platform exporter', () async {
    final logFile = await File(
      p.join(tempDirectory.path, 'app.log'),
    ).writeAsString('safe log');
    final service = DiagnosticLogExportService(
      loadLogFiles: () async => [logFile],
      loadCrashFiles: () async => const [],
      loadUpdaterFiles: () async => const [],
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

  @override
  Future<String?> getApplicationSupportPath() async => temporaryPath;
}
