import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_editor_resize_region.dart';

void main() {
  testWidgets('restored height is clamped without overwriting the preference', (
    tester,
  ) async {
    final writes = <double?>[];
    Widget app(double height) => _app(
      SizedBox(
        height: height,
        child: PromptEditorResizeRegion(
          enabled: true,
          initialHeight: 220,
          onHeightChanged: writes.add,
          builder: (manual) => TextField(maxLines: null, expands: manual),
        ),
      ),
    );
    await tester.pumpWidget(app(260));
    expect(tester.getSize(find.byType(TextField)).height, 220);
    await tester.pumpWidget(app(150));
    expect(tester.getSize(find.byType(TextField)).height, lessThan(150));
    await tester.pumpWidget(app(260));
    expect(tester.getSize(find.byType(TextField)).height, 220);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'drag preserves editor state and avoids rebuilding on each move',
    (tester) async {
      final controller = TextEditingController(text: 'cat, dog');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var builds = 0;
      await tester.pumpWidget(
        _app(
          PromptEditorResizeRegion(
            enabled: true,
            builder: (manual) {
              builds++;
              return TextField(
                controller: controller,
                focusNode: focus,
                minLines: manual ? null : 4,
                maxLines: null,
                expands: manual,
              );
            },
          ),
        ),
      );
      focus.requestFocus();
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pump();
      final state = tester.state(find.byType(EditableText));
      final originalHeight = tester.getSize(find.byType(TextField)).height;
      final handle = find.byKey(
        const ValueKey('generation-prompt-height-handle'),
      );
      final drag = await tester.startGesture(
        tester.getCenter(handle),
        kind: PointerDeviceKind.mouse,
      );
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      await drag.moveBy(const Offset(0, 80));
      await tester.pump();
      final afterStart = builds;
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(builds, afterStart);
      expect(
        tester.getSize(find.byType(TextField)).height,
        greaterThan(originalHeight + 60),
      );
      await drag.up();
      expect(identical(tester.state(find.byType(EditableText)), state), isTrue);
      expect(focus.hasFocus, isTrue);
      expect(controller.text, 'cat, dog');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 3),
      );

      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(handle);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.getSize(find.byType(TextField)).height, originalHeight);
      expect(identical(tester.state(find.byType(EditableText)), state), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'keyboard resize respects available height at all target widths',
    (tester) async {
      for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 400);
        await tester.pumpWidget(
          _app(
            PromptEditorResizeRegion(
              enabled: true,
              builder: (manual) => TextField(
                minLines: manual ? null : 1,
                maxLines: null,
                expands: manual,
              ),
            ),
            textScale: 3,
          ),
        );
        final handle = find.byKey(
          const ValueKey('generation-prompt-height-handle'),
        );
        Focus.of(tester.element(handle)).requestFocus();
        await tester.pump();
        for (var i = 0; i < 15; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
        }
        expect(tester.getRect(handle).bottom, lessThanOrEqualTo(280));
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 15; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pump();
        }
        expect(tester.getSize(find.byType(TextField)).height, 96);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(
          tester.widget<TextField>(find.byType(TextField)).expands,
          isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    },
  );
}

Widget _app(Widget child, {double textScale = 1}) => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      viewInsets: const EdgeInsets.only(bottom: 120),
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 24),
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Align(alignment: Alignment.topCenter, child: child),
  ),
);
