import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../themes/app_theme.dart';

part 'theme_provider.g.dart';

/// 主题状态 Notifier
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  AppThemeType build() {
    // 从本地存储加载主题
    final storage = ref.read(localStorageServiceProvider);
    final index = storage.getThemeIndex();

    if (index >= 0 && index < AppThemeType.values.length) {
      return AppThemeType.values[index];
    }

    return AppThemeType.defaultStyle; // 默认主题
  }

  /// 设置主题
  Future<void> setTheme(AppThemeType type) async {
    state = type;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setThemeIndex(type.index);
  }

  /// 切换到下一个主题
  Future<void> nextTheme() async {
    final currentIndex = state.index;
    final nextIndex = (currentIndex + 1) % AppThemeType.values.length;
    await setTheme(AppThemeType.values[nextIndex]);
  }
}
