import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../themes/app_theme.dart';

part 'theme_provider.g.dart';

/// 主题状态 Notifier
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  AppStyle build() {
    // 从本地存储加载主题
    final storage = ref.read(localStorageServiceProvider);
    final index = storage.getThemeIndex();

    if (index >= 0 && index < AppStyle.values.length) {
      return AppStyle.values[index];
    }

    return AppStyle.herdingStyle; // 默认风格 - herdi.ng 金黄深青
  }

  /// 设置主题
  Future<void> setTheme(AppStyle style) async {
    state = style;

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setThemeIndex(style.index);
  }

  /// 切换到下一个主题
  Future<void> nextTheme() async {
    final currentIndex = state.index;
    final nextIndex = (currentIndex + 1) % AppStyle.values.length;
    await setTheme(AppStyle.values[nextIndex]);
  }
}
