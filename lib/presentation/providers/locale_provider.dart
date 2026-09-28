import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../../core/utils/app_locale.dart';

part 'locale_provider.g.dart';

/// 语言设置 Notifier
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    // 从本地存储加载语言设置
    final storage = ref.read(localStorageServiceProvider);
    final code = storage.getLocaleCode();

    return appLocaleFromCode(code);
  }

  /// 设置语言
  Future<void> setLocale(String localeCode) async {
    state = appLocaleFromCode(localeCode);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setLocaleCode(appLocaleCode(state));
  }

  /// 切换语言
  Future<void> toggleLocale() async {
    final currentCode = appLocaleCode(state);
    final currentIndex = supportedAppLocaleCodes.indexOf(currentCode);
    final newCode =
        supportedAppLocaleCodes[(currentIndex + 1) %
            supportedAppLocaleCodes.length];
    await setLocale(newCode);
  }
}
