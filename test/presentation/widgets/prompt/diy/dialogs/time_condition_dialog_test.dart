import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/time_condition_dialog.dart';

void main() {
  const condition = TimeCondition(
    id: 'test',
    name: 'Long time condition',
    startMonth: 1,
    startDay: 1,
    endMonth: 12,
    endDay: 31,
  );

  testWidgets('compact long form is full-screen and scrollable with IME', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.padding = const FakeViewPadding(
      top: 72,
      left: 24,
      right: 24,
      bottom: 72,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pump(
      tester,
      textScale: 3,
      child: const TimeConditionDialog(initialCondition: condition),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('time-condition-compact-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pump();
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded keeps a bounded centered dialog and all actions', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 900);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await _pump(
      tester,
      child: const TimeConditionDialog(initialCondition: condition),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('time-condition-expanded-content')),
          )
          .width,
      lessThanOrEqualTo(600),
    );
    final content = find.byKey(const ValueKey('time-condition-dialog'));
    expect(
      find.descendant(of: content, matching: find.byType(TextButton)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: content, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => TimeConditionDialog.show(
              context,
              initialCondition: (child as TimeConditionDialog).initialCondition,
              title: child.title,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
