import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_hover_motion.dart';

void main() {
  testWidgets('reduced motion keeps hover feedback geometry stable', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ImageCardHoverMotion(
            hovered: true,
            child: SizedBox(width: 120, height: 120),
          ),
        ),
      ),
    );

    final animatedScale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(animatedScale.scale, 1);
    expect(animatedScale.duration, Duration.zero);
  });

  testWidgets('disabled hover effects settle without a scrolling transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImageCardHoverMotion(
          hovered: true,
          enabled: false,
          child: SizedBox(width: 120, height: 120),
        ),
      ),
    );

    final animatedScale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(animatedScale.scale, 1);
    expect(animatedScale.duration, Duration.zero);
  });
}
