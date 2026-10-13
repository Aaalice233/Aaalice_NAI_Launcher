import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/stroke_preview_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/layer_role_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/layer_role.dart';

Future<ByteData> _paintPreview(
  EditorState state, {
  Size size = const Size(48, 48),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  StrokePreviewPainter(state: state).paint(canvas, size);
  final picture = recorder.endRecording();
  addTearDown(picture.dispose);

  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  addTearDown(image.dispose);

  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);
  return byteData!;
}

Color _pixelAt(ByteData byteData, int width, int x, int y) {
  final bytes = byteData.buffer.asUint8List();
  final index = (y * width + x) * 4;
  return Color.fromARGB(
    bytes[index + 3],
    bytes[index],
    bytes[index + 1],
    bytes[index + 2],
  );
}

int _alphaByte(Color color) {
  return (color.a * 255).round().clamp(0, 255);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('draws a brush single-point preview as a filled circle', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.setForegroundColor(const Color(0xFFFF0000));
    state.setBrushSize(8);
    state.setBrushOpacity(1);
    state.setBrushHardness(1);
    state.startStroke(const Offset(24, 24));

    final byteData = await _paintPreview(state);
    final center = _pixelAt(byteData, 48, 24, 24);
    final outside = _pixelAt(byteData, 48, 2, 2);

    expect(center.r, greaterThan(0.8));
    expect(center.g, lessThan(0.2));
    expect(_alphaByte(center), greaterThan(200));
    expect(_alphaByte(outside), 0);
  });

  test('draws a brush multi-point preview path', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.setForegroundColor(const Color(0xFF0000FF));
    state.setBrushSize(6);
    state.setBrushOpacity(1);
    state.setBrushHardness(1);
    state.startStroke(const Offset(8, 24));
    state.updateStroke(const Offset(24, 24));
    state.updateStroke(const Offset(40, 24));

    final byteData = await _paintPreview(state);
    final pathPixel = _pixelAt(byteData, 48, 24, 24);

    expect(pathPixel.b, greaterThan(0.8));
    expect(_alphaByte(pathPixel), greaterThan(200));
  });

  test('leaves brush strokes on a mask layer to the layer painter', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);
    final image = state.layerManager.addLayer(name: 'image');
    final mask = state.layerManager.addLayer(
      name: 'mask',
      index: 0,
      role: LayerRole.mask,
    );
    state.setRolePolicy(LayerRolePolicy.inpaint(protectedLayerId: image.id));
    state.layerManager.setActiveLayer(mask.id);
    state.setBrushSize(16);
    state.startStroke(const Offset(24, 24));

    final byteData = await _paintPreview(state);

    expect(state.isPaintingMask, isTrue);
    expect(_alphaByte(_pixelAt(byteData, 48, 24, 24)), 0);
  });

  test('draws eraser preview as semi-transparent grey', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.setToolById('eraser');
    state.startStroke(const Offset(24, 24));

    final byteData = await _paintPreview(state);
    final center = _pixelAt(byteData, 48, 24, 24);

    expect(center.r, closeTo(center.g, 0.02));
    expect(center.g, closeTo(center.b, 0.02));
    expect(_alphaByte(center), inInclusiveRange(100, 160));
  });

  test('draws blur preview as low-opacity blue', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.setToolById('blur');
    state.startStroke(const Offset(24, 24));

    final byteData = await _paintPreview(state);
    final center = _pixelAt(byteData, 48, 24, 24);

    expect(center.b, greaterThan(center.r));
    expect(center.b, greaterThan(center.g));
    expect(_alphaByte(center), inInclusiveRange(20, 100));
  });

  group('soft strokes in a magnified view', () {
    const viewport = Size(100, 100);

    // 放大 8 倍并让文档 (200, 200) 落在视口中央
    EditorState createState({required double hardness, double scale = 8}) {
      final state = EditorState()..setCanvasSize(const Size(400, 400));
      addTearDown(state.dispose);
      state.setForegroundColor(const Color(0xFFFF0000));
      state.setBrushSize(20);
      state.setBrushOpacity(1);
      state.setBrushHardness(hardness);
      state.canvasController
        ..setViewportSize(viewport)
        ..setScale(scale)
        ..setOffset(Offset(50 - 200 * scale, 50 - 200 * scale));
      state.startStroke(const Offset(120, 120));
      state.updateStroke(const Offset(200, 200));
      state.updateStroke(const Offset(280, 260));
      return state;
    }

    List<Symbol> drawCalls(EditorState state) {
      final canvas = TestRecordingCanvas();
      StrokePreviewPainter(state: state).paint(canvas, viewport);
      return [
        for (final call in canvas.invocations)
          if (call.invocation.memberName.toString().contains('draw'))
            call.invocation.memberName,
      ];
    }

    test('are rendered at document resolution within the viewport', () {
      final state = createState(hardness: 0.5);
      final canvas = TestRecordingCanvas();
      StrokePreviewPainter(state: state).paint(canvas, viewport);

      final images = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawImage)
            call.invocation.positionalArguments[0] as ui.Image,
      ];
      expect(drawCalls(state), [#drawImage]);
      // 可见文档区域 12.5 像素见方，各边外扩 1 像素再向外取整后至多 16
      expect(images.single.width, lessThanOrEqualTo(16));
      expect(images.single.height, lessThanOrEqualTo(16));
    });

    test('still show the stroke color under the cursor', () async {
      final state = createState(hardness: 0.5);

      final byteData = await _paintPreview(state, size: viewport);
      final center = _pixelAt(byteData, 100, 50, 50);

      expect(center.r, greaterThan(0.8));
      expect(_alphaByte(center), greaterThan(200));
    });

    test('stay vector when the view is not magnified', () {
      expect(
        drawCalls(createState(hardness: 0.5, scale: 1)),
        [#drawPath],
      );
    });

    test('hard strokes stay vector when magnified', () {
      expect(drawCalls(createState(hardness: 1)), [#drawPath]);
    });
  });

  test('listens to canvas transform changes', () {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.startStroke(const Offset(24, 24));
    final painter = StrokePreviewPainter(state: state);

    var repaintCount = 0;
    void onRepaint() {
      repaintCount++;
    }

    painter.addListener(onRepaint);
    addTearDown(() => painter.removeListener(onRepaint));

    state.canvasController.setOffset(const Offset(10, 0));

    expect(repaintCount, 1);
  });

  test('applies canvas transform while painting preview', () async {
    final state = EditorState()..setCanvasSize(const Size(48, 48));
    addTearDown(state.dispose);

    state.setForegroundColor(const Color(0xFFFF0000));
    state.setBrushSize(8);
    state.setBrushOpacity(1);
    state.setBrushHardness(1);
    state.startStroke(const Offset(24, 24));
    state.canvasController.setOffset(const Offset(10, 0));

    final byteData = await _paintPreview(state, size: const Size(64, 48));

    expect(_alphaByte(_pixelAt(byteData, 64, 24, 24)), 0);
    expect(_alphaByte(_pixelAt(byteData, 64, 34, 24)), greaterThan(200));
  });
}
