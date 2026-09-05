import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/theme_extension.dart';
import 'package:nai_launcher/presentation/widgets/prompt/prompt_control_button.dart';

void main() {
  testWidgets('icon-only content retains a full touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: PromptControlButton(
              color: Colors.blue,
              active: false,
              padding: EdgeInsets.zero,
              onPressed: () {},
              builder: (_) => const Icon(Icons.push_pin, size: 16),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'keyboard activation and theme changes preserve the focused action',
    (tester) async {
      var calls = 0;
      Widget app(double radius) => MaterialApp(
        theme: ThemeData(
          extensions: [AppThemeExtension(controlRadius: radius)],
        ),
        home: Scaffold(
          body: PromptControlButton(
            color: Colors.blue,
            active: true,
            selected: true,
            padding: const EdgeInsets.all(8),
            onPressed: () => calls++,
            builder: (_) => const Text('正面提示词'),
          ),
        ),
      );
      await tester.pumpWidget(app(6));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(app(14));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, same(focus));
      final button = tester.widget<TextButton>(find.byType(TextButton));
      final shape =
          button.style!.shape!.resolve({WidgetState.focused})!
              as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(14));
      expect(
        button.style!.side!.resolve({WidgetState.focused})!.style,
        BorderStyle.solid,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      '$width: 3x text, short viewport, safe area and IME retain touch action',
      (tester) async {
        tester.view.physicalSize = Size(width, 320);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 320),
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.all(12),
                viewInsets: const EdgeInsets.only(bottom: 120),
              ),
              child: Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: PromptControlButton(
                        color: Colors.blue,
                        active: false,
                        padding: const EdgeInsets.all(8),
                        onPressed: () => calls++,
                        builder: (_) => const Text('固定词'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final target = find.byType(TextButton);
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
        expect(find.text('固定词'), findsOneWidget);
        final rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(12));
        expect(rect.right, lessThanOrEqualTo(width - 12));
        await tester.tap(target);
        await tester.pump();
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
