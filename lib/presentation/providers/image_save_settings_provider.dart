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
///
/// 保留 keepAlive: true 的原因：
/// 1. 全局功能 - 图片保存设置在整个应用生命周期中需要被访问
/// 2. 后台使用 - 图像生成完成后的自动保存操作需要访问此设置
/// 3. 跨页面访问 - 在设置页面、生成页面等多个页面中共享使用
/// 4. 状态一致性 - 自动保存开关状态需要在整个应用中保持一致
/// 5. 内存收益 - 仅存储简单配置（路径字符串和布尔值），内存占用极小
///
/// 此Provider管理图片保存的全局配置，包括自定义保存路径和自动保存开关。
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
