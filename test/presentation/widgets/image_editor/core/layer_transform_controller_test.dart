import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../layers/layer_pixel_test_helpers.dart';

const _red = [255, 0, 0, 255];
const _blue = [0, 0, 255, 255];
const _mouse = PointerDeviceKind.mouse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('armed box', () {
    testWidgets('frames the whole layer, or the selection when there is one', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        expect(transformer.params!.source, layer.contentBounds);
        expect(transformer.isActive, isFalse);

        state.setSelection(Path()..addRect(const Rect.fromLTWH(8, 8, 16, 16)));
        expect(transformer.params!.source, const Rect.fromLTWH(8, 8, 16, 16));
      });
    });

    testWidgets('dragging inside the box stays a plain move', (tester) async {
      await tester.runAsync(() async {
        final (state, _) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        expect(transformer.pointerDown(const Offset(32, 32), _mouse), isFalse);
        expect(
          transformer.pointerDown(const Offset(400, 400), _mouse),
          isFalse,
        );
        expect(transformer.isActive, isFalse);
      });
    });
  });

  group('session', () {
    testWidgets('corner drags write back and amend a single history entry', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        expect(transformer.pointerDown(const Offset(64, 64), _mouse), isTrue);
        expect(transformer.isActive, isTrue);
        transformer.pointerMove(
          const Offset(128, 128),
          shift: false,
          alt: false,
        );
        expect(layer.preview, isA<LayerTransformPreview>());
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));

        transformer.pointerUp();
        expect(layer.preview, isNull);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 128, 128));
        expect(state.historyManager.undoStackSize, 1);
        final pixels = await LayerPixels.of(layer, layer.contentBounds);
        expect(pixels.at(10, 10), _red);
        expect(pixels.at(100, 10), _blue);

        expect(transformer.pointerDown(const Offset(128, 128), _mouse), isTrue);
        transformer.pointerMove(const Offset(32, 32), shift: false, alt: false);
        transformer.pointerUp();
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 32, 32));
        expect(state.historyManager.undoStackSize, 1);

        state.undo();
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));
        expect(transformer.isActive, isFalse);
      });
    });

    testWidgets('cancel restores the layer and leaves no history', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        transformer.pointerDown(const Offset(64, 64), _mouse);
        transformer.pointerMove(const Offset(96, 96), shift: false, alt: false);
        transformer.pointerUp();
        expect(layer.contentBounds.size, const Size(96, 96));

        transformer.cancel();
        expect(transformer.isActive, isFalse);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));
        expect(state.historyManager.canUndo, isFalse);
        expect(state.historyManager.canRedo, isFalse);
      });
    });

    testWidgets('cancel brings back the redo history it replaced', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;
        transformer
          ..nudge(const Offset(1, 0))
          ..apply()
          ..nudge(const Offset(2, 0))
          ..apply();
        state.undo();
        expect(layer.contentBounds.left, 1);

        transformer.nudge(const Offset(5, 0));
        expect(state.historyManager.canRedo, isFalse);
        transformer.cancel();
        expect(layer.contentBounds.left, 1);
        expect(state.historyManager.redoStackSize, 1);

        state.redo();
        expect(layer.contentBounds.left, 3);
      });
    });

    testWidgets('every step resamples from the captured pixels only once', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer(stripes: true);
        final transformer = state.layerTransformer;
        final before = await LayerPixels.of(layer, layer.contentBounds);

        expect(
          transformer.update((p) => p.withScale(x: 0.25, y: 0.25)),
          isTrue,
        );
        expect(layer.contentBounds.size, const Size(16, 16));
        expect(transformer.update((p) => p.withScale(x: 1, y: 1)), isTrue);

        final after = await LayerPixels.of(layer, layer.contentBounds);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));
        for (var x = 0.0; x < 64; x++) {
          expect(after.at(x, 5), before.at(x, 5), reason: 'column $x');
        }
      });
    });

    testWidgets('pixels outside the selection are never resampled', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer(stripes: true);
        final before = await LayerPixels.of(layer, layer.contentBounds);
        state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 16, 16)));

        state.layerTransformer.update((p) => p.withScale(x: 1.5, y: 1.5));

        final after = await LayerPixels.of(layer, layer.contentBounds);
        for (var x = 32.0; x < 64; x++) {
          expect(after.at(x, 40), before.at(x, 40), reason: 'column $x');
        }
      });
    });

    testWidgets('selected pixels rotate with their outline', (tester) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 32, 16)));
        final transformer = state.layerTransformer;

        transformer.update((p) => p.withRotation(math.pi / 2));

        final selection = state.selectionPath!.getBounds();
        expect(selection.size, const Size(16, 32));
        expect(selection.center, const Offset(16, 8));
        final pixels = await LayerPixels.of(
          layer,
          const Rect.fromLTWH(-16, -16, 96, 96),
        );
        expect(pixels.alphaAt(2, 2), 0, reason: 'vacated corner');
        expect(pixels.at(16, -6), _red, reason: 'rotated pixels');
        expect(pixels.at(40, 40), _blue, reason: 'outside the selection');

        state.undo();
        expect(
          state.selectionPath!.getBounds(),
          const Rect.fromLTWH(0, 0, 32, 16),
        );
      });
    });

    testWidgets('a quarter turn of a non-square layer keeps every pixel', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer(size: const Size(8, 4));
        state.setCanvasSize(const Size(8, 4));

        state.layerTransformer.update((p) => p.withRotation(math.pi / 2));
        state.layerTransformer.apply();

        expect(layer.contentBounds, const Rect.fromLTWH(2, -2, 4, 8));
        final pixels = await LayerPixels.of(layer, layer.contentBounds);
        var opaque = 0;
        for (var y = -2.0; y < 6; y++) {
          for (var x = 2.0; x < 6; x++) {
            if (pixels.alphaAt(x, y) == 255) opaque++;
          }
        }
        expect(opaque, 32);
      });
    });

    testWidgets('nudges and flips amend the open session', (tester) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        transformer.flip(horizontal: true);
        transformer.nudge(const Offset(3, 0));
        expect(state.historyManager.undoStackSize, 1);
        expect(layer.contentBounds, const Rect.fromLTWH(3, 0, 64, 64));
        final pixels = await LayerPixels.of(layer, layer.contentBounds);
        expect(pixels.at(6, 10), _blue, reason: 'mirrored');
      });
    });

    testWidgets('two-finger pinch scales around the fingers', (tester) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;

        expect(transformer.pinchStart(const Offset(32, 32)), isFalse);
        expect(transformer.begin(), isTrue);
        expect(transformer.pinchStart(const Offset(32, 32)), isTrue);
        transformer.pinchUpdate(const Offset(42, 32), 2, 0);
        expect(layer.preview, isA<LayerTransformPreview>());
        transformer.pinchEnd();

        expect(layer.contentBounds, const Rect.fromLTWH(-22, -32, 128, 128));
      });
    });

    testWidgets('bakePreview computes a result without touching history', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final baked = state.layerTransformer.bakePreview(
          (p) => p.withScale(x: 0.5, y: 0.5),
        );
        addTearDown(() => baked?.dispose());

        expect(baked!.bounds, const Rect.fromLTWH(16, 16, 32, 32));
        expect(state.historyManager.canUndo, isFalse);
        expect(state.layerTransformer.isActive, isFalse);
        expect(layer.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));
      });
    });
  });

  group('session ends', () {
    testWidgets('when another action lands on the undo stack', (tester) async {
      await tester.runAsync(() async {
        final (state, _) = await _stateWithLayer();
        state.layerTransformer.update((p) => p.withScale(x: 0.5, y: 0.5));
        expect(state.layerTransformer.isActive, isTrue);

        state.layerCommands.addLayer(name: 'other');
        expect(state.layerTransformer.isActive, isFalse);
      });
    });

    testWidgets('when the active layer or the selection changes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final other = state.layerManager.addLayer(name: 'other', index: 0);
        state.layerManager.setActiveLayer(layer.id);

        state.layerTransformer.begin();
        state.layerManager.setActiveLayer(other.id);
        expect(state.layerTransformer.isActive, isFalse);

        state.layerManager.setActiveLayer(layer.id);
        state.layerTransformer.begin();
        state.setSelection(Path()..addRect(const Rect.fromLTWH(0, 0, 8, 8)));
        expect(state.layerTransformer.isActive, isFalse);
      });
    });

    testWidgets('when the layer was edited outside the session', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, layer) = await _stateWithLayer();
        final transformer = state.layerTransformer;
        transformer.begin();

        state.layerManager.translateLayer(layer.id, const Offset(10, 0));
        // 截下的像素已过期，按当前内容重新开始
        expect(transformer.pointerDown(const Offset(74, 64), _mouse), isTrue);
        expect(transformer.params!.source, const Rect.fromLTWH(10, 0, 64, 64));
        transformer.pointerCancel();
      });
    });
  });

  group('protected source layer', () {
    testWidgets('only selected pixels transform, inside the original extent', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, source) = await _stateWithLayer();
        state.layerManager.addLayer(
          name: 'mask',
          index: 0,
          role: LayerRole.mask,
        );
        state.setRolePolicy(
          LayerRolePolicy.inpaint(protectedLayerId: source.id),
        );
        state.layerManager.setActiveLayer(source.id);
        final transformer = state.layerTransformer;

        expect(transformer.params, isNull);
        expect(transformer.begin(), isFalse);

        state.setSelection(
          Path()..addRect(const Rect.fromLTWH(48, 48, 16, 16)),
        );
        expect(transformer.update((p) => p.withScale(x: 3, y: 3)), isTrue);
        expect(source.contentBounds, const Rect.fromLTWH(0, 0, 64, 64));
      });
    });
  });

  group('placing an imported image', () {
    testWidgets('lands centred at native size and cancel removes it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, original) = await _stateWithLayer();
        state.setCanvasSize(const Size(512, 512));
        final transformer = state.layerTransformer;

        expect(
          transformer.placeImage(
            await _patternImage(const Size(64, 64)),
            name: 'photo.png',
          ),
          isTrue,
        );
        final placed = state.layerManager.activeLayer!;
        expect(placed, isNot(same(original)));
        expect(placed.name, 'photo.png');
        expect(placed.contentBounds, const Rect.fromLTWH(224, 224, 64, 64));
        expect(transformer.isActive, isTrue);
        expect(transformer.params!.size, const Size(64, 64));

        transformer.cancel();
        expect(state.layerManager.getLayerById(placed.id), isNull);
        expect(state.historyManager.canUndo, isFalse);
      });
    });

    testWidgets('oversized images shrink to fit and undo removes them', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final (state, _) = await _stateWithLayer();
        state.setCanvasSize(const Size(512, 512));
        final transformer = state.layerTransformer;

        transformer.placeImage(
          await _patternImage(const Size(2048, 1024)),
          name: 'wide.png',
        );
        final placed = state.layerManager.activeLayer!;
        expect(placed.contentBounds, const Rect.fromLTWH(0, 128, 512, 256));

        // 会话从原图重新计算，放大不经过缩小后的中间结果
        transformer.update((p) => p.withScale(x: 0.5, y: 0.5));
        transformer.apply();
        expect(placed.contentBounds, const Rect.fromLTWH(-256, 0, 1024, 512));
        expect(state.historyManager.undoStackSize, 1);
        final pixels = await LayerPixels.of(placed, placed.contentBounds);
        expect(pixels.at(0, 200), _red);
        expect(pixels.at(600, 200), _blue);

        state.undo();
        expect(state.layerManager.getLayerById(placed.id), isNull);
      });
    });
  });
}

