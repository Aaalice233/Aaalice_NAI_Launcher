import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/layer_painter.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';

Future<Color> _paintCanvasPixel({
  required bool showTransparentCanvasBackground,
}) async {
  final state = EditorState()..setCanvasSize(const Size(32, 32));
  addTearDown(state.dispose);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  LayerPainter(
    state: state,
    showTransparentCanvasBackground: showTransparentCanvasBackground,
  ).paint(canvas, const Size(32, 32));

  final picture = recorder.endRecording();
  addTearDown(picture.dispose);
  final image = await picture.toImage(32, 32);
  addTearDown(image.dispose);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(byteData, isNotNull);

  final bytes = byteData!.buffer.asUint8List();
  return Color.fromARGB(bytes[3], bytes[0], bytes[1], bytes[2]);
}

void _paintLayer(EditorState state) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  LayerPainter(
    state: state,
    showTransparentCanvasBackground: true,
  ).paint(canvas, state.canvasSize);

  recorder.endRecording().dispose();
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

int _redByte(Color color) {
  return (color.r * 255).round().clamp(0, 255);
}

Future<ui.Image> _createTwoToneImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 2, 4),
    Paint()..color = Colors.black,
  );
  canvas.drawRect(
    const Rect.fromLTWH(2, 0, 2, 4),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(4, 4);
  } finally {
    picture.dispose();
  }
}

void main() {
  setUp(LayerPainter.debugResetCheckerboardCache);
  tearDown(LayerPainter.debugResetCheckerboardCache);

  test('default canvas background remains white', () async {
    final color = await _paintCanvasPixel(
      showTransparentCanvasBackground: false,
    );

    expect(color, Colors.white);
  });

  test('transparent canvas background shows checkerboard', () async {
    final color = await _paintCanvasPixel(
      showTransparentCanvasBackground: true,
    );

    expect(color, isNot(Colors.white));
  });

  test('checkerboard cache key changes when canvas size changes', () {
    const baseKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 16,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );
    const resizedKey = CheckerboardCacheKey(
      canvasSize: Size(64, 32),
      cellSize: 16,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );

    expect(resizedKey, isNot(baseKey));
  });

  test('checkerboard cache key changes when cell size changes', () {
    const baseKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 16,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );
    const sameCellSizeKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 16,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );
    const changedCellSizeKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 8,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );

    expect(sameCellSizeKey, baseKey);
    expect(changedCellSizeKey, isNot(baseKey));
  });

  test('checkerboard cache key changes when checkerboard colors change', () {
    const baseKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 16,
      color1: Color(0xFFE0E0E0),
      color2: Color(0xFFF5F5F5),
    );
    const recoloredKey = CheckerboardCacheKey(
      canvasSize: Size(32, 32),
      cellSize: 16,
      color1: Color(0xFFCCCCCC),
      color2: Color(0xFFFFFFFF),
    );

    expect(recoloredKey, isNot(baseKey));
  });

  test('checkerboard cache reuses recorded picture for repeated size', () {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    _paintLayer(state);
    final firstKey = LayerPainter.debugCheckerboardCacheKey;

    expect(LayerPainter.debugCheckerboardRecordCount, 1);
    expect(firstKey, isNotNull);

    _paintLayer(state);

    expect(LayerPainter.debugCheckerboardRecordCount, 1);
    expect(LayerPainter.debugCheckerboardCacheKey, firstKey);
  });

  test('checkerboard cache rebuilds when canvas size changes', () {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    _paintLayer(state);
    final firstKey = LayerPainter.debugCheckerboardCacheKey;

    state.setCanvasSize(const Size(64, 32));
    _paintLayer(state);

    expect(LayerPainter.debugCheckerboardRecordCount, 2);
    expect(LayerPainter.debugCheckerboardCacheKey, isNot(firstKey));
    expect(
      LayerPainter.debugCheckerboardCacheKey?.canvasSize,
      const Size(64, 32),
    );
  });

  test('checkerboard paint stays clipped to non-multiple canvas size',
      () async {
    final state = EditorState()..setCanvasSize(const Size(33, 33));
    addTearDown(state.dispose);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    LayerPainter(
      state: state,
      showTransparentCanvasBackground: true,
    ).paint(canvas, const Size(48, 48));

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);

    final image = await picture.toImage(48, 48);
    addTearDown(image.dispose);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);

    final insidePixel = _pixelAt(byteData!, 48, 1, 1);
    final outsidePixel = _pixelAt(byteData, 48, 34, 16);

    expect(_alphaByte(insidePixel), greaterThan(0));
    expect(_alphaByte(outsidePixel), 0);
  });

  test('layer painter does not draw live current stroke preview', () async {
    final state = EditorState()..setCanvasSize(const Size(32, 32));
    addTearDown(state.dispose);

    state.startStroke(const Offset(16, 16));

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    LayerPainter(
      state: state,
      showTransparentCanvasBackground: false,
    ).paint(canvas, const Size(32, 32));

    final picture = recorder.endRecording();
    addTearDown(picture.dispose);

    final image = await picture.toImage(32, 32);
    addTearDown(image.dispose);

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(byteData, isNotNull);

    expect(_pixelAt(byteData!, 32, 16, 16), Colors.white);
  });

  test(
    'layer painter filters bitmap layers at fractional sample positions',
    () async {
      final state = EditorState()..setCanvasSize(const Size(4, 4));
      addTearDown(state.dispose);

      final sourceImage = await _createTwoToneImage();
      state.layerManager.addLayerFromUiImage(sourceImage, name: 'two-tone');
      state.canvasController.setViewportSize(const Size(3, 3));
      state.canvasController.setScale(0.75);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      LayerPainter(
        state: state,
        showTransparentCanvasBackground: false,
      ).paint(canvas, const Size(3, 3));

      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final image = await picture.toImage(3, 3);
      addTearDown(image.dispose);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(byteData, isNotNull);

      final boundaryRed = _redByte(_pixelAt(byteData!, 3, 1, 1));
      expect(boundaryRed, greaterThan(0));
      expect(boundaryRed, lessThan(255));
    },
  );
}
