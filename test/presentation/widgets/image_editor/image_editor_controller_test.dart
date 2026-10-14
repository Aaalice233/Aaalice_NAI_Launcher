import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/image_editor_effects_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';

void main() {
  test('session config defensively owns image inputs', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final config = ImageEditorSessionConfig(initialImage: bytes);
    bytes[0] = 8;
    final exposed = config.initialImage!;
    exposed[1] = 9;

    expect(config.initialImage, orderedEquals([1, 2, 3]));
  });

  test('effects resolve the current active layer when applying', () {
    final session = ImageEditorController();
    final first = session.editorState.layerManager.addLayer(name: 'first');
    final second = session.editorState.layerManager.addLayer(name: 'second');
    for (final layer in [first, second]) {
      layer.addStroke(
        StrokeData(
          points: const [Offset.zero, Offset(1, 1)],
          size: 1,
          color: Colors.black,
          opacity: 1,
          hardness: 1,
        ),
      );
    }
    final effects = ImageEditorEffectsController(
      session: session,
      editorState: session.editorState,
    );

    session.editorState.layerManager.setActiveLayer(first.id);
    expect(effects.activeLayerForApply, same(first));

    session.editorState.layerManager.setActiveLayer(second.id);
    expect(effects.activeLayerForApply, same(second));

    second.locked = true;
    expect(effects.activeLayerForApply, isNull);
    session.dispose();
  });

  group('ImageEditorController lifecycle', () {
    test('rejects superseded and disposed operation epochs', () {
      final controller = ImageEditorController();
      final first = controller.beginOperation();
      expect(controller.accepts(first), isTrue);

      final second = controller.beginOperation();
      expect(controller.accepts(first), isFalse);
      expect(controller.accepts(second), isTrue);

      controller.dispose();
      expect(controller.accepts(second), isFalse);
    });

    test('cancelPendingOperations supersedes in-flight work', () {
      final controller = ImageEditorController();
      final epoch = controller.beginOperation();

      controller.cancelPendingOperations();

      expect(controller.accepts(epoch), isFalse);
      controller.dispose();
    });

    test('snapshot does not expose controller byte buffers', () {
      final controller = ImageEditorController(
        config: const ImageEditorSessionConfig.empty(),
      );
      controller.outpaintSourceImage = Uint8List.fromList([1, 2, 3]);

      final snapshot = controller.snapshot;
      snapshot.outpaintSourceImage![0] = 9;

      expect(controller.outpaintSourceImage, orderedEquals([1, 2, 3]));
      controller.dispose();
    });
  });
}
