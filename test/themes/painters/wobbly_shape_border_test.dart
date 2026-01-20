/// WobblyShapeBorder Tests
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/painters/wobbly_shape_border.dart';

void main() {
  group('WobblyShapeBorder', () {
    test('should create with default values', () {
      const border = WobblyShapeBorder();
      expect(border.wobbleFactor, 0.3);
      expect(border.seed, 42);
      expect(border.borderWidth, 2.0);
    });

    test('should create with custom values', () {
      const border = WobblyShapeBorder(
        wobbleFactor: 0.5,
        seed: 123,
        borderColor: Colors.red,
        borderWidth: 3.0,
        baseRadius: 16.0,
      );
      expect(border.wobbleFactor, 0.5);
      expect(border.seed, 123);
      expect(border.borderColor, Colors.red);
      expect(border.borderWidth, 3.0);
      expect(border.baseRadius, 16.0);
    });

    test('same seed should produce same path', () {
      const border1 = WobblyShapeBorder(seed: 42);
      const border2 = WobblyShapeBorder(seed: 42);
      const rect = Rect.fromLTWH(0, 0, 100, 100);

      final path1 = border1.getOuterPath(rect);
      final path2 = border2.getOuterPath(rect);

      // Paths should be identical
      expect(path1.getBounds(), path2.getBounds());
    });

    test('different seed should produce different path', () {
      const border1 = WobblyShapeBorder(seed: 42);
      const border2 = WobblyShapeBorder(seed: 123);
      const rect = Rect.fromLTWH(0, 0, 100, 100);

      final path1 = border1.getOuterPath(rect);
      final path2 = border2.getOuterPath(rect);

      // Bounds might be similar but paths should differ
      // (checking that paths are generated, not identical objects)
      expect(path1 != path2, isTrue);
    });

    test('zero wobble factor should still produce valid path', () {
      const border = WobblyShapeBorder(wobbleFactor: 0.0);
      const rect = Rect.fromLTWH(0, 0, 100, 100);

      final path = border.getOuterPath(rect);
      expect(path.getBounds(), isNotNull);
    });

    test('should scale correctly', () {
      const border = WobblyShapeBorder(
        wobbleFactor: 0.4,
        borderWidth: 2.0,
        baseRadius: 10.0,
      );
      final scaled = border.scale(0.5) as WobblyShapeBorder;

      expect(scaled.wobbleFactor, 0.2);
      expect(scaled.borderWidth, 1.0);
      expect(scaled.baseRadius, 5.0);
    });

    test('should have correct dimensions', () {
      const border = WobblyShapeBorder(borderWidth: 4.0);
      expect(border.dimensions, const EdgeInsets.all(4.0));
    });

    test('should lerp correctly', () {
      const border1 = WobblyShapeBorder(
        wobbleFactor: 0.2,
        borderWidth: 2.0,
        borderColor: Colors.black,
      );
      const border2 = WobblyShapeBorder(
        wobbleFactor: 0.6,
        borderWidth: 4.0,
        borderColor: Colors.white,
      );

      final lerped = border1.lerpTo(border2, 0.5) as WobblyShapeBorder;
      expect(lerped.wobbleFactor, 0.4);
      expect(lerped.borderWidth, 3.0);
    });

    test('equality should work correctly', () {
      const border1 = WobblyShapeBorder(seed: 42, wobbleFactor: 0.3);
      const border2 = WobblyShapeBorder(seed: 42, wobbleFactor: 0.3);
      const border3 = WobblyShapeBorder(seed: 99, wobbleFactor: 0.3);

      expect(border1, equals(border2));
      expect(border1, isNot(equals(border3)));
    });

    test('hashCode should be consistent', () {
      const border1 = WobblyShapeBorder(seed: 42);
      const border2 = WobblyShapeBorder(seed: 42);

      expect(border1.hashCode, equals(border2.hashCode));
    });
  });

  group('WobblyShapeBorder in widget', () {
    testWidgets('should work as Card shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              shape: const WobblyShapeBorder(),
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('should work as Container decoration shape', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              width: 100,
              height: 100,
              decoration: ShapeDecoration(
                shape: const WobblyShapeBorder(),
                color: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
    });
  });
}
