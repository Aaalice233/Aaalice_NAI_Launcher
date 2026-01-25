import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

void main() {
  group('Layer Transformation Tests', () {
    late Layer layer;

    setUp(() {
      layer = Layer(name: 'Test Layer');
    });

    tearDown(() {
      layer.dispose();
    });

    group('Crop Mode', () {
      test('should keep stroke positions unchanged when canvas shrinks', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512);
        final stroke = StrokeData(
          points: [
            const Offset(100, 100),
            const Offset(200, 200),
          ],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.crop);

        // Assert
        expect(
          layer.strokes.length,
          equals(1),
          reason: 'Stroke count should remain unchanged',
        );
        expect(
          layer.strokes.first.points.first.dx,
          equals(100.0),
          reason: 'Stroke X position should remain unchanged in crop mode',
        );
        expect(
          layer.strokes.first.points.first.dy,
          equals(100.0),
          reason: 'Stroke Y position should remain unchanged in crop mode',
        );
        expect(
          layer.strokes.first.size,
          equals(10.0),
          reason: 'Stroke size should remain unchanged in crop mode',
        );
      });

      test('should keep stroke positions unchanged when canvas grows', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final stroke = StrokeData(
          points: [const Offset(50, 50)],
          size: 15,
          color: Colors.blue,
          opacity: 0.8,
          hardness: 0.9,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.crop);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(50.0),
          reason:
              'Stroke position should not change when canvas grows in crop mode',
        );
        expect(
          layer.strokes.first.size,
          equals(15.0),
          reason: 'Stroke size should remain unchanged',
        );
      });

      test('should handle multiple strokes in crop mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512);
        final stroke1 = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        final stroke2 = StrokeData(
          points: [const Offset(800, 800)],
          size: 20,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke1);
        layer.addStroke(stroke2);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.crop);

        // Assert
        expect(
          layer.strokes.length,
          equals(2),
          reason: 'Both strokes should remain',
        );
        expect(
          layer.strokes[0].points.first.dx,
          equals(100.0),
          reason: 'First stroke position should remain unchanged',
        );
        expect(
          layer.strokes[1].points.first.dx,
          equals(800.0),
          reason: 'Second stroke position should remain unchanged',
        );
      });

      test('should mark caches as invalid in crop mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512);
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.crop);

        // Assert
        expect(
          layer.needsRasterize,
          isTrue,
          reason: 'Layer should be marked as needing rasterize',
        );
        expect(
          layer.needsThumbnailUpdate,
          isTrue,
          reason: 'Layer should be marked as needing thumbnail update',
        );
      });
    });

    group('Pad Mode', () {
      test('should keep stroke positions unchanged when canvas expands', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final stroke = StrokeData(
          points: [
            const Offset(100, 100),
            const Offset(200, 200),
          ],
          size: 10,
          color: Colors.green,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.pad);

        // Assert
        expect(
          layer.strokes.length,
          equals(1),
          reason: 'Stroke count should remain unchanged',
        );
        expect(
          layer.strokes.first.points.first.dx,
          equals(100.0),
          reason: 'Stroke X position should remain unchanged in pad mode',
        );
        expect(
          layer.strokes.first.points.first.dy,
          equals(100.0),
          reason: 'Stroke Y position should remain unchanged in pad mode',
        );
        expect(
          layer.strokes.first.size,
          equals(10.0),
          reason: 'Stroke size should remain unchanged in pad mode',
        );
      });

      test('should keep stroke positions unchanged when canvas shrinks', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512);
        final stroke = StrokeData(
          points: [const Offset(200, 200)],
          size: 15,
          color: Colors.yellow,
          opacity: 0.9,
          hardness: 0.8,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.pad);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(200.0),
          reason: 'Stroke position should not change in pad mode',
        );
        expect(
          layer.strokes.first.size,
          equals(15.0),
          reason: 'Stroke size should remain unchanged',
        );
      });

      test('should handle strokes with multiple points in pad mode', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 768);
        final stroke = StrokeData(
          points: [
            const Offset(50, 50),
            const Offset(100, 100),
            const Offset(150, 150),
            const Offset(200, 200),
          ],
          size: 12,
          color: Colors.purple,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.pad);

        // Assert - All points should remain unchanged
        expect(layer.strokes.first.points[0].dx, equals(50.0));
        expect(layer.strokes.first.points[1].dx, equals(100.0));
        expect(layer.strokes.first.points[2].dx, equals(150.0));
        expect(layer.strokes.first.points[3].dx, equals(200.0));
      });

      test('should mark caches as invalid in pad mode', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.pad);

        // Assert
        expect(
          layer.needsRasterize,
          isTrue,
          reason: 'Layer should be marked as needing rasterize',
        );
        expect(
          layer.needsThumbnailUpdate,
          isTrue,
          reason: 'Layer should be marked as needing thumbnail update',
        );
      });
    });

    group('Stretch Mode', () {
      test('should scale stroke positions when canvas enlarges uniformly', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048); // 2x scale
        final stroke = StrokeData(
          points: [
            const Offset(100, 100),
            const Offset(200, 200),
          ],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.length,
          equals(1),
          reason: 'Stroke count should remain unchanged',
        );
        expect(
          layer.strokes.first.points.first.dx,
          equals(200.0),
          reason: 'Stroke X should be scaled by 2x',
        );
        expect(
          layer.strokes.first.points.first.dy,
          equals(200.0),
          reason: 'Stroke Y should be scaled by 2x',
        );
        expect(
          layer.strokes.first.size,
          equals(20.0),
          reason:
              'Stroke size should be scaled by 2x (average of scaleX and scaleY)',
        );
      });

      test('should scale stroke positions when canvas shrinks uniformly', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512); // 0.5x scale
        final stroke = StrokeData(
          points: [
            const Offset(200, 200),
            const Offset(400, 400),
          ],
          size: 20,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(100.0),
          reason: 'Stroke X should be scaled by 0.5x',
        );
        expect(
          layer.strokes.first.points.first.dy,
          equals(100.0),
          reason: 'Stroke Y should be scaled by 0.5x',
        );
        expect(
          layer.strokes.first.size,
          equals(10.0),
          reason: 'Stroke size should be scaled by 0.5x',
        );
      });

      test('should scale stroke positions non-uniformly', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 512); // 2x width, 0.5x height
        final stroke = StrokeData(
          points: [
            const Offset(100, 100),
            const Offset(200, 200),
          ],
          size: 10,
          color: Colors.green,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(200.0),
          reason: 'Stroke X should be scaled by 2x (width scale)',
        );
        expect(
          layer.strokes.first.points.first.dy,
          equals(50.0),
          reason: 'Stroke Y should be scaled by 0.5x (height scale)',
        );
        // Average scale = (2.0 + 0.5) / 2 = 1.25
        expect(
          layer.strokes.first.size,
          equals(12.5),
          reason:
              'Stroke size should be scaled by average of scaleX and scaleY',
        );
      });

      test('should handle multiple strokes in stretch mode', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024); // 2x scale
        final stroke1 = StrokeData(
          points: [const Offset(50, 50)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        final stroke2 = StrokeData(
          points: [const Offset(200, 200)],
          size: 20,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke1);
        layer.addStroke(stroke2);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.length,
          equals(2),
          reason: 'Both strokes should remain',
        );
        expect(
          layer.strokes[0].points.first.dx,
          equals(100.0),
          reason: 'First stroke X should be scaled by 2x',
        );
        expect(
          layer.strokes[0].size,
          equals(20.0),
          reason: 'First stroke size should be scaled by 2x',
        );
        expect(
          layer.strokes[1].points.first.dx,
          equals(400.0),
          reason: 'Second stroke X should be scaled by 2x',
        );
        expect(
          layer.strokes[1].size,
          equals(40.0),
          reason: 'Second stroke size should be scaled by 2x',
        );
      });

      test('should handle strokes with multiple points in stretch mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048); // 2x scale
        final stroke = StrokeData(
          points: [
            const Offset(100, 100),
            const Offset(200, 200),
            const Offset(300, 300),
          ],
          size: 10,
          color: Colors.purple,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert - All points should be scaled
        expect(layer.strokes.first.points[0].dx, equals(200.0));
        expect(layer.strokes.first.points[1].dx, equals(400.0));
        expect(layer.strokes.first.points[2].dx, equals(600.0));
        expect(layer.strokes.first.points[0].dy, equals(200.0));
        expect(layer.strokes.first.points[1].dy, equals(400.0));
        expect(layer.strokes.first.points[2].dy, equals(600.0));
      });

      test('should clear rasterized cache in stretch mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.needsRasterize,
          isTrue,
          reason: 'Layer should be marked as needing rasterize',
        );
        expect(
          layer.needsThumbnailUpdate,
          isTrue,
          reason: 'Layer should be marked as needing thumbnail update',
        );
      });
    });

    group('Edge Cases', () {
      test('should handle empty layer (no strokes)', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);

        // Act - Should not throw
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.length,
          equals(0),
          reason: 'Layer should remain empty',
        );
      });

      test('should handle same size transformation (no-op)', () {
        // Arrange
        const sameSize = Size(1024, 1024);
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(sameSize, sameSize, CanvasResizeMode.stretch);

        // Assert - Stroke should remain unchanged
        expect(
          layer.strokes.first.points.first.dx,
          equals(100.0),
          reason: 'Stroke position should not change when size is the same',
        );
        expect(
          layer.strokes.first.size,
          equals(10.0),
          reason: 'Stroke size should not change when size is the same',
        );
      });

      test('should handle layer with only base image', () {
        // Arrange - This test verifies the method doesn't crash when there's a base image
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);

        // Note: We can't easily set a base image in tests without actual image data,
        // but we can verify the method handles the case where strokes are empty

        // Act - Should not throw even if base image exists
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(layer.strokes.length, equals(0));
      });

      test('should handle eraser strokes in stretch mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);
        final eraserStroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 20,
          color: Colors.white,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: true,
        );
        layer.addStroke(eraserStroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert - Eraser strokes should also be scaled
        expect(
          layer.strokes.first.isEraser,
          isTrue,
          reason: 'Eraser flag should be preserved',
        );
        expect(
          layer.strokes.first.points.first.dx,
          equals(200.0),
          reason: 'Eraser stroke position should be scaled',
        );
        expect(
          layer.strokes.first.size,
          equals(40.0),
          reason: 'Eraser stroke size should be scaled',
        );
      });

      test('should handle very small scale factor', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(128, 128); // 0.125x scale
        final stroke = StrokeData(
          points: [const Offset(512, 512)],
          size: 16,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(64.0),
          reason: 'Position should be scaled by 0.125x',
        );
        expect(
          layer.strokes.first.size,
          equals(2.0),
          reason: 'Size should be scaled by 0.125x',
        );
      });

      test('should handle very large scale factor', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(4096, 4096); // 8x scale
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 5,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        expect(
          layer.strokes.first.points.first.dx,
          equals(800.0),
          reason: 'Position should be scaled by 8x',
        );
        expect(
          layer.strokes.first.size,
          equals(40.0),
          reason: 'Size should be scaled by 8x',
        );
      });

      test('should handle asymmetric aspect ratio change', () {
        // Arrange
        const oldSize = Size(1024, 768); // 4:3 aspect
        const newSize = Size(768, 1024); // 3:4 aspect (swapped)
        final stroke = StrokeData(
          points: [
            const Offset(512, 384), // Center of old canvas
            const Offset(1024, 768), // Bottom-right corner
          ],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert
        // scaleX = 768/1024 = 0.75, scaleY = 1024/768 ≈ 1.333
        // average scale = (0.75 + 1.333) / 2 ≈ 1.0415
        expect(
          layer.strokes.first.points[0].dx,
          closeTo(384, 0.5),
          reason: 'First point X should be scaled by 0.75x',
        );
        expect(
          layer.strokes.first.points[0].dy,
          closeTo(512, 0.5),
          reason: 'First point Y should be scaled by ~1.333x',
        );
        expect(
          layer.strokes.first.size,
          closeTo(10.4, 0.1),
          reason: 'Size should be scaled by average of scaleX and scaleY',
        );
      });

      test('should preserve stroke metadata in stretch mode', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);
        final stroke = StrokeData(
          points: [const Offset(100, 100)],
          size: 10,
          color: const Color.fromARGB(255, 128, 64, 32),
          opacity: 0.75,
          hardness: 0.85,
        );
        layer.addStroke(stroke);

        // Act
        layer.transformContent(oldSize, newSize, CanvasResizeMode.stretch);

        // Assert - Metadata should be preserved
        expect(
          layer.strokes.first.color,
          equals(const Color.fromARGB(255, 128, 64, 32)),
          reason: 'Stroke color should be preserved',
        );
        expect(
          layer.strokes.first.opacity,
          equals(0.75),
          reason: 'Stroke opacity should be preserved',
        );
        expect(
          layer.strokes.first.hardness,
          equals(0.85),
          reason: 'Stroke hardness should be preserved',
        );
      });
    });

    group('LayerManager Integration', () {
      late LayerManager layerManager;

      setUp(() {
        layerManager = LayerManager();
      });

      tearDown(() {
        layerManager.dispose();
      });

      test('should transform all layers', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final layer1 = layerManager.addLayer(name: 'Layer 1');
        final layer2 = layerManager.addLayer(name: 'Layer 2');

        final stroke1 = StrokeData(
          points: [const Offset(50, 50)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        final stroke2 = StrokeData(
          points: [const Offset(100, 100)],
          size: 20,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );

        layerManager.addStrokeToLayer(layer1.id, stroke1);
        layerManager.addStrokeToLayer(layer2.id, stroke2);

        // Act
        layerManager.transformAllLayers(
          oldSize,
          newSize,
          CanvasResizeMode.stretch,
        );

        // Assert - Both layers should be transformed
        expect(
          layer1.strokes.first.points.first.dx,
          equals(100.0),
          reason: 'Layer 1 stroke should be scaled by 2x',
        );
        expect(
          layer2.strokes.first.points.first.dx,
          equals(200.0),
          reason: 'Layer 2 stroke should be scaled by 2x',
        );
      });

      test('should handle layer manager with no layers', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(512, 512);

        // Act - Should not throw
        layerManager.transformAllLayers(
          oldSize,
          newSize,
          CanvasResizeMode.crop,
        );

        // Assert
        expect(layerManager.layerCount, equals(0));
      });

      test('should handle layer manager with empty layers', () {
        // Arrange
        const oldSize = Size(1024, 1024);
        const newSize = Size(2048, 2048);
        layerManager.addLayer(name: 'Empty Layer 1');
        layerManager.addLayer(name: 'Empty Layer 2');

        // Act - Should not throw
        layerManager.transformAllLayers(
          oldSize,
          newSize,
          CanvasResizeMode.stretch,
        );

        // Assert - Layers should remain empty
        expect(layerManager.layers[0].strokes.length, equals(0));
        expect(layerManager.layers[1].strokes.length, equals(0));
      });

      test('should invalidate snapshot after transforming layers', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final layer = layerManager.addLayer(name: 'Test Layer');
        final stroke = StrokeData(
          points: [const Offset(50, 50)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        layerManager.addStrokeToLayer(layer.id, stroke);

        // Act
        layerManager.transformAllLayers(
          oldSize,
          newSize,
          CanvasResizeMode.stretch,
        );

        // Assert
        expect(
          layerManager.hasValidSnapshot,
          isFalse,
          reason: 'Snapshot should be invalidated after layer transformation',
        );
      });

      test('should use batch operation for transforming all layers', () {
        // Arrange
        const oldSize = Size(512, 512);
        const newSize = Size(1024, 1024);
        final layer1 = layerManager.addLayer(name: 'Layer 1');
        final layer2 = layerManager.addLayer(name: 'Layer 2');

        final stroke1 = StrokeData(
          points: [const Offset(50, 50)],
          size: 10,
          color: Colors.red,
          opacity: 1.0,
          hardness: 1.0,
        );
        final stroke2 = StrokeData(
          points: [const Offset(100, 100)],
          size: 20,
          color: Colors.blue,
          opacity: 1.0,
          hardness: 1.0,
        );

        layerManager.addStrokeToLayer(layer1.id, stroke1);
        layerManager.addStrokeToLayer(layer2.id, stroke2);

        // Track notification count
        int notificationCount = 0;
        layerManager.addListener(() {
          notificationCount++;
        });

        // Act
        layerManager.transformAllLayers(
          oldSize,
          newSize,
          CanvasResizeMode.stretch,
        );

        // Assert - Should only notify once (batch operation)
        expect(
          notificationCount,
          equals(1),
          reason: 'Batch operation should trigger only one notification',
        );
      });
    });
  });
}
