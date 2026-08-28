import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/controllers/magic_wand_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/image_editor_effects_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';

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

  group('MagicWandController mask target', () {
    test(
      'reuses the first unlocked non-source layer when source is active',
      () {
        final session = ImageEditorController();
        final manager = session.editorState.layerManager;
        final reusable = manager.addLayer(name: 'reusable');
        final source = manager.addLayer(name: 'source');
        session.sourceLayerId = source.id;
        var addCount = 0;
        final magicWand = MagicWandController(
          session: session,
          editorState: session.editorState,
          config: const ImageEditorSessionConfig.empty(),
          addMaskLayer: (name) {
            addCount++;
            return manager.addLayer(name: name);
          },
        );

        expect(magicWand.resolveMagicWandMaskTarget('mask'), same(reusable));
        expect(addCount, 0);

        magicWand.dispose();
        session.dispose();
      },
    );

    test('reuses the first unlocked layer when the active layer is locked', () {
      final session = ImageEditorController();
      final manager = session.editorState.layerManager;
      final reusable = manager.addLayer(name: 'reusable');
      final locked = manager.addLayer(name: 'locked')..locked = true;
      var addCount = 0;
      final magicWand = MagicWandController(
        session: session,
        editorState: session.editorState,
        config: const ImageEditorSessionConfig.empty(),
        addMaskLayer: (name) {
          addCount++;
          return manager.addLayer(name: name);
        },
      );

      expect(manager.activeLayer, same(locked));
      expect(magicWand.resolveMagicWandMaskTarget('mask'), same(reusable));
      expect(addCount, 0);

      magicWand.dispose();
      session.dispose();
    });

    test('reuses the first unlocked layer when there is no active layer', () {
      final session = ImageEditorController();
      final manager = session.editorState.layerManager;
      final detached = Layer(name: 'reusable');
      manager.insertLayerFromData(detached.toData(), 0);
      detached.dispose();
      final reusable = manager.layers.single;
      var addCount = 0;
      final magicWand = MagicWandController(
        session: session,
        editorState: session.editorState,
        config: const ImageEditorSessionConfig.empty(),
        addMaskLayer: (name) {
          addCount++;
          return manager.addLayer(name: name);
        },
      );

      expect(manager.activeLayer, isNull);
      expect(magicWand.resolveMagicWandMaskTarget('mask'), same(reusable));
      expect(addCount, 0);

      magicWand.dispose();
      session.dispose();
    });

    test('adds one mask layer only when no reusable candidate exists', () {
      final session = ImageEditorController();
      final manager = session.editorState.layerManager;
      final source = manager.addLayer(name: 'source');
      manager.addLayer(name: 'locked').locked = true;
      session.sourceLayerId = source.id;
      var addCount = 0;
      final magicWand = MagicWandController(
        session: session,
        editorState: session.editorState,
        config: const ImageEditorSessionConfig.empty(),
        addMaskLayer: (name) {
          addCount++;
          return manager.addLayer(name: name);
        },
      );

      final created = magicWand.resolveMagicWandMaskTarget('mask');
      expect(addCount, 1);
      expect(created.name, 'mask');
      expect(magicWand.resolveMagicWandMaskTarget('mask'), same(created));
      expect(addCount, 1);

      magicWand.dispose();
      session.dispose();
    });
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
