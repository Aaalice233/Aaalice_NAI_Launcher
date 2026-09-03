import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_confirm_dialog.dart';

void main() {
  testWidgets('long confirmation stays inside the safe viewport', (
    tester,
  ) async {
    final view = tester.view;
    view.devicePixelRatio = 3;
    view.physicalSize = const Size(960, 1704);
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
            viewInsets: const EdgeInsets.only(bottom: 240),
            textScaler: const TextScaler.linear(3),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => ThemedConfirmDialog.show(
              context: context,
              title: 'Confirmation',
              content:
                  'Long warning text. Long warning text. Long warning text. '
                  'Long warning text. Long warning text. Long warning text.',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    await tester.ensureVisible(find.text('Confirm'));
    await tester.pump();
    expect(find.text('Confirm').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warning confirmation uses an AA semantic color pair', (
    tester,
  ) async {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF345678))
        .copyWith(
          tertiary: const Color(0xFF6C4B16),
          tertiaryContainer: const Color(0xFF3B2608),
          onTertiaryContainer: const Color(0xFFFFFFFF),
        );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: const Scaffold(
          body: ThemedConfirmDialog(
            title: 'Warning',
            content: 'This action needs confirmation.',
            confirmText: 'Continue',
            cancelText: 'Cancel',
            type: ThemedConfirmDialogType.warning,
            icon: Icons.warning_rounded,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continue'),
    );
    final background = button.style!.backgroundColor!.resolve({})!;
    final foreground = button.style!.foregroundColor!.resolve({})!;
    expect(background, scheme.tertiaryContainer);
    expect(foreground, scheme.onTertiaryContainer);
    expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
  });

  testWidgets('dismissal restores focus to the opener', (tester) async {
    final openerFocus = FocusNode();
    addTearDown(openerFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              focusNode: openerFocus,
              autofocus: true,
              onPressed: () => ThemedConfirmDialog.show(
                context: context,
                title: 'Title',
                content: 'Content',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(openerFocus.hasFocus, isTrue);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(openerFocus.hasFocus, isTrue);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground
      : background;
  final darker = foreground == lighter ? background : foreground;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
