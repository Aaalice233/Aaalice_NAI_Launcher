import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/workflow_import_wizard.dart';

void main() {
  testWidgets('320dp、3x 字号、IME 和 SafeArea 下四步向导使用全屏入口', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _buildApp(
        size: const Size(320, 800),
        textScale: 3,
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
        viewInsets: const EdgeInsets.only(bottom: 220),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(panel, findsOneWidget);
    expect(find.byKey(const Key('workflow-import-step-label')), findsOneWidget);
    expect(find.textContaining('1'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);

    final panelRect = tester.getRect(panel);
    expect(panelRect.top, greaterThanOrEqualTo(24));
    expect(panelRect.bottom, lessThanOrEqualTo(580));
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏四步向导入口有界且系统返回保持取消语义', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildApp(
        size: const Size(1600, 900),
        textScale: 1,
        padding: EdgeInsets.zero,
        viewInsets: EdgeInsets.zero,
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThanOrEqualTo(600));
    expect(find.byType(WorkflowImportWizard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowImportWizard), findsNothing);
  });
}

Widget _buildApp({
  required Size size,
  required double textScale,
  required EdgeInsets padding,
  required EdgeInsets viewInsets,
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewInsets: viewInsets,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => WorkflowImportWizard.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
