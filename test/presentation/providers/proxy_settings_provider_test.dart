import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/settings/proxy_settings.dart';
import 'package:nai_launcher/presentation/providers/proxy_settings_provider.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  ProviderContainer createContainer(MemoryLocalStorage storage) {
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('移动端默认不启用代理，桌面端保持启用', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );
    expect(
      createContainer(
        MemoryLocalStorage(),
      ).read(proxySettingsNotifierProvider).enabled,
      isFalse,
    );

    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    expect(
      createContainer(
        MemoryLocalStorage(),
      ).read(proxySettingsNotifierProvider).enabled,
      isTrue,
    );
  });

  test('移动端把 auto 模式折算成 manual 且不回写存储', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.proxyEnabled] = true
      ..values[StorageKeys.proxyMode] = 'auto'
      ..values[StorageKeys.proxyManualHost] = '127.0.0.1'
      ..values[StorageKeys.proxyManualPort] = 7890;

    final settings = createContainer(
      storage,
    ).read(proxySettingsNotifierProvider);

    expect(settings.mode, ProxyMode.manual);
    expect(settings.effectiveProxyAddress, '127.0.0.1:7890');
    expect(storage.values[StorageKeys.proxyMode], 'auto');
  });

  test('桌面端保留存储里的 auto 模式', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.proxyEnabled] = true
      ..values[StorageKeys.proxyMode] = 'auto';

    expect(
      createContainer(storage).read(proxySettingsNotifierProvider).mode,
      ProxyMode.auto,
    );
  });
}
