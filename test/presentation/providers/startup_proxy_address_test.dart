import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/providers/startup_initialization_provider.dart';

void main() {
  late Directory hiveDir;
  late Box<dynamic> box;
  final android = PlatformCapabilities.forPlatform(TargetPlatform.android);

  setUpAll(() {
    hiveDir = Directory.systemTemp.createTempSync('startup_proxy_hive_');
    Hive.init(hiveDir.path);
  });

  setUp(() async {
    box = await Hive.openBox('startup_proxy', bytes: Uint8List(0));
  });

  tearDown(() async => box.close());

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 10));
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  test('移动端启用代理时使用手动地址，即使存储里是 auto', () async {
    await box.putAll({
      StorageKeys.proxyEnabled: true,
      StorageKeys.proxyMode: 'auto',
      StorageKeys.proxyManualHost: '192.168.1.2',
      StorageKeys.proxyManualPort: 7890,
    });

    expect(resolveStartupProxyAddress(box, android), '192.168.1.2:7890');
  });

  test('关闭代理或没有手动地址时不注入代理', () async {
    await box.putAll({
      StorageKeys.proxyEnabled: false,
      StorageKeys.proxyMode: 'manual',
      StorageKeys.proxyManualHost: '192.168.1.2',
      StorageKeys.proxyManualPort: 7890,
    });
    expect(resolveStartupProxyAddress(box, android), isNull);

    await box.clear();
    await box.put(StorageKeys.proxyEnabled, true);
    expect(resolveStartupProxyAddress(box, android), isNull);
  });
}
