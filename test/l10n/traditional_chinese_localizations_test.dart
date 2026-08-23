import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/l10n/app_localizations_zh.dart';

void main() {
  test('registers a complete Traditional Chinese localization', () {
    expect(
      AppLocalizations.supportedLocales.any(
        (locale) => locale.languageCode == 'zh' && locale.scriptCode == 'Hant',
      ),
      isTrue,
    );

    final l10n = AppLocalizationsZhHant();
    expect(l10n.app_title, 'NAI 啟動器');
    expect(l10n.settings_languageChinese, '簡體中文');
    expect(l10n.settings_languageTraditionalChinese, '繁體中文');
  });
}
