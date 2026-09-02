import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/color_panel.dart';

Widget _wrapPanel(
  EditorState state, {
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
      child: child!,
    ),
    home: Scaffold(body: ColorPanel(state: state)),
  );
}

void main() {
  testWidgets('320px, 3x text, and IME keep picker and actions reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = EditorState();
    addTearDown(state.dispose);

    await tester.pumpWidget(
      _wrapPanel(
        state,
        textScaler: const TextScaler.linear(3),
        viewInsets: const EdgeInsets.only(bottom: 200),
      ),
    );
    await tester.tap(find.byKey(const Key('color_panel_foreground_preview')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('color_picker_surface')), findsOneWidget);
    expect(find.byKey(const Key('color_picker_cancel')), findsOneWidget);
    expect(find.byKey(const Key('color_picker_confirm')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('color_picker_hex')),
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('color_picker_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    final hexRect = tester.getRect(find.byKey(const Key('color_picker_hex')));
    final confirmRect = tester.getRect(
      find.byKey(const Key('color_picker_confirm')),
    );
    expect(hexRect.top, greaterThanOrEqualTo(0));
    expect(hexRect.bottom, lessThanOrEqualTo(confirmRect.top));
    expect(confirmRect.bottom, lessThanOrEqualTo(600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('expanded picker is constrained to an adaptive side sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = EditorState();
    addTearDown(state.dispose);

    await tester.pumpWidget(_wrapPanel(state));
    await tester.tap(find.byKey(const Key('color_panel_foreground_preview')));
    await tester.pumpAndSettle();

    final sideSheet = find.byKey(const ValueKey('adaptive-side-sheet'));
    expect(sideSheet, findsOneWidget);
    expect(tester.getSize(sideSheet).width, lessThanOrEqualTo(440));
    expect(find.byKey(const Key('color_picker_confirm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
