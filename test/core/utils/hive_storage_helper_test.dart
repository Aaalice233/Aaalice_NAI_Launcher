import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/hive_storage_helper.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory documentsDir;
  late Directory supportDir;
  late Directory targetDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_startup_migration_');
    documentsDir = await Directory(
      p.join(tempDir.path, 'documents'),
    ).create(recursive: true);
    supportDir = await Directory(
      p.join(tempDir.path, 'app_data', 'publisher', 'app'),
    ).create(recursive: true);
    targetDir = await Directory(
      p.join(tempDir.path, 'target'),
    ).create(recursive: true);
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      documentsPath: documentsDir.path,
      supportPath: supportDir.path,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('首帧前只迁移 settings，其他 Hive 文件留给 Warmup', () async {
    final oldSettings = File(p.join(documentsDir.path, 'settings.hive'));
    final oldTagCache = File(p.join(documentsDir.path, 'tag_cache.hive'));
    await oldSettings.writeAsString('settings data');
    await oldTagCache.writeAsString('tag cache data');

    await HiveStorageHelper.instance.migrateSettingsFromOldLocation(
      targetDir.path,
    );

    expect(
      await File(p.join(targetDir.path, 'settings.hive')).readAsString(),
      'settings data',
    );
    expect(await oldSettings.exists(), isFalse);
    expect(await oldTagCache.exists(), isTrue);
    expect(
      await File(p.join(targetDir.path, 'tag_cache.hive')).exists(),
      isFalse,
    );
  });

  test('较新的目标文件内容不同时保留旧文件', () async {
    final oldSettings = File(p.join(documentsDir.path, 'settings.hive'));
    final targetSettings = File(p.join(targetDir.path, 'settings.hive'));
    await oldSettings.writeAsString('old settings');
    await targetSettings.writeAsString('new settings');
    await oldSettings.setLastModified(DateTime.utc(2020));
    await targetSettings.setLastModified(DateTime.utc(2021));

    await HiveStorageHelper.instance.migrateSettingsFromOldLocation(
      targetDir.path,
    );

    expect(await oldSettings.readAsString(), 'old settings');
    expect(await targetSettings.readAsString(), 'new settings');
  });
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({
    required this.documentsPath,
    required this.supportPath,
  });

  final String documentsPath;
  final String supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}
