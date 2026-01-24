
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_manager.dart';

void main() {
  group('ResizeCanvasAction', () {
    late EditorState editorState;
    late LayerManager layerManager;

    setUp(() {
      editorState = EditorState();
      layerManager = editorState.layerManager;
    });

    tearDown(() {
      editorState.dispose();
    });

    test('execute should update canvas size', () {
      // Arrange
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.pad,
      );

      // Act
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize),
          reason: 'Canvas size should be updated to new size',);
    });

    test('execute should store previous size for undo', () {
      // Arrange
      const oldSize = Size(1024, 1024);
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.pad,
      );

      // Act
      action.execute(editorState);

      // Assert - Previous size is stored internally (not directly accessible)
      // We verify it works by testing undo
      expect(editorState.canvasSize, equals(newSize));

      action.undo(editorState);
      expect(editorState.canvasSize, equals(oldSize),
          reason: 'Undo should restore previous size',);
    });

    test('undo should restore previous canvas size', () {
      // Arrange
      const oldSize = Size(1024, 1024);
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Act
      action.execute(editorState);
      expect(editorState.canvasSize, equals(newSize));

      action.undo(editorState);

      // Assert
      expect(editorState.canvasSize, equals(oldSize),
          reason: 'Canvas size should be restored to original size after undo',);
    });

    test('execute should transform all layers with crop mode', () {
      // Arrange
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
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
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize),
          reason: 'Canvas size should be updated',);
      expect(layer.strokes.length, equals(1),
          reason: 'Stroke count should remain the same in crop mode',);
      // In crop mode, stroke positions remain unchanged
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke X position should remain unchanged in crop mode',);
      expect(layer.strokes.first.points.first.dy, equals(100.0),
          reason: 'Stroke Y position should remain unchanged in crop mode',);
    });

    test('execute should transform all layers with pad mode', () {
      // Arrange
      const newSize = Size(1024, 1024);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.pad,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
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
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize),
          reason: 'Canvas size should be updated',);
      expect(layer.strokes.length, equals(1),
          reason: 'Stroke count should remain the same in pad mode',);
      // In pad mode, stroke positions remain unchanged
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke X position should remain unchanged in pad mode',);
      expect(layer.strokes.first.points.first.dy, equals(100.0),
          reason: 'Stroke Y position should remain unchanged in pad mode',);
    });

    test('execute should transform all layers with stretch mode', () {
      // Arrange - EditorState starts at 1024x1024
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.stretch,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
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
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize),
          reason: 'Canvas size should be updated',);
      expect(layer.strokes.length, equals(1),
          reason: 'Stroke count should remain the same in stretch mode',);
      // In stretch mode (2x scale), stroke positions should be scaled
      expect(layer.strokes.first.points.first.dx, equals(200.0),
          reason: 'Stroke X position should be scaled by 2x in stretch mode',);
      expect(layer.strokes.first.points.first.dy, equals(200.0),
          reason: 'Stroke Y position should be scaled by 2x in stretch mode',);
      expect(layer.strokes.first.size, equals(20.0),
          reason: 'Stroke size should be scaled by 2x in stretch mode',);
    });

    test('undo with stretch mode should restore original positions', () {
      // Arrange - EditorState starts at 1024x1024
      const oldSize = Size(1024, 1024);
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.stretch,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
      final originalStroke = StrokeData(
        points: [
          const Offset(100, 100),
          const Offset(200, 200),
        ],
        size: 10,
        color: Colors.red,
        opacity: 1.0,
        hardness: 1.0,
      );
      layerManager.addStrokeToLayer(layer.id, originalStroke);

      // Act - Execute resize
      action.execute(editorState);
      expect(layer.strokes.first.points.first.dx, equals(200.0));
      expect(layer.strokes.first.size, equals(20.0));

      // Act - Undo resize
      action.undo(editorState);

      // Assert - Positions should be restored
      expect(editorState.canvasSize, equals(oldSize),
          reason: 'Canvas size should be restored',);
      expect(layer.strokes.length, equals(1),
          reason: 'Stroke count should remain the same after undo',);
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke X position should be restored to original',);
      expect(layer.strokes.first.points.first.dy, equals(100.0),
          reason: 'Stroke Y position should be restored to original',);
      expect(layer.strokes.first.size, equals(10.0),
          reason: 'Stroke size should be restored to original',);
    });

    test('undo should reverse crop mode to pad mode', () {
      // Arrange - Making canvas smaller with crop
      const oldSize = Size(1024, 1024);
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Add a layer
      final layer = layerManager.addLayer(name: 'Test Layer');
      final stroke = StrokeData(
        points: [const Offset(100, 100)],
        size: 10,
        color: Colors.red,
        opacity: 1.0,
        hardness: 1.0,
      );
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);
      expect(editorState.canvasSize, equals(newSize));

      // Undo - should use pad mode (reverse of crop)
      action.undo(editorState);

      // Assert
      expect(editorState.canvasSize, equals(oldSize));
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke position should remain unchanged after undo crop',);
    });

    test('undo should reverse pad mode to crop mode', () {
      // Arrange - EditorState starts at 1024x1024, making it larger
      const oldSize = Size(1024, 1024);
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.pad,
      );

      // Add a layer
      final layer = layerManager.addLayer(name: 'Test Layer');
      final stroke = StrokeData(
        points: [const Offset(100, 100)],
        size: 10,
        color: Colors.red,
        opacity: 1.0,
        hardness: 1.0,
      );
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);
      expect(editorState.canvasSize, equals(newSize));

      // Undo - should use crop mode (reverse of pad)
      action.undo(editorState);

      // Assert
      expect(editorState.canvasSize, equals(oldSize));
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke position should remain unchanged after undo pad',);
    });

    test('execute should handle multiple layers', () {
      // Arrange - EditorState starts at 1024x1024
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.stretch,
      );

      // Add multiple layers
      final layer1 = layerManager.addLayer(name: 'Layer 1');
      final layer2 = layerManager.addLayer(name: 'Layer 2');

      final stroke1 = StrokeData(
        points: [const Offset(100, 100)],
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

      layerManager.addStrokeToLayer(layer1.id, stroke1);
      layerManager.addStrokeToLayer(layer2.id, stroke2);

      // Act
      action.execute(editorState);

      // Assert - Both layers should be transformed (2x scale)
      expect(layer1.strokes.first.points.first.dx, equals(200.0),
          reason: 'Layer 1 stroke should be scaled',);
      expect(layer2.strokes.first.points.first.dx, equals(400.0),
          reason: 'Layer 2 stroke should be scaled',);
    });

    test('execute should handle empty layers', () {
      // Arrange
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Add an empty layer
      layerManager.addLayer(name: 'Empty Layer');

      // Act - Should not throw
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize));
    });

    test('execute should handle no layers', () {
      // Arrange
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Act - Should not throw even with no layers
      action.execute(editorState);

      // Assert
      expect(editorState.canvasSize, equals(newSize));
    });

    test('undo without execute should not throw', () {
      // Arrange
      const newSize = Size(512, 512);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.crop,
      );

      // Act & Assert - Should not throw
      expect(() => action.undo(editorState), returnsNormally);
    });

    test('description should include mode label', () {
      // Arrange & Act
      final cropAction = ResizeCanvasAction(
        newSize: const Size(512, 512),
        mode: CanvasResizeMode.crop,
      );
      final padAction = ResizeCanvasAction(
        newSize: const Size(1024, 1024),
        mode: CanvasResizeMode.pad,
      );
      final stretchAction = ResizeCanvasAction(
        newSize: const Size(768, 768),
        mode: CanvasResizeMode.stretch,
      );

      // Assert
      expect(cropAction.description, contains('裁剪'),
          reason: 'Description should include crop mode label',);
      expect(padAction.description, contains('填充'),
          reason: 'Description should include pad mode label',);
      expect(stretchAction.description, contains('拉伸'),
          reason: 'Description should include stretch mode label',);
    });

    test('execute with same size should not transform layers', () {
      // Arrange
      const sameSize = Size(1024, 1024);
      final action = ResizeCanvasAction(
        newSize: sameSize,
        mode: CanvasResizeMode.stretch,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
      final stroke = StrokeData(
        points: [const Offset(100, 100)],
        size: 10,
        color: Colors.red,
        opacity: 1.0,
        hardness: 1.0,
      );
      layerManager.addStrokeToLayer(layer.id, stroke);

      // Act
      action.execute(editorState);

      // Assert - Stroke should remain unchanged
      expect(layer.strokes.first.points.first.dx, equals(100.0),
          reason: 'Stroke position should not change when size is the same',);
      expect(layer.strokes.first.size, equals(10.0),
          reason: 'Stroke size should not change when size is the same',);
    });

    test('execute and undo should be idempotent', () {
      // Arrange - EditorState starts at 1024x1024
      const newSize = Size(2048, 2048);
      final action = ResizeCanvasAction(
        newSize: newSize,
        mode: CanvasResizeMode.stretch,
      );

      // Add a layer with a stroke
      final layer = layerManager.addLayer(name: 'Test Layer');
      final originalStroke = StrokeData(
        points: [const Offset(100, 100)],
        size: 10,
        color: Colors.red,
        opacity: 1.0,
        hardness: 1.0,
      );
      layerManager.addStrokeToLayer(layer.id, originalStroke);

      // Act - Execute, undo, execute again
      action.execute(editorState);
      final firstExecuteX = layer.strokes.first.points.first.dx;

      action.undo(editorState);

      action.execute(editorState);
      final secondExecuteX = layer.strokes.first.points.first.dx;

      // Assert - Both executes should produce the same result
      expect(firstExecuteX, equals(secondExecuteX),
          reason: 'Execute should be idempotent',);
    });
  });
}
