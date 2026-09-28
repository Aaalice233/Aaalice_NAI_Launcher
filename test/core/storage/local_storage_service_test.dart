import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'local_storage_service_test_',
    );
    Hive.init(hiveDirectory.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });

  test('uses the V5 generation defaults when no preferences are stored', () {
    final storage = LocalStorageService();

    expect(storage.getDefaultModel(), ImageModels.animeDiffusionV5Full);
    expect(storage.getDefaultSteps(), 28);
    expect(storage.getDefaultScale(), 4.0);
    expect(storage.getDefaultSampler(), Samplers.kEulerAncestral);
  });

  test(
    'uses the selected model capability when steps are not stored',
    () async {
      final storage = LocalStorageService();

      await storage.setDefaultModel(ImageModels.animeDiffusionV45Full);
      expect(storage.getDefaultSteps(), 23);
      expect(storage.getDefaultScale(), 5.0);

      await storage.setDefaultModel(ImageModels.animeFull);
      expect(storage.getDefaultSteps(), 28);
      expect(storage.getDefaultScale(), 10.0);
    },
  );

  test('keeps explicitly stored generation preferences', () async {
    final storage = LocalStorageService();
    await storage.setDefaultModel(ImageModels.animeDiffusionV45Curated);
    await storage.setDefaultSteps(31);
    await storage.setDefaultScale(6.5);
    await storage.setDefaultSampler(Samplers.kDpmpp2sAncestral);

    expect(storage.getDefaultModel(), ImageModels.animeDiffusionV45Curated);
    expect(storage.getDefaultSteps(), 31);
    expect(storage.getDefaultScale(), 6.5);
    expect(storage.getDefaultSampler(), Samplers.kDpmpp2sAncestral);
  });

  test('prerelease updates are disabled when no preference is stored', () {
    final storage = LocalStorageService();

    expect(storage.getIncludePrereleaseUpdates(), isFalse);
    expect(
      Hive.box(
        StorageKeys.settingsBox,
      ).containsKey(StorageKeys.includePrereleaseUpdates),
      isFalse,
    );
  });

  test('keeps the stored prerelease update preference', () async {
    final storage = LocalStorageService();

    await storage.setIncludePrereleaseUpdates(true);
    final restoredStorage = LocalStorageService();
    expect(restoredStorage.getIncludePrereleaseUpdates(), isTrue);

    await restoredStorage.setIncludePrereleaseUpdates(false);
    expect(storage.getIncludePrereleaseUpdates(), isFalse);
  });

  group('配置导出/导入', () {
    test('导出文档带格式版本与导出时间，正文是扁平的设置 Map', () async {
      final storage = LocalStorageService();
      await storage.setDefaultSteps(31);

      final document = storage.buildSettingsExportDocument();

      expect(document[SettingsExportFile.versionField], 1);
      expect(
        DateTime.tryParse(
          document[SettingsExportFile.exportedAtField] as String,
        ),
        isNotNull,
      );
      final payload =
          document[SettingsExportFile.payloadField] as Map<String, dynamic>;
      expect(payload[StorageKeys.defaultSteps], 31);
    });

    test('解析同时支持带信封的新格式与 ios-v2 的扁平旧格式', () {
      final storage = LocalStorageService();
      final enveloped = LocalStorageService.parseSettingsExport(
        jsonEncode(storage.buildSettingsExportDocument()),
      );
      expect(enveloped.formatVersion, 1);
      expect(enveloped.isNewerThanSupported, isFalse);

      final legacy = LocalStorageService.parseSettingsExport(
        jsonEncode({StorageKeys.defaultSteps: 24}),
      );
      expect(legacy.formatVersion, 0);
      expect(legacy.settings[StorageKeys.defaultSteps], 24);

      final future = LocalStorageService.parseSettingsExport(
        jsonEncode({
          SettingsExportFile.versionField: 99,
          SettingsExportFile.payloadField: <String, dynamic>{},
        }),
      );
      expect(future.isNewerThanSupported, isTrue);
    });

    test('导入只写白名单内的键，白名单外的键原样保留', () async {
      final storage = LocalStorageService();
      await storage.setSetting(StorageKeys.windowWidth, 1280.0);

      final result = await storage.importSettings(
        <String, dynamic>{
          StorageKeys.defaultSteps: 33,
          StorageKeys.windowWidth: 4096.0,
          'some_key_from_a_newer_build': 'nope',
        },
        allowedKeys: const {StorageKeys.defaultSteps},
      );

      expect(result.importedKeys, [StorageKeys.defaultSteps]);
      expect(result.skippedKeys, [
        'some_key_from_a_newer_build',
        StorageKeys.windowWidth,
      ]);
      expect(storage.getDefaultSteps(), 33);
      // 窗口几何是设备本地值，不能被别的机器的备份覆盖
      expect(storage.getSetting<double>(StorageKeys.windowWidth), 1280.0);
    });
  });

  group('随机提示词工具入口的平台默认值', () {
    tearDown(() {
      PlatformCapabilities.debugOverride = null;
    });

    test('移动端默认隐藏，桌面端默认显示，显式设置优先', () async {
      final storage = LocalStorageService();

      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.iOS,
      );
      expect(storage.getShowRandomPromptTools(), isFalse);

      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.windows,
      );
      expect(storage.getShowRandomPromptTools(), isTrue);

      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.iOS,
      );
      await storage.setShowRandomPromptTools(true);
      expect(storage.getShowRandomPromptTools(), isTrue);
    });
  });
}
