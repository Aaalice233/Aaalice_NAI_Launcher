import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/size_selector.dart';

void main() {
  testWidgets('shows a valid 64-grid suggestion for custom resolution', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizeSelector(width: 1080, height: 1920, onChanged: (_, _) {}),
        ),
      ),
    );

    expect(
      find.text(
        '1080×1920 无法用于生成。宽度和高度必须是 64 的倍数、单边不能超过 4096，且总像素'
        '不能超过 3,145,728。最接近的可用尺寸是 1088×1920。',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not warn for a valid 64-grid resolution', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizeSelector(width: 1088, height: 1920, onChanged: (_, _) {}),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('invalid-resolution-hint')), findsNothing);
  });
}
