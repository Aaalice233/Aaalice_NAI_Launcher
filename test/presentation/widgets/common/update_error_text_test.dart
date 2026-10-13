import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/update_error_text.dart';

void main() {
  Future<BuildContext> pumpLocale(WidgetTester tester, Locale locale) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  String describeInstall(BuildContext context, UpdateInstallFailure failure) =>
      describeUpdateError(
        context,
        UpdateState(status: UpdateStatus.error, installFailure: failure),
      );

  testWidgets('every install failure has its own text in every language', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final context = await pumpLocale(tester, locale);
      final texts = {
        for (final failure in UpdateInstallFailure.values)
          failure: describeInstall(context, failure),
      };

      for (final MapEntry(key: failure, value: text) in texts.entries) {
        expect(text.trim(), isNotEmpty, reason: '$locale $failure');
      }
      expect(
        texts.values.toSet(),
        hasLength(UpdateInstallFailure.values.length),
        reason: '$locale',
      );
    }
  });

  testWidgets('English install failures contain no Chinese text', (
    tester,
  ) async {
    final context = await pumpLocale(tester, const Locale('en'));
    final han = RegExp(r'\p{Script=Han}', unicode: true);

    for (final failure in UpdateInstallFailure.values) {
      expect(
        describeInstall(context, failure),
        isNot(matches(han)),
        reason: '$failure',
      );
    }
  });

  testWidgets('appends the updater log after the localized reason', (
    tester,
  ) async {
    final context = await pumpLocale(tester, const Locale('ja'));

    final text = describeUpdateError(
      context,
      const UpdateState(
        status: UpdateStatus.error,
        installFailure: UpdateInstallFailure.installFailed,
        errorLogPath: r'C:\Temp\update.log',
      ),
    );

    expect(
      text,
      '前回の更新はインストールされませんでした。もう一度試すか、'
      '新しいバージョンを手動でダウンロードしてインストールしてください。\n'
      r'ログ: C:\Temp\update.log',
    );
  });

  testWidgets('check failures keep their existing localized texts', (
    tester,
  ) async {
    final context = await pumpLocale(tester, const Locale('zh'));
    String describeCheck(UpdateCheckFailureType? failure) => describeUpdateError(
      context,
      UpdateState(status: UpdateStatus.error, checkFailureType: failure),
    );

    expect(
      describeCheck(UpdateCheckFailureType.rateLimited),
      '更新服务器请求繁忙，请稍后重试。',
    );
    expect(describeCheck(UpdateCheckFailureType.unknown), '暂时无法检查更新，请稍后重试。');
    expect(describeCheck(null), '暂时无法检查更新，请稍后重试。');
  });
}
