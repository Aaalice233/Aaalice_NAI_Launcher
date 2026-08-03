import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/share_image_settings_provider.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('generation_cooldown_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  test('rejects starts until the configured interval has elapsed', () async {
    var now = DateTime.utc(2026, 7, 27, 12);
    final container = ProviderContainer(
      overrides: [generationCooldownClockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);

    final settings = container.read(shareImageSettingsProvider.notifier);
    await settings.setProtectionMode(true);
    await settings.setLimitGenerationInterval(true);
    await settings.setGenerationIntervalSeconds(10);

    final cooldown = container.read(generationCooldownProvider.notifier);
    expect(cooldown.tryStartGeneration(), isTrue);
    expect(container.read(generationCooldownProvider).remainingSeconds, 10);
    expect(cooldown.tryStartGeneration(), isFalse);

    now = now.add(const Duration(seconds: 9));
    expect(cooldown.tryStartGeneration(), isFalse);
    expect(container.read(generationCooldownProvider).remainingSeconds, 1);

    now = now.add(const Duration(seconds: 1));
    expect(cooldown.tryStartGeneration(), isTrue);
  });

  test('master switch and feature switch both gate the cooldown', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final settings = container.read(shareImageSettingsProvider.notifier);
    final cooldown = container.read(generationCooldownProvider.notifier);

    await settings.setGenerationIntervalSeconds(30);
    expect(cooldown.tryStartGeneration(), isTrue);
    expect(container.read(generationCooldownProvider).isActive, isFalse);

    await settings.setProtectionMode(true);
    expect(cooldown.tryStartGeneration(), isTrue);
    expect(container.read(generationCooldownProvider).isActive, isFalse);

    await settings.setLimitGenerationInterval(true);
    expect(cooldown.tryStartGeneration(), isTrue);
    expect(container.read(generationCooldownProvider).remainingSeconds, 30);
  });

  test('restores an active cooldown from storage', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final box = Hive.box(StorageKeys.settingsBox);
    await box.put(StorageKeys.protectionMode, true);
    await box.put(StorageKeys.protectionLimitGenerationInterval, true);
    await box.put(StorageKeys.protectionGenerationIntervalSeconds, 20);
    await box.put(
      StorageKeys.protectionLastGenerationStartedAt,
      now.subtract(const Duration(seconds: 7)).millisecondsSinceEpoch,
    );

    final container = ProviderContainer(
      overrides: [generationCooldownClockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);

    expect(container.read(generationCooldownProvider).remainingSeconds, 13);
  });

  test('image generation rejects a second start during cooldown', () async {
    final now = DateTime.utc(2026, 7, 27, 12);
    final container = ProviderContainer(
      overrides: [generationCooldownClockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);

    final settings = container.read(shareImageSettingsProvider.notifier);
    await settings.setProtectionMode(true);
    await settings.setLimitGenerationInterval(true);
    await settings.setGenerationIntervalSeconds(10);
    container.read(generationCooldownProvider.notifier).tryStartGeneration();

    await container
        .read(imageGenerationNotifierProvider.notifier)
        .generate(const ImageParams(prompt: '1girl'));

    expect(
      container.read(imageGenerationNotifierProvider).status,
      GenerationStatus.idle,
    );
  });
}