Future<(EditorState, Layer)> _stateWithLayer({
  Size size = const Size(64, 64),
  bool stripes = false,
}) async {
  final state = EditorState();
  addTearDown(state.dispose);
  final layer = state.layerManager.addLayer(name: 'layer');
  final image = stripes ? await _stripesImage(size) : await _patternImage(size);
  state.layerManager.replaceLayerBaseImageSync(layer.id, image, null);
  return (state, layer);
}

/// 左半红、右半蓝，调用方负责释放
Future<ui.Image> _patternImage(Size size) {
  return _render(size, (canvas) {
    final half = size.width / 2;
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, half, size.height),
        Paint()..color = const Color(0xFFFF0000),
      )
      ..drawRect(
        Rect.fromLTWH(half, 0, half, size.height),
        Paint()..color = const Color(0xFF0000FF),
      );
  });
}

/// 1 像素宽的红蓝竖条，任何多余的插值都会让颜色混合
Future<ui.Image> _stripesImage(Size size) {
  return _render(size, (canvas) {
    for (var x = 0; x < size.width; x++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 1, size.height),
        Paint()
          ..color = x.isEven
              ? const Color(0xFFFF0000)
              : const Color(0xFF0000FF),
      );
    }
  });
}

Future<ui.Image> _render(Size size, void Function(Canvas canvas) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size.width.round(), size.height.round());
  } finally {
    picture.dispose();
  }
}
