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
