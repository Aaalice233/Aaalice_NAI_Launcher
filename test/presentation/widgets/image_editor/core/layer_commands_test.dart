import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/history_manager.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _red = Color(0xFFFF0000);
const _blue = Color(0xFF0000FF);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('edit session', () {
    testWidgets('addLayer inserts right above the active layer', (
      tester,
    ) async {
      final state = _editorState();
      final layers = state.layerManager;
      final bottom = layers.addLayer(name: 'bottom');
      final top = layers.addLayer(name: 'top', index: 0);
      layers.setActiveLayer(bottom.id);

      final added = state.layerCommands.addLayer(name: 'added');

      expect(layers.layers.map((l) => l.name), ['top', 'added', 'bottom']);
      expect(layers.activeLayer, same(added));

      state.undo();
      expect(layers.layers, [top, bottom]);
    });

    testWidgets('delete and undo restore pixels, offset and stack position', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final state = _editorState();
        final layers = state.layerManager;
        layers.addLayer(name: 'bottom');
        final middle = layers.addLayer(name: 'middle', index: 0);
        layers.addLayer(name: 'top', index: 0);
        await fillLayer(
          layers,
          middle,
          size: const Size(8, 8),
          color: _red,
          offset: const Offset(10, 20),
        );

        state.layerCommands.delete(middle);
        expect(layers.layers.map((l) => l.name), ['top', 'bottom']);

        state.undo();
        final restored = layers.layers[1];
        expect(restored.id, middle.id);
        expect(restored.contentBounds, const Rect.fromLTWH(10, 20, 8, 8));
        final pixels = await LayerPixels.of(
          restored,
          const Rect.fromLTWH(10, 20, 8, 8),
        );
        expect(pixels.at(14, 24), [255, 0, 0, 255]);
      });
    });

    testWidgets('duplicate copies pixels and sits right above the source', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final state = _editorState();
        final layers = state.layerManager;
        final source = layers.addLayer(name: 'source');
        await fillLayer(
          layers,
          source,
          size: const Size(8, 8),
          color: _red,
          offset: const Offset(4, 4),
        );
        source.opacity = 0.4;

        final copy = state.layerCommands.duplicate(source, name: 'copy');

        expect(layers.layers, [copy, source]);
        expect(copy.opacity, 0.4);
        expect(copy.contentBounds, source.contentBounds);
        final pixels = await LayerPixels.of(
          copy,
          const Rect.fromLTWH(4, 4, 8, 8),
        );
        expect(pixels.at(6, 6), [255, 0, 0, 255]);

        state.undo();
        expect(layers.layers, [source]);
      });
    });

    testWidgets(
      'mergeDown bakes upper opacity once and undo restores both layers',
      (tester) async {
        await tester.runAsync(() async {
          final state = _editorState();
          final layers = state.layerManager;
          final lower = layers.addLayer(name: 'lower');
          final upper = layers.addLayer(name: 'upper', index: 0);
          await fillLayer(layers, lower, size: const Size(8, 8), color: _red);
          await fillLayer(
            layers,
            upper,
            size: const Size(8, 8),
            color: _blue,
            offset: const Offset(4, 0),
          );
          upper.opacity = 0.5;

          expect(state.layerCommands.mergeDown(upper), isTrue);

          expect(layers.layers, [lower]);
          expect(lower.contentBounds, const Rect.fromLTWH(0, 0, 12, 8));
          final merged = await LayerPixels.of(
            lower,
            const Rect.fromLTWH(0, 0, 12, 8),
          );
          expect(merged.at(2, 4), [255, 0, 0, 255]);
          // 只有上层覆盖的区域保留一次 50% 不透明度，不能再被乘一次
          expect(merged.alphaAt(10, 4), closeTo(128, 2));
          final overlap = merged.at(6, 4);
          expect(overlap[0], closeTo(127, 2));
          expect(overlap[2], closeTo(128, 2));
          expect(overlap[3], 255);

          state.undo();
          expect(layers.layers.map((l) => l.id), [upper.id, lower.id]);
          final restoredUpper = layers.layers.first;
          expect(restoredUpper.opacity, 0.5);
          expect(lower.contentBounds, const Rect.fromLTWH(0, 0, 8, 8));
          final lowerPixels = await LayerPixels.of(
            lower,
            const Rect.fromLTWH(0, 0, 8, 8),
          );
          expect(lowerPixels.at(6, 4), [255, 0, 0, 255]);
        });
      },
    );

    testWidgets('reorder goes through history', (tester) async {
      final state = _editorState();
      final layers = state.layerManager;
      final a = layers.addLayer(name: 'a');
      final b = layers.addLayer(name: 'b');
      final c = layers.addLayer(name: 'c');

      state.layerCommands.moveDown(a);
      expect(layers.layers, [b, a, c]);

      state.layerCommands.reorder(2, 0);
      expect(layers.layers, [c, b, a]);

      state.undo();
      expect(layers.layers, [b, a, c]);
      state.undo();
      expect(layers.layers, [a, b, c]);
      expect(state.layerCommands.canMoveUp(a), isFalse);
      expect(state.layerCommands.canMoveDown(c), isFalse);
    });

    testWidgets('the last layer cannot be deleted', (tester) async {
      final state = _editorState();
      final only = state.layerManager.addLayer(name: 'only');

      expect(state.layerCommands.canDelete(only), isFalse);
      state.layerCommands.delete(only);
      expect(state.layerManager.layers, [only]);
    });

    testWidgets(
      'cutSelectionToNewLayer is one undo step that restores the selection',
      (tester) async {
        await tester.runAsync(() async {
          final state = _editorState();
          final layers = state.layerManager;
          final source = layers.addLayer(name: 'source');
          await fillLayer(
            layers,
            source,
            size: const Size(16, 16),
            color: _red,
          );
          final selection = Path()..addRect(const Rect.fromLTWH(0, 0, 8, 8));
          state.setSelection(selection);

          final cut = state.layerCommands.cutSelectionToNewLayer(
            layerName: 'cut',
          );

          expect(cut, isTrue);
          expect(layers.layerCount, 2);
          final cutLayer = layers.layers.first;
          expect(cutLayer.name, 'cut');
          expect(layers.activeLayer, same(cutLayer));
          expect(cutLayer.contentBounds, const Rect.fromLTWH(0, 0, 8, 8));
          expect(state.selectionPath, isNull);
          final remainder = await LayerPixels.of(
            source,
            const Rect.fromLTWH(0, 0, 16, 16),
          );
          expect(remainder.alphaAt(4, 4), 0);
          expect(remainder.at(12, 12), [255, 0, 0, 255]);

          state.undo();

          expect(layers.layers, [source]);
          expect(layers.activeLayer, same(source));
          expect(state.selectionPath, isNotNull);
          expect(
            state.selectionPath!.getBounds(),
            const Rect.fromLTWH(0, 0, 8, 8),
          );
          final restored = await LayerPixels.of(
            source,
            const Rect.fromLTWH(0, 0, 16, 16),
          );
          expect(restored.at(4, 4), [255, 0, 0, 255]);
        });
      },
    );

    testWidgets('clearSelectionPixels keeps the selection and undoes cleanly', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final state = _editorState();
        final layers = state.layerManager;
        final layer = layers.addLayer(name: 'layer');
        await fillLayer(layers, layer, size: const Size(16, 16), color: _red);
        state.setSelection(Path()..addRect(const Rect.fromLTWH(4, 4, 4, 4)));

        expect(state.layerCommands.clearSelectionPixels(), isTrue);

        expect(state.selectionPath, isNotNull);
        var pixels = await LayerPixels.of(
          layer,
          const Rect.fromLTWH(0, 0, 16, 16),
        );
        expect(pixels.alphaAt(5, 5), 0);
        expect(pixels.at(1, 1), [255, 0, 0, 255]);

        state.undo();
        pixels = await LayerPixels.of(layer, const Rect.fromLTWH(0, 0, 16, 16));
        expect(pixels.at(5, 5), [255, 0, 0, 255]);
      });
    });

    testWidgets('selection pixel edits need an unlocked layer with content', (
      tester,
    ) async {
      final state = _editorState();
      final layer = state.layerManager.addLayer(name: 'empty');
      state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 4)));

      expect(state.layerCommands.canEditSelectionPixels, isFalse);
      expect(state.layerCommands.clearSelectionPixels(), isFalse);

      layer.addStroke(_stroke());
      expect(state.layerCommands.canEditSelectionPixels, isTrue);
      layer.locked = true;
      expect(state.layerCommands.canEditSelectionPixels, isFalse);
    });
  });

  group('inpaint roles', () {
    testWidgets('new layers land in their own role group', (tester) async {
      final session = _inpaintSession();
      final state = session.state;
      final layers = state.layerManager;
      layers.setActiveLayer(session.source.id);

      final mask2 = state.layerCommands.addLayer(
        name: 'mask2',
        role: LayerRole.mask,
      );
      expect(layers.layers.indexOf(mask2), 0);

      final image = state.layerCommands.addLayer(name: 'image');
      expect(layers.layers, [mask2, session.mask, image, session.source]);

      // 当前是图片层时，新图片层紧贴它上方
      layers.setActiveLayer(session.source.id);
      final image2 = state.layerCommands.addLayer(name: 'image2');
      expect(layers.layers.indexOf(image2), 3);
      expect(state.rolePolicy.isValidOrder(layers.layers), isTrue);
    });

    testWidgets('the source layer cannot be deleted, cleared or merged away', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final session = _inpaintSession();
        final state = session.state;
        final layers = state.layerManager;
        await fillLayer(
          layers,
          session.source,
          size: const Size(16, 16),
          color: _red,
        );
        final below = state.layerCommands.addLayer(name: 'below');
        state.layerCommands.reorder(
          layers.indexOfLayer(below.id),
          layers.layerCount - 1,
        );
        below.addStroke(_stroke());
        expect(layers.layers.last, same(below));

        expect(state.layerCommands.canDelete(session.source), isFalse);
        expect(state.rolePolicy.canClear(session.source), isFalse);
        expect(state.layerCommands.canMergeDown(session.source), isFalse);
        expect(state.layerCommands.mergeDown(session.source), isFalse);
      });
    });

    testWidgets('a duplicate of the source is an ordinary image layer', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final session = _inpaintSession();
        final state = session.state;
        await fillLayer(
          state.layerManager,
          session.source,
          size: const Size(16, 16),
          color: _red,
        );

        final copy = state.layerCommands.duplicate(
          session.source,
          name: 'copy',
        );

        expect(copy.role, LayerRole.image);
        expect(state.rolePolicy.isProtected(copy), isFalse);
        expect(state.layerCommands.canDelete(copy), isTrue);
        expect(state.layerCommands.canMergeDown(copy), isTrue);
      });
    });

    testWidgets('the last mask layer cannot be deleted', (tester) async {
      final session = _inpaintSession();
      final state = session.state;

      expect(state.layerCommands.canDelete(session.mask), isFalse);
      final mask2 = state.layerCommands.addLayer(
        name: 'mask2',
        role: LayerRole.mask,
      );
      expect(state.layerCommands.canDelete(session.mask), isTrue);
      expect(state.layerCommands.canDelete(mask2), isTrue);
    });

    testWidgets('masks always stay above image layers', (tester) async {
      final session = _inpaintSession();
      final state = session.state;
      final layers = state.layerManager;
      final image = state.layerCommands.addLayer(name: 'image');
      expect(layers.layers, [session.mask, image, session.source]);

      expect(state.layerCommands.canMoveDown(session.mask), isFalse);
      expect(state.layerCommands.canMoveUp(image), isFalse);
      state.layerCommands.moveUp(image);
      expect(layers.layers, [session.mask, image, session.source]);

      expect(state.layerCommands.canMoveDown(image), isTrue);
    });

    testWidgets('mergeDown refuses to mix image and mask layers', (
      tester,
    ) async {
      final session = _inpaintSession();
      final state = session.state;
      session.mask.addStroke(_stroke());

      expect(state.layerCommands.canMergeDown(session.mask), isFalse);
    });

    testWidgets('pixel edits on the source keep its extent locked', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final session = _inpaintSession();
        final state = session.state;
        final layers = state.layerManager;
        await fillLayer(
          layers,
          session.source,
          size: const Size(16, 16),
          color: _red,
        );
        layers.setActiveLayer(session.source.id);
        state.setSelection(
          Path()..addRect(const Rect.fromLTWH(-8, -8, 12, 12)),
        );

        expect(state.layerCommands.clearSelectionPixels(), isTrue);
        expect(session.source.contentBounds, const Rect.fromLTWH(0, 0, 16, 16));

        state.setSelection(Path()..addRect(const Rect.fromLTWH(8, 8, 16, 16)));
        expect(
          state.layerCommands.cutSelectionToNewLayer(layerName: 'cut'),
          isTrue,
        );
        expect(session.source.contentBounds, const Rect.fromLTWH(0, 0, 16, 16));
        final cut = layers.layers[layers.indexOfLayer(session.source.id) - 1];
        expect(cut.role, LayerRole.image);
        expect(cut.contentBounds, const Rect.fromLTWH(8, 8, 8, 8));
      });
    });
  });
}

EditorState _editorState() {
  final state = EditorState();
  addTearDown(state.dispose);
  return state;
}

({EditorState state, Layer source, Layer mask}) _inpaintSession() {
  final state = _editorState();
  final layers = state.layerManager;
  final source = layers.addLayer(name: 'source');
  final mask = layers.addLayer(name: 'mask', index: 0, role: LayerRole.mask);
  state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: source.id));
  return (state: state, source: source, mask: mask);
}

StrokeData _stroke() {
  return StrokeData(
    points: const [Offset(2, 2), Offset(6, 6)],
    size: 4,
    color: _red,
    opacity: 1,
    hardness: 1,
  );
}
