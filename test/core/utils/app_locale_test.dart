import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_locale.dart';

void main() {
  test('creates and persists the Traditional Chinese locale', () {
    final locale = appLocaleFromCode(traditionalChineseLocaleCode);

    expect(locale.languageCode, 'zh');
    expect(locale.scriptCode, 'Hant');
    expect(appLocaleCode(locale), traditionalChineseLocaleCode);
  });

  test('recognizes Traditional Chinese region variants', () {
    expect(
      isTraditionalChineseLocale(
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
      ),
      isTrue,
    );
    expect(appLocaleFromCode('zh-TW').scriptCode, 'Hant');
    expect(isTraditionalChineseLocale(const Locale('zh')), isFalse);
  });
}
