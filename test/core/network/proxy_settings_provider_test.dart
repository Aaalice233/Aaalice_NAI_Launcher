import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/network/proxy_settings_provider.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/settings/proxy_settings.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  ProxySettings readSettings(MemoryLocalStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    );
    addTearDown(container.dispose);
    return container.read(proxySettingsNotifierProvider);
  }

  MemoryLocalStorage autoWithManualAddress() => MemoryLocalStorage()
    ..values[StorageKeys.proxyEnabled] = true
    ..values[StorageKeys.proxyMode] = 'auto'
    ..values[StorageKeys.proxyManualHost] = '127.0.0.1'
    ..values[StorageKeys.proxyManualPort] = 7890;

  test('移动端把 auto 折算成 manual，且不回写存储', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    final storage = autoWithManualAddress();

    final settings = readSettings(storage);

    expect(settings.mode, ProxyMode.manual);
    expect(settings.effectiveProxyAddress, '127.0.0.1:7890');
    expect(storage.values[StorageKeys.proxyMode], 'auto');
  });

  test('桌面端保留存储里的 auto 模式', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );

    expect(readSettings(autoWithManualAddress()).mode, ProxyMode.auto);
  });
}
