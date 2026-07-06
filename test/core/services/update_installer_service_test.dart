import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';

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
  });
}
