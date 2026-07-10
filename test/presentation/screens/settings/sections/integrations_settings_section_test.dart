import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/integrations_settings_section.dart';

void main() {
  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: IntegrationsSettingsSection(
            panelBuilders: [
              (_) => const Text('panel-prompt-assistant'),
              (_) => const Text('panel-comfyui'),
              (_) => const Text('panel-krita'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('默认显示第一个面板且三段可切换', (tester) async {
    await pumpSection(tester);

    // 三段子导航
    expect(find.text('Prompt Assistant'), findsOneWidget);
    expect(find.text('ComfyUI'), findsOneWidget);
    expect(find.text('Krita'), findsOneWidget);

    // 默认渲染第一个面板，且一次只渲染一个
    expect(find.text('panel-prompt-assistant'), findsOneWidget);
    expect(find.text('panel-comfyui'), findsNothing);

    await tester.tap(find.text('ComfyUI'));
    await tester.pumpAndSettle();
    expect(find.text('panel-comfyui'), findsOneWidget);
    expect(find.text('panel-prompt-assistant'), findsNothing);

    await tester.tap(find.text('Krita'));
    await tester.pumpAndSettle();
    expect(find.text('panel-krita'), findsOneWidget);
    expect(find.text('panel-comfyui'), findsNothing);
  });
}
