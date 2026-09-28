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

    return AppStyle.grungeCollage; // 默认风格 - 拼贴朋克
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

  /// 在「默认深色（拼贴朋克）/ Bold Retro（浅色）」两套之间快速切换。
  ///
  /// 偏离上游：上游只有按 [AppStyle.values] 顺序轮转的 [nextTheme]，16 个主题
  /// 要按 15 次才能回到原处，手机上不可用。移动端「更多」面板的一键深浅快切
  /// 需要一个确定的两态切换：日常只在这两套之间来回换，其余主题仍走
  /// 外观 设置里的完整列表；当前处于其它主题时优先切到浅色。
  Future<void> toggleQuickTheme() async {
    await setTheme(
      state == AppStyle.boldRetro ? AppStyle.grungeCollage : AppStyle.boldRetro,
    );
  }
}
