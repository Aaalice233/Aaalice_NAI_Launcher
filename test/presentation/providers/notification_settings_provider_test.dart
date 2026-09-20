import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

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

  test('移动端默认关闭生成完成提示音，桌面端保持开启', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );
    expect(
      createContainer(
        MemoryLocalStorage(),
      ).read(notificationSettingsNotifierProvider).soundEnabled,
      isFalse,
    );

    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    expect(
      createContainer(
        MemoryLocalStorage(),
      ).read(notificationSettingsNotifierProvider).soundEnabled,
      isTrue,
    );
  });

  test('移动端上用户显式开启的提示音优先于平台默认值', () {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.notificationSoundEnabled] = true;

    expect(
      createContainer(
        storage,
      ).read(notificationSettingsNotifierProvider).soundEnabled,
      isTrue,
    );
  });
}
