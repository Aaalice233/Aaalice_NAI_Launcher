import 'dart:ui';

import '../../utils/app_locale.dart';

/// 按应用当前语言给出浏览器风格的 `accept-language` 取值。
String acceptLanguageForLocale(Locale locale) {
  if (isTraditionalChineseLocale(locale)) return 'zh-TW,zh;q=0.9';
  return switch (locale.languageCode) {
    'zh' => 'zh-CN,zh;q=0.9',
    'ja' => 'ja,en-US;q=0.9,en;q=0.8',
    _ => 'en-US,en;q=0.9',
  };
}
