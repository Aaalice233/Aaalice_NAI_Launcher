import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/app_installation_service.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';

class _SupportedInstallationService extends AppInstallationService {
  @override
  bool get supportsInAppInstall => true;
}

void main() {
  group('UpdateInstallerService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nai_update_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('calculates and compares SHA256 checksums', () async {
      final file = File('${tempDir.path}/update.exe');
      await file.writeAsString('installer bytes');

      final hash = await UpdateInstallerService.calculateSha256(file);

      expect(
        hash,
        'e34210a6de4f653edf588301431c3d69a633638cbf587345cc50a7fed9f38f4c',
      );
      expect(
        UpdateInstallerService.equalsSha256(hash, hash.toUpperCase()),
        isTrue,
      );
      expect(UpdateInstallerService.equalsSha256(hash, 'bad'), isFalse);
    });

    test(
      'resumes a part file with Range and restores pending metadata',
      () async {
        final payload = List<int>.generate(128 * 1024, (index) => index % 251);
        final source = File('${tempDir.path}/source.bin');
        await source.writeAsBytes(payload);
        final hash = await UpdateInstallerService.calculateSha256(source);
        const fileName = 'resume-test.zip';
        final updateDir = Directory('${tempDir.path}/updates')..createSync();
        final partFile = File('${updateDir.path}/$fileName.part');
        const existingLength = 37 * 1024;
        await partFile.writeAsBytes(payload.take(existingLength).toList());

        final requests = <String?>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          requests.add(request.headers.value(HttpHeaders.rangeHeader));
          final range = request.headers.value(HttpHeaders.rangeHeader);
          final start = range == null
              ? 0
              : int.parse(range.substring('bytes='.length).split('-').first);
          request.response.statusCode = range == null
              ? HttpStatus.ok
              : HttpStatus.partialContent;
          request.response.headers.contentLength = payload.length - start;
          if (range != null) {
            request.response.headers.set(
              HttpHeaders.contentRangeHeader,
              'bytes $start-${payload.length - 1}/${payload.length}',
            );
          }
          request.response.add(payload.sublist(start));
          await request.response.close();
        });

        try {
          final asset = ReleaseAssetInfo(
            type: ReleaseAssetType.windowsPortable,
            platform: 'windows',
            fileName: fileName,
            downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
            sha256: hash,
            size: payload.length,
          );
          final versionInfo = VersionInfo(
            version: '9.9.9',
            currentVersion: '1.0.0',
            releaseNotes: 'resume test',
            primaryAsset: asset,
            assets: [asset],
            isNewer: true,
          );
          final service = UpdateInstallerService(
            dio: Dio(),
            installationService: _SupportedInstallationService(),
            updateDirectory: updateDir,
          );

          final downloaded = await service.downloadUpdate(versionInfo);

          expect(requests, ['bytes=$existingLength-']);
          expect(await downloaded.file.readAsBytes(), payload);
          expect(await partFile.exists(), isFalse);
          final restored = await service.restorePendingUpdate();
          expect(restored, isNotNull);
          expect(restored!.versionInfo.version, '9.9.9');
          expect(restored.update.file.path, downloaded.file.path);
        } finally {
          await server.close(force: true);
        }
      },
    );

    test('cancelling during checksum keeps the resumable part file', () async {
      final payload = List<int>.generate(64 * 1024, (index) => index % 251);
      final source = File('${tempDir.path}/checksum-source.bin');
      await source.writeAsBytes(payload);
      final hash = await UpdateInstallerService.calculateSha256(source);
      const fileName = 'checksum-cancel.zip';
      final updateDir = Directory('${tempDir.path}/updates')..createSync();
      final hashStarted = Completer<void>();
      final releaseHash = Completer<void>();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentLength = payload.length;
        request.response.add(payload);
        await request.response.close();
      });

      try {
        final asset = ReleaseAssetInfo(
          type: ReleaseAssetType.windowsPortable,
          platform: 'windows',
          fileName: fileName,
          downloadUrl: 'http://127.0.0.1:${server.port}/update.zip',
          sha256: hash,
          size: payload.length,
        );
        final versionInfo = VersionInfo(
          version: '9.9.9',
          currentVersion: '1.0.0',
          releaseNotes: 'checksum cancellation test',
          primaryAsset: asset,
          assets: [asset],
          isNewer: true,
        );
        final cancelToken = CancelToken();
        final service = UpdateInstallerService(
          dio: Dio(),
          installationService: _SupportedInstallationService(),
          updateDirectory: updateDir,
          sha256Calculator: (file) async {
            if (file.path.endsWith('.part')) {
              hashStarted.complete();
              await releaseHash.future;
            }
            return UpdateInstallerService.calculateSha256(file);
          },
        );

        final download = service.downloadUpdate(
          versionInfo,
          cancelToken: cancelToken,
        );
        await hashStarted.future;
        cancelToken.cancel('cancelled during checksum');
        releaseHash.complete();

        await expectLater(
          download,
          throwsA(isA<UpdateDownloadCancelledException>()),
        );
        expect(await File('${updateDir.path}/$fileName.part').exists(), isTrue);
        expect(await File('${updateDir.path}/$fileName').exists(), isFalse);
        expect(
          await File('${updateDir.path}/pending_update.json').exists(),
          isFalse,
        );
      } finally {
        await server.close(force: true);
      }
    });

    test('consumes updater result exactly once', () async {
      final updateDir = Directory('${tempDir.path}/updates')..createSync();
      final resultFile = File('${updateDir.path}/update_result.json');
      await resultFile.writeAsString('''
{"success":false,"version":"2.0.0","message":"access denied","logPath":"C:/update.log"}
''');
      final service = UpdateInstallerService(
        dio: Dio(),
        installationService: _SupportedInstallationService(),
        updateDirectory: updateDir,
      );

      final result = await service.consumeExecutionResult();

      expect(result, isNotNull);
      expect(result!.success, isFalse);
      expect(result.version, '2.0.0');
      expect(result.message, 'access denied');
      expect(await service.consumeExecutionResult(), isNull);
    });

    test(
      'starts updater in normal mode before shutting down the application',
      () async {
        final updateDir = Directory('${tempDir.path}/updates')..createSync();
        final installer = File('${updateDir.path}/setup.exe');
        await installer.writeAsString('verified installer');
        final hash = await UpdateInstallerService.calculateSha256(installer);
        final events = <String>[];
        String? executable;
        List<String>? arguments;
        ProcessStartMode? processMode;
        final service = UpdateInstallerService(
          dio: Dio(),
          installationService: _SupportedInstallationService(),
          updateDirectory: updateDir,
          processStarter: (command, commandArguments, mode) async {
            events.add('process');
            executable = command;
            arguments = commandArguments;
            processMode = mode;
          },
          shutdownHandler: (_) async {
            events.add('shutdown');
          },
        );
        final asset = ReleaseAssetInfo(
          type: ReleaseAssetType.windowsInstaller,
          platform: 'windows',
          fileName: 'setup.exe',
          downloadUrl: 'https://example.com/setup.exe',
          sha256: hash,
          size: await installer.length(),
        );

        await service.installAndRestart(
          DownloadedUpdate(file: installer, asset: asset, version: '1.8.2'),
        );

        expect(events, ['process', 'shutdown']);
        expect(executable, 'powershell.exe');
        expect(processMode, ProcessStartMode.normal);
        expect(arguments, containsAllInOrder(['-File']));
        expect(File(arguments!.last).existsSync(), isTrue);
      },
      skip: !Platform.isWindows,
    );

    test(
      'default process starter executes a hidden PowerShell script',
      () async {
        final marker = File('${tempDir.path}/updater-started.txt');
        final script = File('${tempDir.path}/updater-start-test.ps1');
        final escapedMarker = marker.path.replaceAll("'", "''");
        await script.writeAsString(
          "[System.IO.File]::WriteAllText('$escapedMarker', 'started')",
        );

        await startUpdateProcess('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-WindowStyle',
          'Hidden',
          '-File',
          script.path,
        ], ProcessStartMode.normal);

        final deadline = DateTime.now().add(const Duration(seconds: 15));
        while (!await marker.exists() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        expect(await marker.exists(), isTrue);
      },
      skip: !Platform.isWindows,
    );

    test(
      'does not shut down when the updater process cannot start',
      () async {
        final updateDir = Directory('${tempDir.path}/updates')..createSync();
        final installer = File('${updateDir.path}/setup.exe');
        await installer.writeAsString('verified installer');
        final hash = await UpdateInstallerService.calculateSha256(installer);
        var shutdownCalled = false;
        final service = UpdateInstallerService(
          dio: Dio(),
          installationService: _SupportedInstallationService(),
          updateDirectory: updateDir,
          processStarter: (_, _, _) async {
            throw const ProcessException('powershell.exe', [], 'blocked');
          },
          shutdownHandler: (_) async {
            shutdownCalled = true;
          },
        );
        final asset = ReleaseAssetInfo(
          type: ReleaseAssetType.windowsInstaller,
          platform: 'windows',
          fileName: 'setup.exe',
          downloadUrl: 'https://example.com/setup.exe',
          sha256: hash,
          size: await installer.length(),
        );

        await expectLater(
          service.installAndRestart(
            DownloadedUpdate(file: installer, asset: asset, version: '1.8.2'),
          ),
          throwsA(
            isA<UpdateInstallException>().having(
              (error) => error.message,
              'message',
              '启动更新程序失败',
            ),
          ),
        );
        expect(shutdownCalled, isFalse);
      },
      skip: !Platform.isWindows,
    );

    test('DownloadedUpdate identifies portable zip packages', () {
      const portableAsset = ReleaseAssetInfo(
        type: ReleaseAssetType.windowsPortable,
        platform: 'windows',
        fileName: 'update.zip',
        downloadUrl: 'https://example.com/update.zip',
      );
      const installerAsset = ReleaseAssetInfo(
        type: ReleaseAssetType.windowsInstaller,
        platform: 'windows',
        fileName: 'setup.exe',
        downloadUrl: 'https://example.com/setup.exe',
      );

      expect(
        DownloadedUpdate(
          file: File('update.zip'),
          asset: portableAsset,
          version: '1.0.0',
        ).isPortableZip,
        isTrue,
      );
      expect(
        DownloadedUpdate(
          file: File('setup.exe'),
          asset: installerAsset,
          version: '1.0.0',
        ).isPortableZip,
        isFalse,
      );
    });
  });
}
