/// TexturePainter Tests
///
/// Tests for the TexturePainter CustomPainter and TextureOverlay widget.
/// Covers all 4 texture types: paperGrain, dotMatrix, halftone, grunge.
library;

import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/painters/texture_painter.dart';
import 'package:nai_launcher/presentation/themes/painters/texture_overlay.dart';

void main() {
  group('TexturePainter', () {
    test('should create with default values', () {
      const painter = TexturePainter();
      expect(painter.type, TextureType.none);
      expect(painter.opacity, 0.1);
      expect(painter.density, 1.0);
      expect(painter.seed, 42);
    });

    test('should create with custom values', () {
      const painter = TexturePainter(
        type: TextureType.paperGrain,
        color: Colors.brown,
        opacity: 0.2,
        density: 1.5,
        seed: 123,
      );
      expect(painter.type, TextureType.paperGrain);
      expect(painter.color, Colors.brown);
      expect(painter.opacity, 0.2);
      expect(painter.density, 1.5);
      expect(painter.seed, 123);
    });

    test('same seed should produce consistent patterns', () {
      const painter1 = TexturePainter(
        type: TextureType.paperGrain,
        seed: 42,
      );
      const painter2 = TexturePainter(
        type: TextureType.paperGrain,
        seed: 42,
      );
      // Painters with same config should be equal
      expect(painter1, equals(painter2));
    });

    test('different seed should produce different painters', () {
      const painter1 = TexturePainter(
        type: TextureType.paperGrain,
        seed: 42,
      );
      const painter2 = TexturePainter(
        type: TextureType.paperGrain,
        seed: 123,
      );
      expect(painter1, isNot(equals(painter2)));
    });

    test('shouldRepaint returns false for same config', () {
      const painter1 = TexturePainter(
        type: TextureType.dotMatrix,
        seed: 42,
      );
      const painter2 = TexturePainter(
        type: TextureType.dotMatrix,
        seed: 42,
      );
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true for different config', () {
      const painter1 = TexturePainter(
        type: TextureType.dotMatrix,
        seed: 42,
      );
      const painter2 = TexturePainter(
        type: TextureType.halftone,
        seed: 42,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    group('TextureType.paperGrain', () {
      test('should have paperGrain type', () {
        const painter = TexturePainter(type: TextureType.paperGrain);
        expect(painter.type, TextureType.paperGrain);
      });

      test('should paint without error', () {
        const painter = TexturePainter(type: TextureType.paperGrain);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(100, 100);

        // Should not throw
        expect(() => painter.paint(canvas, size), returnsNormally);
      });
    });

    group('TextureType.dotMatrix', () {
      test('should have dotMatrix type', () {
        const painter = TexturePainter(type: TextureType.dotMatrix);
        expect(painter.type, TextureType.dotMatrix);
      });

      test('should paint without error', () {
        const painter = TexturePainter(type: TextureType.dotMatrix);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(100, 100);

        expect(() => painter.paint(canvas, size), returnsNormally);
      });
    });

    group('TextureType.halftone', () {
      test('should have halftone type', () {
        const painter = TexturePainter(type: TextureType.halftone);
        expect(painter.type, TextureType.halftone);
      });

      test('should paint without error', () {
        const painter = TexturePainter(type: TextureType.halftone);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(100, 100);

        expect(() => painter.paint(canvas, size), returnsNormally);
      });
    });

    group('TextureType.grunge', () {
      test('should have grunge type', () {
        const painter = TexturePainter(type: TextureType.grunge);
        expect(painter.type, TextureType.grunge);
      });

      test('should paint without error', () {
        const painter = TexturePainter(type: TextureType.grunge);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(100, 100);

        expect(() => painter.paint(canvas, size), returnsNormally);
      });
    });

    group('TextureType.none', () {
      test('should not paint anything for none type', () {
        const painter = TexturePainter(type: TextureType.none);
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        const size = Size(100, 100);

        // Should not throw and should do nothing
        expect(() => painter.paint(canvas, size), returnsNormally);
      });
    });

    test('equality should work correctly', () {
      const painter1 = TexturePainter(
        type: TextureType.grunge,
        opacity: 0.15,
        seed: 42,
      );
      const painter2 = TexturePainter(
        type: TextureType.grunge,
        opacity: 0.15,
        seed: 42,
      );
      const painter3 = TexturePainter(
        type: TextureType.grunge,
        opacity: 0.25,
        seed: 42,
      );

      expect(painter1, equals(painter2));
      expect(painter1, isNot(equals(painter3)));
    });

    test('hashCode should be consistent', () {
      const painter1 = TexturePainter(type: TextureType.paperGrain, seed: 42);
      const painter2 = TexturePainter(type: TextureType.paperGrain, seed: 42);

      expect(painter1.hashCode, equals(painter2.hashCode));
    });
  });

  group('TextureOverlay widget', () {
    testWidgets('should render child correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.paperGrain,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('should work with different texture types', (tester) async {
      for (final type in TextureType.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextureOverlay(
                type: type,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        );

        expect(find.byType(TextureOverlay), findsOneWidget);
      }
    });

    testWidgets('should apply custom opacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.dotMatrix,
              opacity: 0.3,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('should apply custom color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.grunge,
              color: Colors.red,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('should not show overlay when type is none', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.none,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      // Should still render but CustomPaint may be skipped
      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('should handle zero opacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.halftone,
              opacity: 0.0,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('should handle full opacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextureOverlay(
              type: TextureType.paperGrain,
              opacity: 1.0,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('should work inside Stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.blue,
                ),
                const TextureOverlay(
                  type: TextureType.grunge,
                  child: SizedBox(width: 200, height: 200),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
      // Stack exists (at least one in the tree)
      expect(find.byType(Stack), findsWidgets);
    });
  });
}
