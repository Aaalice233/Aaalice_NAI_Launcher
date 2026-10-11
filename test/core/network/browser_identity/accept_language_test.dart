import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/browser_identity/accept_language.dart';

void main() {
  test('maps every supported app locale', () {
    expect(acceptLanguageForLocale(const Locale('zh')), 'zh-CN,zh;q=0.9');
    expect(
      acceptLanguageForLocale(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ),
      'zh-TW,zh;q=0.9',
    );
    expect(acceptLanguageForLocale(const Locale('en')), 'en-US,en;q=0.9');
    expect(
      acceptLanguageForLocale(const Locale('ja')),
      'ja,en-US;q=0.9,en;q=0.8',
    );
  });

  test('treats regional traditional Chinese as zh-TW', () {
    expect(
      acceptLanguageForLocale(const Locale('zh', 'TW')),
      'zh-TW,zh;q=0.9',
    );
    expect(
      acceptLanguageForLocale(const Locale('zh', 'HK')),
      'zh-TW,zh;q=0.9',
    );
  });

  test('falls back to English for unknown locales', () {
    expect(acceptLanguageForLocale(const Locale('de')), 'en-US,en;q=0.9');
  });
}
