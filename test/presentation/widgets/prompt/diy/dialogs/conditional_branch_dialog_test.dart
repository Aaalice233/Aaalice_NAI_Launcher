import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/conditional_branch_dialog.dart';

void main() {
  testWidgets('compact uses a full-screen scroll view at 320dp, 3x and IME', (
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
      child: const ConditionalBranchDialog(
        initialConfig: ConditionalBranchConfig(id: 'test', name: 'Long form'),
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('conditional-branch-compact-scroll')),
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
      child: const ConditionalBranchDialog(
        initialConfig: ConditionalBranchConfig(id: 'test', name: 'Existing'),
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('conditional-branch-expanded-content')),
          )
          .width,
      lessThanOrEqualTo(600),
    );
    final content = find.byKey(const ValueKey('conditional-branch-dialog'));
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
            onPressed: () => ConditionalBranchDialog.show(
              context,
              initialConfig: (child as ConditionalBranchDialog).initialConfig,
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
