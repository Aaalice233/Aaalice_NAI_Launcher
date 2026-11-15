import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';

void main() {
  group('ReleaseAssetInfo', () {
    test('detects Windows installer asset', () {
      final asset = ReleaseAssetInfo.fromGitHubAsset({
        'name': 'NAI_Launcher_Windows_1.0.0-beta13+16_Setup.exe',
        'browser_download_url': 'https://example.com/setup.exe',
        'size': 123,
      });

      expect(asset.type, ReleaseAssetType.windowsInstaller);
      expect(asset.platform, 'windows');
      expect(asset.supportsInAppInstall, isTrue);
      expect(asset.typeId, 'windows-installer');
    });

    test('detects portable assets', () {
      final windowsAsset = ReleaseAssetInfo.fromGitHubAsset({
        'name': 'NAI_Launcher_Windows_1.0.0_Portable.zip',
        'browser_download_url': 'https://example.com/windows.zip',
      });
      final macosAsset = ReleaseAssetInfo.fromGitHubAsset({
        'name': 'NAI_Launcher_macOS_1.0.0_Portable.zip',
        'browser_download_url': 'https://example.com/macos.zip',
      });

      expect(windowsAsset.type, ReleaseAssetType.windowsPortable);
      expect(windowsAsset.supportsInAppInstall, isTrue);
      expect(macosAsset.type, ReleaseAssetType.macosPortable);
      expect(macosAsset.supportsInAppInstall, isFalse);
      expect(macosAsset.platform, 'macos');
    });

    test('detects Android APK as a verified system-installed update', () {
      final asset = ReleaseAssetInfo.fromGitHubAsset({
        'name': 'NAI_Launcher_Android_1.0.0+17.apk',
        'browser_download_url': 'https://example.com/launcher.apk',
        'size': 456,
      });

      expect(asset.type, ReleaseAssetType.androidApk);
      expect(asset.platform, 'android');
      expect(asset.abi, isNull);
      expect(asset.supportsInAppInstall, isTrue);
      expect(asset.typeId, 'android-apk');
      expect(asset.label, 'Android APK');
    });

    test('reads explicit abi from manifest and tolerates legacy manifest without abi', () {
      final splitAsset = ReleaseAssetInfo.fromManifestAsset({
        'platform': 'android',
        'type': 'android-apk',
        'abi': 'arm64-v8a',
        'fileName': 'NAI_Launcher_Android_4.4.0+47_arm64-v8a.apk',
        'downloadUrl': 'https://example.com/arm64.apk',
        'sha256': 'abc123',
        'size': 1024,
      });
      final legacyAsset = ReleaseAssetInfo.fromManifestAsset({
        'platform': 'android',
        'type': 'android-apk',
        'fileName': 'NAI_Launcher_Android_4.3.1+46.apk',
        'downloadUrl': 'https://example.com/legacy.apk',
        'sha256': 'def456',
        'size': 2048,
      });

      expect(splitAsset.abi, 'arm64-v8a');
      expect(splitAsset.label, 'Android APK (arm64-v8a)');
      expect(legacyAsset.abi, isNull);
      expect(legacyAsset.label, 'Android APK');
    });

    test('infers abi from split Android APK file names when manifest omits abi', () {
      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']) {
        final asset = ReleaseAssetInfo.fromManifestAsset({
          'platform': 'android',
          'type': 'android-apk',
          'fileName': 'NAI_Launcher_Android_4.4.0+47_$abi.apk',
          'downloadUrl': 'https://example.com/$abi.apk',
        });
        expect(asset.abi, abi);
        expect(asset.label, 'Android APK ($abi)');
      }

      expect(
        ReleaseAssetInfo.inferAbi(
          fileName: 'NAI_Launcher_Windows_4.4.0_x86_64_Setup.exe',
        ),
        isNull,
      );
    });

    test('merges manifest metadata with GitHub asset', () {
      final githubAsset = ReleaseAssetInfo.fromGitHubAsset({
        'name': 'NAI_Launcher_Windows_1.0.0_Setup.exe',
        'browser_download_url': 'https://example.com/setup.exe',
        'size': 123,
      });
      final asset = ReleaseAssetInfo.fromManifestAsset({
        'type': 'windows-installer',
        'fileName': 'NAI_Launcher_Windows_1.0.0_Setup.exe',
        'sha256': 'abc123',
        'description': '安装版',
      }, githubAsset: githubAsset);

      expect(asset.downloadUrl, githubAsset.downloadUrl);
      expect(asset.size, 123);
      expect(asset.sha256, 'abc123');
      expect(asset.description, '安装版');
    });
  });
}
