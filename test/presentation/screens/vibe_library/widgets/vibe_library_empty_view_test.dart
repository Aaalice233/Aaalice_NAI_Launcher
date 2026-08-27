import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_library_empty_view.dart';

void main() {
  testWidgets('空库直接提供文件导入主操作', (tester) async {
    var importCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: VibeLibraryEmptyView(onImport: () => importCount++),
        ),
      ),
    );

    expect(find.text('可从文件导入，或从生成页面保存 Vibe'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '导入'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    expect(importCount, 1);
    expect(tester.takeException(), isNull);
  });
}
