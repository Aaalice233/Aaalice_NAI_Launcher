import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/widgets/prompt_assistant_hover_icon.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('glyph glow follows button hover, reduceMotion=$reduceMotion', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: Center(
                child: PromptAssistantHoverIcon(
                  icon: Icons.auto_awesome_rounded,
                  size: 17,
                  buttonBuilder: (icon) => SizedBox.square(
                    dimension: 44,
                    child: IconButton(onPressed: () {}, icon: icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final glyph = find.byIcon(Icons.auto_awesome_rounded);
      final originalSize = tester.getSize(glyph);
      expect(tester.widget<Icon>(glyph).shadows, isNull);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final buttonRect = tester.getRect(find.byType(IconButton));
      await mouse.moveTo(buttonRect.topLeft + const Offset(4, 22));
      await tester.pump();
      final first = tester.widget<Icon>(glyph).shadows!;
      expect(first, hasLength(2));
      await tester.pump(const Duration(milliseconds: 700));
      final next = tester.widget<Icon>(glyph).shadows!;
      expect(
        next.last.blurRadius,
        reduceMotion
            ? first.last.blurRadius
            : greaterThan(first.last.blurRadius),
      );
      expect(tester.getSize(glyph), originalSize);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(tester.widget<Icon>(glyph).shadows, isNull);
      expect(tester.binding.hasScheduledFrame, false);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
