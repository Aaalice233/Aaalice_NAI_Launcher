import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/auth/network_troubleshooting_dialog.dart';

void main() {
  for (final scenario in <({Size size, double scale, double keyboard})>[
    (size: const Size(320, 800), scale: 1, keyboard: 0),
    (size: const Size(320, 900), scale: 3, keyboard: 0),
    (size: const Size(599, 420), scale: 2, keyboard: 0),
    (size: const Size(700, 360), scale: 1, keyboard: 0),
    (size: const Size(840, 500), scale: 2, keyboard: 0),
    (size: const Size(1600, 900), scale: 1, keyboard: 0),
    (size: const Size(320, 800), scale: 1, keyboard: 300),
  ]) {
    testWidgets('adaptive tips and close stay reachable at ${scenario.size}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = scenario.size;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => NetworkTroubleshootingDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final surfaceKey = scenario.size.width >= 600
          ? 'adaptive-centered-form'
          : 'adaptive-bottom-sheet';
      expect(find.byKey(ValueKey(surfaceKey)), findsOneWidget);
      final tipsList = find.byKey(
        const Key('network-troubleshooting-tips-list'),
      );
      expect(tipsList, findsOneWidget);
      final tipsScrollable = find.descendant(
        of: tipsList,
        matching: find.byType(Scrollable),
      );
      expect(tipsScrollable, findsOneWidget);
      final controller = tester.widget<ListView>(tipsList).controller!;
      expect(controller.hasClients, isTrue);
      final serverStatus = find.text('Check Server Status');
      for (
        var step = 1;
        step <= 20 && serverStatus.evaluate().isEmpty;
        step++
      ) {
        controller.jumpTo(controller.position.maxScrollExtent * step / 20);
        await tester.pump();
      }
      expect(serverStatus, findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(serverStatus),
        alignment: 0.5,
      );
      await tester.pump();
      expect(serverStatus.hitTestable(), findsOne);

      final close = find.widgetWithText(TextButton, 'Close');
      expect(close.hitTestable(), findsOne);
      expect(tester.takeException(), isNull);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(surfaceKey)), findsNothing);
    });
  }
}
