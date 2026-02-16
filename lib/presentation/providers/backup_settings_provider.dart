import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'backup_settings_provider.g.dart';

/// 备份设置状态
class BackupSettings {
  /// 是否启用自动备份
  final bool autoBackupEnabled;

  /// 自动备份间隔（小时）
  final int backupIntervalHours;

  const BackupSettings({
    this.autoBackupEnabled = false,
    this.backupIntervalHours = 24,
  });

  BackupSettings copyWith({
    bool? autoBackupEnabled,
    int? backupIntervalHours,
  }) {
    return BackupSettings(
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      backupIntervalHours: backupIntervalHours ?? this.backupIntervalHours,
    );
  }

  /// 获取备份间隔的显示文本
  String getIntervalDisplayText() {
    if (backupIntervalHours < 24) {
      return '$backupIntervalHours 小时';
    } else if (backupIntervalHours == 24) {
      return '每天';
    } else {
      final days = backupIntervalHours ~/ 24;
      return '$days 天';
    }
  }
}

/// 备份设置 Notifier
@Riverpod(keepAlive: true)
class BackupSettingsNotifier extends _$BackupSettingsNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  BackupSettings build() {
    return BackupSettings(
      autoBackupEnabled: _storage.getAutoBackupEnabled(),
      backupIntervalHours: _storage.getAutoBackupInterval(),
    );
  }

  /// 设置自动备份开关
  Future<void> setAutoBackupEnabled(bool value) async {
    await _storage.setAutoBackupEnabled(value);
    state = state.copyWith(autoBackupEnabled: value);
  }

  /// 切换自动备份开关
  Future<void> toggleAutoBackup() async {
    await setAutoBackupEnabled(!state.autoBackupEnabled);
  }

  /// 设置备份间隔（小时）
  Future<void> setBackupInterval(int hours) async {
    final clampedHours = hours.clamp(1, 168); // 限制在 1-168 小时
    await _storage.setAutoBackupInterval(clampedHours);
    state = state.copyWith(backupIntervalHours: clampedHours);
  }

  /// 重置为默认设置
  Future<void> resetToDefaults() async {
    await _storage.setAutoBackupEnabled(false);
    await _storage.setAutoBackupInterval(24);
    state = const BackupSettings();
  }
}
