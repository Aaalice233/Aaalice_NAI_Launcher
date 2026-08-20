import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/right_panel.dart';

void main() {
  testWidgets('resize mode changes preserve the history panel state', (
    tester,
  ) async {
    final isResizing = ValueNotifier(false);
    addTearDown(isResizing.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 640,
              child: ValueListenableBuilder<bool>(
                valueListenable: isResizing,
                builder: (_, value, __) => RightPanel(isResizing: value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final initialState = tester.state(find.byType(HistoryPanel));
    expect(_panelContainer(tester).duration, const Duration(milliseconds: 200));

    isResizing.value = true;
    await tester.pump();
    expect(tester.state(find.byType(HistoryPanel)), same(initialState));
    expect(_panelContainer(tester).duration, Duration.zero);

    isResizing.value = false;
    await tester.pump();
    expect(tester.state(find.byType(HistoryPanel)), same(initialState));
    expect(_panelContainer(tester).duration, const Duration(milliseconds: 200));
  });
}

AnimatedContainer _panelContainer(WidgetTester tester) {
  return tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.byType(HistoryPanel),
      matching: find.byType(AnimatedContainer),
    ),
  );
}
