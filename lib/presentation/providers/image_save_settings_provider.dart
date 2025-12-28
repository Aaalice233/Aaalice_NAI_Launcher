import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'image_save_settings_provider.g.dart';

/// 图片保存设置状态
class ImageSaveSettings {
  /// 自定义保存路径（null 表示使用默认路径）
  final String? customPath;

  /// 是否自动保存
  final bool autoSave;

  const ImageSaveSettings({
    this.customPath,
    this.autoSave = false,
  });

  ImageSaveSettings copyWith({
    String? customPath,
    bool? autoSave,
    bool clearCustomPath = false,
  }) {
    return ImageSaveSettings(
      customPath: clearCustomPath ? null : (customPath ?? this.customPath),
      autoSave: autoSave ?? this.autoSave,
    );
  }

  /// 是否使用自定义路径
  bool get hasCustomPath => customPath != null && customPath!.isNotEmpty;

  /// 获取显示用的路径（自定义路径或"默认"）
  String getDisplayPath(String defaultLabel) {
    return hasCustomPath ? customPath! : defaultLabel;
  }
}

/// 图片保存设置 Notifier
@Riverpod(keepAlive: true)
class ImageSaveSettingsNotifier extends _$ImageSaveSettingsNotifier {
  @override
  ImageSaveSettings build() {
    final storage = ref.read(localStorageServiceProvider);
    return ImageSaveSettings(
      customPath: storage.getImageSavePath(),
      autoSave: storage.getAutoSaveImages(),
    );
  }

  /// 设置自定义保存路径
  Future<void> setCustomPath(String? path) async {
    final storage = ref.read(localStorageServiceProvider);
    if (path != null && path.isNotEmpty) {
      await storage.setImageSavePath(path);
      state = state.copyWith(customPath: path);
    } else {
      // 清除自定义路径，使用默认
      await storage.setImageSavePath('');
      state = state.copyWith(clearCustomPath: true);
    }
  }

  /// 重置为默认路径
  Future<void> resetToDefault() async {
    await setCustomPath(null);
  }

  /// 设置自动保存
  Future<void> setAutoSave(bool value) async {
    final storage = ref.read(localStorageServiceProvider);
    await storage.setAutoSaveImages(value);
    state = state.copyWith(autoSave: value);
  }

  /// 切换自动保存
  Future<void> toggleAutoSave() async {
    await setAutoSave(!state.autoSave);
  }
}
