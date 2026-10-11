import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _red = Color(0xFFFF0000);
const _canvas = Rect.fromLTWH(0, 0, 32, 32);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('whole layer move previews rounded offsets and commits once', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();
      final mover = state.layerMover;

      expect(mover.begin(const Offset(5, 5)), isTrue);
      mover.update(const Offset(15.4, 8.6));

      expect(layer.movePreview?.offset, const Offset(10, 4));
      expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 8));

      mover.end();

      expect(layer.movePreview, isNull);
      expect(layer.contentBounds, const Rect.fromLTWH(10, 4, 8, 8));
      final moved = await LayerPixels.of(layer, _canvas);
      expect(moved.at(12, 6), [255, 0, 0, 255]);
      expect(moved.alphaAt(2, 2), 0);

      state.undo();
      expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 8));
    });
  });

  testWidgets('a zero-distance drag leaves no history entry', (tester) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();

      state.layerMover.begin(const Offset(4, 4));
      state.layerMover.update(const Offset(4.3, 3.8));
      state.layerMover.end();

      expect(layer.movePreview, isNull);
      expect(state.historyManager.canUndo, isFalse);
    });
  });

  testWidgets('cancel drops the preview without touching pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();
      state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)));

      state.layerMover.begin(const Offset(1, 1));
      state.layerMover.update(const Offset(9, 1));
      expect(state.selectionManager.isDragging, isTrue);

      state.layerMover.cancel();

      expect(layer.movePreview, isNull);
      expect(state.selectionManager.isDragging, isFalse);
      expect(state.selectionPath!.getBounds(), const Rect.fromLTWH(0, 0, 4, 4));
      expect(state.historyManager.canUndo, isFalse);
    });
  });

  testWidgets(
    'moving selected pixels bakes them and carries the selection along',
    (tester) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)));
        final mover = state.layerMover;

        expect(mover.begin(const Offset(2, 2)), isTrue);
        mover.update(const Offset(14, 2));
        expect(
          state.selectionManager.displayPath!.getBounds(),
          const Rect.fromLTWH(12, 0, 4, 4),
        );

        mover.end();

        expect(layer.movePreview, isNull);
        expect(state.selectionManager.isDragging, isFalse);
        expect(
          state.selectionPath!.getBounds(),
          const Rect.fromLTWH(12, 0, 4, 4),
        );
        var pixels = await LayerPixels.of(layer, _canvas);
        expect(pixels.alphaAt(1, 1), 0, reason: 'original spot is emptied');
        expect(pixels.at(6, 6), [255, 0, 0, 255], reason: 'rest untouched');
        expect(pixels.at(13, 1), [255, 0, 0, 255], reason: 'moved pixels');

        state.undo();

        expect(
          state.selectionPath!.getBounds(),
          const Rect.fromLTWH(0, 0, 4, 4),
        );
        pixels = await LayerPixels.of(layer, _canvas);
        expect(pixels.at(1, 1), [255, 0, 0, 255]);
        expect(pixels.alphaAt(13, 1), 0);
      });
    },
  );

  testWidgets('the source layer only moves selected pixels inside its extent', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, source) = await _stateWithLayer();
      final mask = state.layerManager.addLayer(
        name: 'mask',
        index: 0,
        role: LayerRole.mask,
      );
      state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: source.id));
      state.layerManager.setActiveLayer(source.id);

      expect(state.layerMover.canMoveWholeLayer(source), isFalse);
      expect(state.layerMover.canMoveWholeLayer(mask), isTrue);
      expect(state.layerMover.begin(const Offset(1, 1)), isFalse);

      state.setSelection(Path()..addRect(const Rect.fromLTWH(4, 4, 4, 4)));
      expect(state.layerMover.begin(const Offset(5, 5)), isTrue);
      state.layerMover.update(const Offset(11, 5));
      state.layerMover.end();

      expect(source.contentBounds, const Rect.fromLTWH(0, 0, 8, 8));
      final pixels = await LayerPixels.of(source, _canvas);
      expect(pixels.alphaAt(5, 5), 0);
      expect(pixels.at(1, 1), [255, 0, 0, 255]);
    });
  });

  testWidgets('locked or empty layers cannot be moved', (tester) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();
      layer.locked = true;
      expect(state.layerMover.begin(Offset.zero), isFalse);

      layer.locked = false;
      final empty = state.layerManager.addLayer(name: 'empty', index: 0);
      expect(state.layerManager.activeLayer, same(empty));
      expect(state.layerMover.begin(Offset.zero), isFalse);
    });
  });

  testWidgets('back-to-back nudges each commit on top of the previous one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();
      state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)));

      state.layerMover.nudge(const Offset(1, 0));
      state.layerMover.nudge(const Offset(1, 0));

      expect(state.historyManager.undoStackSize, 2);
      expect(state.selectionPath!.getBounds(), const Rect.fromLTWH(2, 0, 4, 4));
      final pixels = await LayerPixels.of(layer, _canvas);
      expect(pixels.alphaAt(0, 1), 0);
      expect(pixels.alphaAt(1, 1), 0);
      expect(pixels.at(2, 1), [255, 0, 0, 255]);
      expect(pixels.at(5, 1), [255, 0, 0, 255]);

      state.clearSelection();
      state.layerMover.nudge(const Offset(0, 10));
      expect(layer.contentBounds.top, 10);
    });
  });

  testWidgets('a new drag can start right after a selection move is released', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final (state, layer) = await _stateWithLayer();
      state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)));
      final mover = state.layerMover;

      expect(mover.begin(const Offset(1, 1)), isTrue);
      mover.update(const Offset(5, 1));
      mover.end();
      expect(mover.begin(const Offset(5, 1)), isTrue);
      mover.update(const Offset(9, 1));
      mover.end();

      expect(state.historyManager.undoStackSize, 2);
      var pixels = await LayerPixels.of(layer, _canvas);
      expect(pixels.at(9, 1), [255, 0, 0, 255]);
      expect(pixels.alphaAt(1, 1), 0);

      state.undo();
      pixels = await LayerPixels.of(layer, _canvas);
      expect(pixels.at(5, 1), [255, 0, 0, 255]);
      expect(pixels.alphaAt(9, 1), 0);
    });
  });
}

Future<(EditorState, Layer)> _stateWithLayer() async {
  final state = EditorState();
  addTearDown(state.dispose);
  final layer = state.layerManager.addLayer(name: 'layer');
  await fillLayer(
    state.layerManager,
    layer,
    size: const Size(8, 8),
    color: _red,
  );
  return (state, layer);
}
