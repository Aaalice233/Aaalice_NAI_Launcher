import 'dart:ui';

const simplifiedChineseLocaleCode = 'zh';
const traditionalChineseLocaleCode = 'zh_Hant';
const supportedAppLocaleCodes = <String>[
  simplifiedChineseLocaleCode,
  traditionalChineseLocaleCode,
  'en',
  'ja',
];

Locale appLocaleFromCode(String code) {
  final normalized = code.replaceAll('-', '_').toLowerCase();
  if (normalized == 'zh_hant' ||
      normalized == 'zh_tw' ||
      normalized == 'zh_hk' ||
      normalized == 'zh_mo') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }
  if (normalized.startsWith('zh')) return const Locale('zh');
  if (normalized.startsWith('ja')) return const Locale('ja');
  return const Locale('en');
}

String appLocaleCode(Locale locale) {
  if (isTraditionalChineseLocale(locale)) return traditionalChineseLocaleCode;
  return locale.languageCode;
}

bool isTraditionalChineseLocale(Locale locale) {
  if (locale.languageCode != 'zh') return false;
  if (locale.scriptCode?.toLowerCase() == 'hant') return true;
  return const {'TW', 'HK', 'MO'}.contains(locale.countryCode?.toUpperCase());
}
