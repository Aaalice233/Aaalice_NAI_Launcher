/// Painters Integration Tests
///
/// Integration tests for WobblyShapeBorder + TextureOverlay combination
/// and performance benchmarks for painters.
library;

import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/theme_modules.dart';
import 'package:nai_launcher/presentation/themes/painters/texture_overlay.dart';
import 'package:nai_launcher/presentation/themes/painters/texture_painter.dart';
import 'package:nai_launcher/presentation/themes/painters/wobbly_shape_border.dart';

void main() {
  group('Painters Integration', () {
    group('WobblyShapeBorder + TextureOverlay combination', () {
      testWidgets('should render Card with wobbly border and paper texture',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextureOverlay(
                  type: TextureType.paperGrain,
                  opacity: 0.1,
                  child: Card(
                    shape: const WobblyShapeBorder(
                      wobbleFactor: 0.3,
                      seed: 42,
                      borderWidth: 2.0,
                    ),
                    child: const SizedBox(width: 200, height: 150),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(TextureOverlay), findsOneWidget);
      });

      testWidgets('should render Container with grunge texture and wobbly decoration',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextureOverlay(
                  type: TextureType.grunge,
                  opacity: 0.15,
                  child: Container(
                    width: 200,
                    height: 150,
                    decoration: const ShapeDecoration(
                      shape: WobblyShapeBorder(
                        wobbleFactor: 0.4,
                        seed: 123,
                        borderColor: Color(0xFF2D2D2D),
                        borderWidth: 2.5,
                      ),
                      color: Color(0xFFFDFBF7),
                    ),
                    child: const Center(
                      child: Text('Hand-drawn style'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Container), findsWidgets);
        expect(find.byType(TextureOverlay), findsOneWidget);
        expect(find.text('Hand-drawn style'), findsOneWidget);
      });

      testWidgets('should handle nested TextureOverlays', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextureOverlay(
                type: TextureType.paperGrain,
                opacity: 0.05,
                child: Center(
                  child: TextureOverlay(
                    type: TextureType.dotMatrix,
                    opacity: 0.1,
                    child: const SizedBox(width: 200, height: 200),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.byType(TextureOverlay), findsNWidgets(2));
      });
    });

    group('withTexture extension method', () {
      testWidgets('should apply texture using extension', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const SizedBox(
                width: 100,
                height: 100,
              ).withTexture(
                TextureType.halftone,
                opacity: 0.2,
              ),
            ),
          ),
        );

        expect(find.byType(TextureOverlay), findsOneWidget);
      });
    });

    group('All texture types with WobblyShapeBorder', () {
      for (final textureType in TextureType.values) {
        testWidgets(
          'should render WobblyShapeBorder with ${textureType.name} texture',
          (tester) async {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: TextureOverlay(
                      type: textureType,
                      opacity: 0.1,
                      child: Container(
                        width: 150,
                        height: 100,
                        decoration: const ShapeDecoration(
                          shape: WobblyShapeBorder(),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            expect(find.byType(TextureOverlay), findsOneWidget);
          },
        );
      }
    });
  });

  group('Painter Performance', () {
    test('TexturePainter.paperGrain should paint efficiently', () {
      const painter = TexturePainter(
        type: TextureType.paperGrain,
        opacity: 0.1,
      );

      final stopwatch = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // Paint 10 times to get average
      for (int i = 0; i < 10; i++) {
        painter.paint(canvas, const Size(400, 300));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMicroseconds / 10;

      // Should paint in less than 16ms (60fps target) per frame
      // Actually targeting < 5ms for good margin
      expect(avgTime, lessThan(16000)); // 16ms in microseconds
    });

    test('TexturePainter.dotMatrix should paint efficiently', () {
      const painter = TexturePainter(
        type: TextureType.dotMatrix,
        opacity: 0.1,
      );

      final stopwatch = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      for (int i = 0; i < 10; i++) {
        painter.paint(canvas, const Size(400, 300));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMicroseconds / 10;

      expect(avgTime, lessThan(16000));
    });

    test('TexturePainter.halftone should paint efficiently', () {
      const painter = TexturePainter(
        type: TextureType.halftone,
        opacity: 0.1,
      );

      final stopwatch = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      for (int i = 0; i < 10; i++) {
        painter.paint(canvas, const Size(400, 300));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMicroseconds / 10;

      expect(avgTime, lessThan(16000));
    });

    test('TexturePainter.grunge should paint efficiently', () {
      const painter = TexturePainter(
        type: TextureType.grunge,
        opacity: 0.1,
      );

      final stopwatch = Stopwatch()..start();
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      for (int i = 0; i < 10; i++) {
        painter.paint(canvas, const Size(400, 300));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMicroseconds / 10;

      expect(avgTime, lessThan(16000));
    });

    test('WobblyShapeBorder should generate path efficiently', () {
      const border = WobblyShapeBorder(
        wobbleFactor: 0.3,
        seed: 42,
      );

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        border.getOuterPath(const Rect.fromLTWH(0, 0, 200, 150));
      }

      stopwatch.stop();
      final avgTime = stopwatch.elapsedMicroseconds / 100;

      // Path generation should be very fast (< 1ms)
      expect(avgTime, lessThan(1000)); // 1ms in microseconds
    });
  });

  group('Golden Tests (Visual Regression)', () {
    // Note: Golden tests require `flutter test --update-goldens` to generate
    // reference images. These tests document expected visual output.

    testWidgets('WobblyShapeBorder renders correctly', (tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: const ShapeDecoration(
                    shape: WobblyShapeBorder(
                      wobbleFactor: 0.3,
                      seed: 42,
                      borderColor: Color(0xFF2D2D2D),
                      borderWidth: 2.0,
                    ),
                    color: Color(0xFFFDFBF7),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Visual inspection placeholder - actual golden matching requires
      // generated reference files
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('TextureOverlay.paperGrain renders correctly', (tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: TextureOverlay(
                  type: TextureType.paperGrain,
                  color: const Color(0xFFE5E0D8),
                  opacity: 0.3,
                  seed: 42,
                  child: Container(
                    width: 200,
                    height: 200,
                    color: const Color(0xFFFDFBF7),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('TextureOverlay.grunge renders correctly', (tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: TextureOverlay(
                  type: TextureType.grunge,
                  color: const Color(0xFF1A1A1A),
                  opacity: 0.2,
                  seed: 42,
                  child: Container(
                    width: 200,
                    height: 200,
                    color: const Color(0xFFF0EAD6),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextureOverlay), findsOneWidget);
    });

    testWidgets('Hand-drawn card style (wobbly + paper)', (tester) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              backgroundColor: const Color(0xFFFDFBF7),
              body: Center(
                child: TextureOverlay(
                  type: TextureType.paperGrain,
                  color: const Color(0xFFE5E0D8),
                  opacity: 0.15,
                  seed: 42,
                  child: Container(
                    width: 250,
                    height: 180,
                    decoration: const ShapeDecoration(
                      shape: WobblyShapeBorder(
                        wobbleFactor: 0.35,
                        seed: 42,
                        borderColor: Color(0xFF2D2D2D),
                        borderWidth: 2.0,
                        baseRadius: 16.0,
                      ),
                      color: Colors.white,
                      shadows: [
                        BoxShadow(
                          color: Color(0xFF2D2D2D),
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'Hand-drawn Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hand-drawn Card'), findsOneWidget);
      expect(find.byType(TextureOverlay), findsOneWidget);
    });
  });
}
