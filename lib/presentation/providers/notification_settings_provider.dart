import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/services/notification_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_logger.dart';

part 'notification_settings_provider.g.dart';

/// 音效设置状态
class NotificationSettings {
  final bool soundEnabled;
  final String? customSoundPath;

  const NotificationSettings({this.soundEnabled = true, this.customSoundPath});

  NotificationSettings copyWith({
    bool? soundEnabled,
    String? customSoundPath,
    bool clearCustomSound = false,
  }) {
    return NotificationSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      customSoundPath: clearCustomSound
          ? null
          : (customSoundPath ?? this.customSoundPath),
    );
  }
}

/// 音效设置 Provider
@Riverpod(keepAlive: true)
class NotificationSettingsNotifier extends _$NotificationSettingsNotifier {
  @override
  NotificationSettings build() {
    final storage = ref.read(localStorageServiceProvider);
    return NotificationSettings(
      soundEnabled:
          storage.getSetting<bool>(
            StorageKeys.notificationSoundEnabled,
            defaultValue: true,
          ) ??
          true,
      customSoundPath: storage.getSetting<String>(
        StorageKeys.notificationCustomSoundPath,
      ),
    );
  }

  /// 设置音效开关
  Future<void> setSoundEnabled(bool value) async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setSetting(StorageKeys.notificationSoundEnabled, value);
    state = state.copyWith(soundEnabled: value);
  }

  /// 设置自定义音效路径。移动端会持久化文件选择器返回的临时缓存文件。
  Future<void> setCustomSoundPath(String? path) async {
    final storage = ref.read(localStorageServiceProvider);
    final previousPath = state.customSoundPath;
    if (path != null) {
      final persistedPath = await NotificationService.instance
          .persistCustomSound(path);
      try {
        await storage.setSetting(
          StorageKeys.notificationCustomSoundPath,
          persistedPath,
        );
        state = state.copyWith(customSoundPath: persistedPath);
      } catch (_) {
        await _deleteManagedSoundBestEffort(persistedPath);
        rethrow;
      }
      if (previousPath != persistedPath) {
        await _deleteManagedSoundBestEffort(previousPath);
      }
    } else {
      await storage.deleteSetting(StorageKeys.notificationCustomSoundPath);
      state = state.copyWith(clearCustomSound: true);
      await _deleteManagedSoundBestEffort(previousPath);
    }
  }

  Future<void> _deleteManagedSoundBestEffort(String? path) async {
    try {
      await NotificationService.instance.deleteManagedCustomSound(path);
    } catch (error, stackTrace) {
      AppLogger.w(
        'Failed to clean up a managed notification sound: $error',
        'NotificationSettings',
      );
      AppLogger.d('$stackTrace', 'NotificationSettings');
    }
  }
}
