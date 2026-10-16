import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/transform_geometry.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/editor_effects.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/effects/image_editor_effects_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'rotations, flips and crop work in place; only the first four transform',
    () {
      final inPlace = {
        for (final type in EditorEffectType.values)
          if (editorEffectWorksInPlace(type)) type,
      };
      expect(inPlace, {
        EditorEffectType.rotateLeft,
        EditorEffectType.rotateRight,
        EditorEffectType.flipHorizontal,
        EditorEffectType.flipVertical,
        EditorEffectType.cropToSelection,
      });
      for (final type in EditorEffectType.values) {
        expect(
          ImageEditorEffectsController.layerTransformFor(type) != null,
          inPlace.contains(type) && type != EditorEffectType.cropToSelection,
          reason: type.name,
        );
      }

      final identity = TransformParams.identity(
        const Rect.fromLTWH(0, 0, 8, 4),
      );
      expect(
        ImageEditorEffectsController.layerTransformFor(
          EditorEffectType.rotateRight,
        )!(identity).rotation,
        closeTo(math.pi / 2, 1e-12),
      );
      expect(
        ImageEditorEffectsController.layerTransformFor(
          EditorEffectType.rotateLeft,
        )!(identity).rotation,
        closeTo(-math.pi / 2, 1e-12),
      );
      expect(
        ImageEditorEffectsController.layerTransformFor(
          EditorEffectType.flipVertical,
        )!(identity).scaleY,
        -1,
      );
    },
  );

  group('rotation', () {
    testWidgets('preview shows the frame exactly as it will be applied', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer();

        final preview = await _preview(effects, EditorEffectType.rotateRight);
        expect(preview.width, 8);
        expect(preview.height, 4);
        // 4×8 的结果居中摆在 8×4 的取景框里，左右各空出两列
        expect(preview.getPixel(0, 1).a, 0);
        expect(preview.getPixel(7, 1).a, 0);
        expect(preview.getPixel(3, 1).a, 255);
        expect(state.historyManager.canUndo, isFalse);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 4));
      });
    });

    testWidgets('with a selection only the selected pixels turn', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer();
        state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 4, 2)));

        final preview = await _preview(effects, EditorEffectType.rotateRight);
        expect(preview.getPixel(6, 3).a, 255, reason: 'outside the selection');
        expect(preview.getPixel(0, 0).a, 0, reason: 'vacated by the turn');
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 4));
      });
    });

    testWidgets('applying keeps every pixel in one undo step', (tester) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer();

        expect(
          effects.applyInPlace(EditorEffectType.rotateRight),
          InPlaceEffectOutcome.applied,
        );
        expect(layer.contentBounds, const Rect.fromLTWH(2, -2, 4, 8));
        expect(state.layerTransformer.isActive, isFalse);
        expect(state.historyManager.undoStackSize, 1);

        state.undo();
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 4));
      });
    });
  });

  group('crop to selection', () {
    testWidgets('keeps the selected box in place and clears the rest', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer();
        state.setSelection(Path()..addRect(const Rect.fromLTWH(2, 1, 3, 2)));

        final preview = await _preview(
          effects,
          EditorEffectType.cropToSelection,
        );
        expect(preview.width, 8);
        expect(preview.height, 4);
        expect(preview.getPixel(3, 2).a, 255);
        expect(preview.getPixel(0, 0).a, 0);
        expect(preview.getPixel(6, 3).a, 0);

        expect(
          effects.applyInPlace(EditorEffectType.cropToSelection),
          InPlaceEffectOutcome.applied,
        );
        expect(layer.contentBounds, const Rect.fromLTWH(2, 1, 3, 2));
        final pixels = await LayerPixels.of(
          layer,
          const Rect.fromLTWH(0, 0, 8, 4),
        );
        expect(pixels.at(2, 1), [255, 0, 0, 255]);
        expect(pixels.at(4, 2), [255, 0, 0, 255]);
        expect(pixels.alphaAt(1, 1), 0);
        expect(
          state.selectionPath!.getBounds(),
          const Rect.fromLTWH(2, 1, 3, 2),
        );

        state.undo();
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 4));
      });
    });

    testWidgets('an empty box clears the layer', (tester) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer(
          content: const Size(4, 4),
        );
        state.setSelection(Path()..addRect(const Rect.fromLTWH(5, 0, 2, 2)));

        expect(
          effects.applyInPlace(EditorEffectType.cropToSelection),
          InPlaceEffectOutcome.applied,
        );
        expect(layer.hasContent, isFalse);

        state.undo();
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 4, 4));
      });
    });

    testWidgets('the source layer keeps its extent, even for an empty box', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer(
          content: const Size(4, 4),
        );
        state.setRolePolicy(
          LayerRolePolicy.inpaint(protectedLayerId: layer.id),
        );

        state.setSelection(Path()..addRect(const Rect.fromLTWH(1, 1, 2, 2)));
        effects.applyInPlace(EditorEffectType.cropToSelection);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 4, 4));
        final pixels = await LayerPixels.of(
          layer,
          const Rect.fromLTWH(0, 0, 4, 4),
        );
        expect(pixels.alphaAt(1, 1), 255);
        expect(pixels.alphaAt(0, 0), 0);

        state.setSelection(Path()..addRect(const Rect.fromLTWH(5, 0, 2, 2)));
        effects.applyInPlace(EditorEffectType.cropToSelection);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 4, 4));
      });
    });

    testWidgets('without a selection nothing changes', (tester) async {
      await tester.runAsync(() async {
        final (effects, state, layer) = await _effectsWithLayer();

        expect(
          await effects.inPlacePreview(EditorEffectType.cropToSelection),
          isNull,
        );
        expect(
          effects.applyInPlace(EditorEffectType.cropToSelection),
          InPlaceEffectOutcome.needsSelection,
        );
        expect(state.historyManager.canUndo, isFalse);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 8, 4));
      });
    });
  });
}

Future<img.Image> _preview(
  ImageEditorEffectsController effects,
  EditorEffectType type,
) async {
  final bytes = await effects.inPlacePreview(type);
  return img.decodePng(bytes!)!;
}

Future<(ImageEditorEffectsController, EditorState, Layer)> _effectsWithLayer({
  Size content = const Size(8, 4),
}) async {
  final session = ImageEditorController();
  addTearDown(session.dispose);
  final state = session.editorState..setCanvasSize(const Size(8, 4));
  final layer = state.layerManager.addLayer(name: 'layer');
  final image = await solidImage(
    content.width.round(),
    content.height.round(),
    const Color(0xFFFF0000),
  );
  state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
  return (
    ImageEditorEffectsController(session: session, editorState: state),
    state,
    layer,
  );
}
