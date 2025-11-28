import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'locale_provider.g.dart';

/// 语言设置 Notifier
@riverpod
class LocaleNotifier extends _$LocaleNotifier {
  @override
  Locale build() {
    // 从本地存储加载语言设置
    final storage = ref.read(localStorageServiceProvider);
    final code = storage.getLocaleCode();

    return Locale(code);
  }

  /// 设置语言
  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);

    // 保存到本地存储
    final storage = ref.read(localStorageServiceProvider);
    await storage.setLocaleCode(languageCode);
  }

  /// 切换语言 (中/英)
  Future<void> toggleLocale() async {
    final currentCode = state.languageCode;
    final newCode = currentCode == 'zh' ? 'en' : 'zh';
    await setLocale(newCode);
  }
}
