import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';

/// Tests for verifying editing capabilities on loaded masks.
///
/// This test suite verifies that masks loaded from image files can be edited
/// using drawing tools, eraser tools, and layer transformations (opacity, blend mode, etc.).
void main() {
  group('Mask Editing Tests', () {
    late LayerManager layerManager;

    setUp(() {
      layerManager = LayerManager();
    });

    tearDown(() {
      layerManager.dispose();
    });

    /// Helper: Creates a test PNG mask image
    Uint8List createTestMask({int width = 100, int height = 100, int color = 0xFFFF0000}) {
      final image = img.Image(width: width, height: height);
      image.clear(img.ColorRgb8(
        (color >> 16) & 0xFF,
        (color >> 8) & 0xFF,
        color & 0xFF,
      ),);
      return Uint8List.fromList(img.encodePng(image));
    }

    test('should allow drawing brush strokes on loaded mask', () async {
      // Load a mask
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '测试蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.strokes.length, 0); // Initially no strokes

      // Add a brush stroke
      final stroke = StrokeData(
        points: [const Offset(10, 10), const Offset(20, 20), const Offset(30, 30)],
        size: 10.0,
        color: Colors.white,
        opacity: 1.0,
        hardness: 0.8,
        isEraser: false,
      );

      layerManager.addStrokeToLayer(layer!.id, stroke);

      // Verify stroke was added
      expect(layer.strokes.length, 1);
      expect(layer.strokes.first.points.length, 3);
      expect(layer.strokes.first.isEraser, false);
    });

    test('should allow erasing parts of loaded mask', () async {
      // Load a mask
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '可擦除蒙版',
      );

      expect(layer, isNotNull);

      // Add a brush stroke first
      final brushStroke = StrokeData(
        points: [const Offset(10, 10), const Offset(50, 50)],
        size: 20.0,
        color: Colors.white,
        opacity: 1.0,
        hardness: 1.0,
        isEraser: false,
      );
      layerManager.addStrokeToLayer(layer!.id, brushStroke);
      expect(layer.strokes.length, 1);

      // Add an eraser stroke
      final eraserStroke = StrokeData(
        points: [const Offset(20, 20), const Offset(30, 30)],
        size: 15.0,
        color: Colors.transparent,
        opacity: 1.0,
        hardness: 1.0,
        isEraser: true,
      );

      layerManager.addStrokeToLayer(layer.id, eraserStroke);

      // Verify eraser stroke was added
      expect(layer.strokes.length, 2);
      expect(layer.strokes.last.isEraser, true);
      expect(layer.strokes.last.size, 15.0);
    });

    test('should allow changing opacity of loaded mask', () async {
      // Load a mask
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '透明度蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.opacity, 1.0); // Default opacity

      // Change opacity to 50%
      layerManager.setLayerOpacity(layer!.id, 0.5);

      // Verify opacity changed
      expect(layer.opacity, 0.5);
    });

    test('should allow setting opacity to zero (fully transparent)', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '透明蒙版',
      );

      expect(layer, isNotNull);

      // Set to fully transparent
      layerManager.setLayerOpacity(layer!.id, 0.0);

      expect(layer.opacity, 0.0);
    });

    test('should clamp opacity values to valid range', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '边界测试蒙版',
      );

      expect(layer, isNotNull);

      // Try to set opacity > 1.0
      layerManager.setLayerOpacity(layer!.id, 1.5);
      expect(layer.opacity, 1.0); // Should be clamped to 1.0

      // Try to set opacity < 0.0
      layerManager.setLayerOpacity(layer.id, -0.5);
      expect(layer.opacity, 0.0); // Should be clamped to 0.0
    });

    test('should allow changing blend mode of loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '混合模式蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.blendMode, LayerBlendMode.normal); // Default blend mode

      // Change to multiply blend mode
      layerManager.setLayerBlendMode(layer!.id, LayerBlendMode.multiply);

      // Verify blend mode changed
      expect(layer.blendMode, LayerBlendMode.multiply);
    });

    test('should support all blend modes on loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '全混合模式蒙版',
      );

      expect(layer, isNotNull);

      // Test various blend modes
      final blendModes = [
        LayerBlendMode.multiply,
        LayerBlendMode.screen,
        LayerBlendMode.overlay,
        LayerBlendMode.darken,
        LayerBlendMode.lighten,
        LayerBlendMode.colorDodge,
        LayerBlendMode.colorBurn,
        LayerBlendMode.hardLight,
        LayerBlendMode.softLight,
        LayerBlendMode.difference,
        LayerBlendMode.exclusion,
      ];

      for (final mode in blendModes) {
        layerManager.setLayerBlendMode(layer!.id, mode);
        expect(layer.blendMode, mode);
      }
    });

    test('should allow moving loaded mask up in layer stack', () async {
      // Create two masks
      final mask1Bytes = createTestMask(color: 0xFFFF0000); // Red
      final mask2Bytes = createTestMask(color: 0xFF00FF00); // Green

      final layer1 = await layerManager.addLayerFromImage(
        mask1Bytes,
        name: '底层蒙版',
      );
      final layer2 = await layerManager.addLayerFromImage(
        mask2Bytes,
        name: '顶层蒙版',
      );

      expect(layer1, isNotNull);
      expect(layer2, isNotNull);
      expect(layerManager.layerCount, 2);

      // Initial order: layer1 at index 0, layer2 at index 1
      expect(layerManager.layers.indexOf(layer1!), 0);
      expect(layerManager.layers.indexOf(layer2!), 1);

      // Move layer1 up
      final moved = layerManager.moveLayerUp(layer1.id);

      // Verify it moved
      expect(moved, true);
      expect(layerManager.layers.indexOf(layer1), 1); // Now at top
      expect(layerManager.layers.indexOf(layer2), 0); // Now at bottom
    });

    test('should allow moving loaded mask down in layer stack', () async {
      // Create two masks
      final mask1Bytes = createTestMask(color: 0xFFFF0000); // Red
      final mask2Bytes = createTestMask(color: 0xFF00FF00); // Green

      final layer1 = await layerManager.addLayerFromImage(
        mask1Bytes,
        name: '底层蒙版',
      );
      final layer2 = await layerManager.addLayerFromImage(
        mask2Bytes,
        name: '顶层蒙版',
      );

      expect(layer1, isNotNull);
      expect(layer2, isNotNull);

      // layer2 is already at top, move it down
      final moved = layerManager.moveLayerDown(layer2!.id);

      // Verify it moved
      expect(moved, true);
      expect(layerManager.layers.indexOf(layer2), 0); // Now at bottom
      expect(layerManager.layers.indexOf(layer1!), 1); // Now at top
    });

    test('should not move mask up when already at top', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '顶层蒙版',
      );

      expect(layer, isNotNull);
      expect(layerManager.layerCount, 1);

      // Try to move up when already at top
      final moved = layerManager.moveLayerUp(layer!.id);

      // Should return false (no move occurred)
      expect(moved, false);
      expect(layerManager.layers.indexOf(layer), 0); // Still at same position
    });

    test('should not move mask down when already at bottom', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '底层蒙版',
      );

      expect(layer, isNotNull);
      expect(layerManager.layerCount, 1);

      // Try to move down when already at bottom
      final moved = layerManager.moveLayerDown(layer!.id);

      // Should return false (no move occurred)
      expect(moved, false);
      expect(layerManager.layers.indexOf(layer), 0); // Still at same position
    });

    test('should allow adding multiple brush strokes to loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '多笔画蒙版',
      );

      expect(layer, isNotNull);

      // Add multiple strokes
      for (int i = 0; i < 5; i++) {
        final stroke = StrokeData(
          points: [
            Offset(i * 10.0, i * 10.0),
            Offset(i * 10.0 + 20, i * 10.0 + 20),
          ],
          size: 10.0 + i,
          color: Colors.white,
          opacity: 1.0,
          hardness: 0.8,
          isEraser: false,
        );
        layerManager.addStrokeToLayer(layer!.id, stroke);
      }

      // Verify all strokes were added
      expect(layer!.strokes.length, 5);
      expect(layer.strokes[0].size, 10.0);
      expect(layer.strokes[4].size, 14.0);
    });

    test('should allow mixing brush and eraser strokes on loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '混合笔画蒙版',
      );

      expect(layer, isNotNull);

      // Add brush stroke
      layerManager.addStrokeToLayer(
        layer!.id,
        StrokeData(
          points: [const Offset(10, 10), const Offset(50, 50)],
          size: 20.0,
          color: Colors.white,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: false,
        ),
      );

      // Add eraser stroke
      layerManager.addStrokeToLayer(
        layer.id,
        StrokeData(
          points: [const Offset(20, 20), const Offset(40, 40)],
          size: 15.0,
          color: Colors.transparent,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: true,
        ),
      );

      // Add another brush stroke
      layerManager.addStrokeToLayer(
        layer.id,
        StrokeData(
          points: [const Offset(60, 60), const Offset(80, 80)],
          size: 10.0,
          color: Colors.white,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: false,
        ),
      );

      // Verify all strokes were added in order
      expect(layer.strokes.length, 3);
      expect(layer.strokes[0].isEraser, false);
      expect(layer.strokes[1].isEraser, true);
      expect(layer.strokes[2].isEraser, false);
    });

    test('should allow removing strokes from loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '可撤销蒙版',
      );

      expect(layer, isNotNull);

      // Add strokes
      final stroke1 = StrokeData(
        points: [const Offset(10, 10), const Offset(20, 20)],
        size: 10.0,
        color: Colors.white,
        opacity: 1.0,
        hardness: 1.0,
        isEraser: false,
      );

      final stroke2 = StrokeData(
        points: [const Offset(30, 30), const Offset(40, 40)],
        size: 15.0,
        color: Colors.white,
        opacity: 1.0,
        hardness: 1.0,
        isEraser: false,
      );

      layerManager.addStrokeToLayer(layer!.id, stroke1);
      layerManager.addStrokeToLayer(layer.id, stroke2);

      expect(layer.strokes.length, 2);

      // Remove last stroke
      final removedStroke = layerManager.removeLastStrokeFromLayer(layer.id);

      // Verify stroke was removed
      expect(removedStroke, isNotNull);
      expect(removedStroke?.size, 15.0); // stroke2 was removed
      expect(layer.strokes.length, 1);
      expect(layer.strokes.last.size, 10.0); // Only stroke1 remains
    });

    test('should allow clearing all strokes from loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '可清除蒙版',
      );

      expect(layer, isNotNull);

      // Add multiple strokes
      for (int i = 0; i < 3; i++) {
        layerManager.addStrokeToLayer(
          layer!.id,
          StrokeData(
            points: [Offset(i * 10.0, i * 10.0)],
            size: 10.0,
            color: Colors.white,
            opacity: 1.0,
            hardness: 1.0,
            isEraser: false,
          ),
        );
      }

      expect(layer!.strokes.length, 3);

      // Clear all strokes
      layerManager.clearLayer(layer.id);

      // Verify all strokes were removed
      expect(layer.strokes.length, 0);
      expect(layer.hasContent, true); // Still has base image
    });

    test('should not allow adding strokes to locked mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '锁定蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.locked, false);

      // Lock the layer
      layerManager.toggleLock(layer!.id);
      expect(layer.locked, true);

      // Try to add stroke to locked layer
      final stroke = StrokeData(
        points: [const Offset(10, 10), const Offset(20, 20)],
        size: 10.0,
        color: Colors.white,
        opacity: 1.0,
        hardness: 1.0,
        isEraser: false,
      );

      layerManager.addStrokeToLayer(layer.id, stroke);

      // Verify stroke was NOT added (layer is locked)
      expect(layer.strokes.length, 0);
    });

    test('should maintain base image after editing operations', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '保留底图蒙版',
      );

      expect(layer, isNotNull);
      expect(layer?.hasBaseImage, true);
      expect(layer?.baseImage, isNotNull);

      // Perform various editing operations
      layerManager.addStrokeToLayer(
        layer!.id,
        StrokeData(
          points: [const Offset(10, 10), const Offset(20, 20)],
          size: 10.0,
          color: Colors.white,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: false,
        ),
      );

      layerManager.setLayerOpacity(layer.id, 0.7);
      layerManager.setLayerBlendMode(layer.id, LayerBlendMode.multiply);

      // Verify base image is still present
      expect(layer.hasBaseImage, true);
      expect(layer.baseImage, isNotNull);
    });

    test('should handle complex editing workflow on loaded mask', () async {
      final maskBytes = createTestMask();
      final layer = await layerManager.addLayerFromImage(
        maskBytes,
        name: '复杂编辑蒙版',
      );

      expect(layer, isNotNull);

      // 1. Draw some strokes
      for (int i = 0; i < 3; i++) {
        layerManager.addStrokeToLayer(
          layer!.id,
          StrokeData(
            points: [
              Offset(i * 20.0, i * 20.0),
              Offset(i * 20.0 + 30, i * 20.0 + 30),
            ],
            size: 15.0,
            color: Colors.white,
            opacity: 0.8,
            hardness: 0.9,
            isEraser: false,
          ),
        );
      }
      expect(layer!.strokes.length, 3);

      // 2. Change opacity
      layerManager.setLayerOpacity(layer.id, 0.6);
      expect(layer.opacity, 0.6);

      // 3. Change blend mode
      layerManager.setLayerBlendMode(layer.id, LayerBlendMode.overlay);
      expect(layer.blendMode, LayerBlendMode.overlay);

      // 4. Erase some parts
      layerManager.addStrokeToLayer(
        layer.id,
        StrokeData(
          points: [const Offset(25, 25), const Offset(35, 35)],
          size: 20.0,
          color: Colors.transparent,
          opacity: 1.0,
          hardness: 1.0,
          isEraser: true,
        ),
      );
      expect(layer.strokes.length, 4);

      // 5. Undo some strokes
      layerManager.removeLastStrokeFromLayer(layer.id);
      expect(layer.strokes.length, 3);

      // 6. Verify final state
      expect(layer.hasBaseImage, true);
      expect(layer.opacity, 0.6);
      expect(layer.blendMode, LayerBlendMode.overlay);
      expect(layer.strokes.last.isEraser, false); // Last stroke is brush, not eraser
    });
  });
}
