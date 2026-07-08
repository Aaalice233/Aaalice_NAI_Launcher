import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'generation_layout_mode_provider.g.dart';

/// 生成页布局模式
enum GenerationLayoutMode {
  /// 经典三栏布局
  classic,

  /// 官网式布局（提示词在最左栏）
  webStyle;

  /// 从存储值解析，未知值回落到 classic
  static GenerationLayoutMode fromStorageValue(String value) {
    return value == 'web_style'
        ? GenerationLayoutMode.webStyle
        : GenerationLayoutMode.classic;
  }

  /// 持久化存储值
  String get storageValue =>
      this == GenerationLayoutMode.webStyle ? 'web_style' : 'classic';
}

/// 生成页布局模式 Notifier
@riverpod
class GenerationLayoutModeNotifier extends _$GenerationLayoutModeNotifier {
  @override
  GenerationLayoutMode build() {
    final storage = ref.read(localStorageServiceProvider);
    return GenerationLayoutMode.fromStorageValue(
      storage.getGenerationLayoutMode(),
    );
  }

  /// 切换布局模式并持久化
  Future<void> setMode(GenerationLayoutMode mode) async {
    state = mode;
    final storage = ref.read(localStorageServiceProvider);
    await storage.setGenerationLayoutMode(mode.storageValue);
  }
}
