import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/window_size_class.dart';

void main() {
  group('WindowSizeClass', () {
    test('uses Material width breakpoints', () {
      expect(WindowSizeClass.fromWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(599.9), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839.9), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
    });
  });

  testWidgets('metrics classify the safe usable width', (tester) async {
    late AdaptiveWindowMetrics metrics;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(620, 900),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        ),
        child: Builder(
          builder: (context) {
            metrics = context.adaptiveWindow;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(metrics.size, const Size(620, 900));
    expect(metrics.usableSize, const Size(588, 852));
    expect(metrics.sizeClass, WindowSizeClass.compact);
  });
}
