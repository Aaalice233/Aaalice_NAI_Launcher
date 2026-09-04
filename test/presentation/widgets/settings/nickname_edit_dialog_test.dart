import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/settings/nickname_edit_dialog.dart';

void main() {
  final account = SavedAccount(
    id: 'account-1',
    email: 'alice@example.com',
    nickname: 'Alice',
    createdAt: DateTime(2025),
  );

  Widget testApp({
    required Widget home,
    TextScaler textScaler = TextScaler.noScaling,
    EdgeInsets viewInsets = EdgeInsets.zero,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          viewInsets: viewInsets,
          padding: padding,
          viewPadding: padding,
        ),
        child: child!,
      ),
      home: home,
    );
  }

  testWidgets('uses adaptive form presentation from 320 through wide panes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final width in [320.0, 600.0, 840.0, 1600.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => NicknameEditDialog.show(
                  context: context,
                  account: account,
                  onSave: (_) {},
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final presentation = width < 840
          ? find.byKey(const ValueKey('adaptive-bottom-sheet'))
          : find.byKey(const ValueKey('adaptive-centered-form'));
      expect(presentation, findsOneWidget, reason: 'width=$width');
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Cancel').hitTestable(), findsOneWidget);
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('keeps actions reachable with 3x text, SafeArea, and IME', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      testApp(
        textScaler: const TextScaler.linear(3),
        viewInsets: const EdgeInsets.only(bottom: 260),
        padding: const EdgeInsets.only(top: 20, bottom: 16),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => NicknameEditDialog.show(
                context: context,
                account: account,
                onSave: (_) {},
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final presentation = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(tester.getTopLeft(presentation).dy, greaterThanOrEqualTo(20));
    expect(tester.getBottomRight(presentation).dy, lessThanOrEqualTo(540));
    for (final label in ['Cancel', 'Save']) {
      await tester.scrollUntilVisible(
        find.text(label),
        120,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('nickname-edit-form-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('returns the trimmed nickname when saved', (tester) async {
    String? savedNickname;

    await tester.pumpWidget(
      testApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => NicknameEditDialog.show(
                context: context,
                account: account,
                onSave: (nickname) => savedNickname = nickname,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  New nickname  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedNickname, 'New nickname');
    expect(find.byType(NicknameEditDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
