import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_custom_dialog.dart';

void main() {
  testWidgets('custom assistant panel supports narrow, wide, 3x text and IME', (
    tester,
  ) async {
    for (final width in [320.0, 600.0, 840.0, 1600.0]) {
      const height = 900.0;
      final keyboardInset = width == 320 ? 320.0 : 0.0;
      await tester.binding.setSurfaceSize(Size(width, height));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(3),
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => PromptAssistantCustomDialog.show(
                  context: context,
                  currentPrompt: 'masterpiece, best quality',
                  allowImages: false,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(PromptAssistantCustomDialog), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');

      final requestField = find.byType(TextField, skipOffstage: false);
      expect(requestField, findsOneWidget, reason: 'field width=$width');
      await Scrollable.ensureVisible(
        requestField.evaluate().single,
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      final sheet = find.byWidgetPredicate(
        (widget) =>
            widget.key == const ValueKey('adaptive-full-screen-form') ||
            widget.key == const ValueKey('adaptive-centered-form') ||
            widget.key == const ValueKey('adaptive-centered-form') ||
            widget.key == const ValueKey('adaptive-bottom-sheet'),
      );
      final visibleField = tester
          .getRect(requestField)
          .intersect(tester.getRect(sheet));
      expect(visibleField.height, greaterThan(48), reason: 'width=$width');
      await tester.tapAt(visibleField.center);
      await tester.showKeyboard(requestField);
      await tester.enterText(requestField, 'Improve the lighting');
      await tester.pumpAndSettle();
      final run = find.widgetWithText(FilledButton, 'Run');
      await tester.ensureVisible(run);
      await tester.pumpAndSettle();
      expect(run, findsOneWidget);
      final visibleRun = tester.getRect(run).intersect(tester.getRect(sheet));
      expect(visibleRun.height, greaterThan(0), reason: 'Run width=$width');
      expect(tester.takeException(), isNull, reason: 'IME width=$width');

      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    await tester.binding.setSurfaceSize(null);
  });
}
