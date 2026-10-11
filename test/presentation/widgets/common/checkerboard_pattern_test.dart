import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/checkerboard_pattern.dart';

const _even = Color(0xFFE0E0E0);
const _odd = Color(0xFF606060);
const _pattern = CheckerboardPattern(
  cellSize: 8,
  evenColor: _even,
  oddColor: _odd,
);

Future<ByteData> _render(
  int width,
  int height,
  void Function(Canvas canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final picture = recorder.endRecording();
  addTearDown(picture.dispose);
  final image = await picture.toImage(width, height);
  addTearDown(image.dispose);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  expect(bytes, isNotNull);
  return bytes!;
}

Color _pixelAt(ByteData bytes, int width, int x, int y) {
  final data = bytes.buffer.asUint8List();
  final index = (y * width + x) * 4;
  return Color.fromARGB(
    data[index + 3],
    data[index],
    data[index + 1],
    data[index + 2],
  );
}

void main() {
  setUp(CheckerboardPattern.debugReset);
  tearDown(CheckerboardPattern.debugReset);

  test('cells alternate starting with the even color at the origin', () async {
    final pixels = await _render(
      32,
      32,
      (canvas) => _pattern.paint(canvas, const Rect.fromLTWH(0, 0, 32, 32)),
    );

    expect(_pixelAt(pixels, 32, 4, 4), _even);
    expect(_pixelAt(pixels, 32, 12, 4), _odd);
    expect(_pixelAt(pixels, 32, 4, 12), _odd);
    expect(_pixelAt(pixels, 32, 12, 12), _even);
    expect(_pixelAt(pixels, 32, 28, 28), _even);
  });

  test('grid is anchored at the given origin', () async {
    final pixels = await _render(
      32,
      32,
      (canvas) => _pattern.paint(
        canvas,
        const Rect.fromLTWH(0, 0, 32, 32),
        origin: const Offset(8, 0),
      ),
    );

    expect(_pixelAt(pixels, 32, 4, 4), _odd);
    expect(_pixelAt(pixels, 32, 12, 4), _even);
  });

  test('only the requested rect is filled', () async {
    final pixels = await _render(
      32,
      32,
      (canvas) => _pattern.paint(canvas, const Rect.fromLTWH(0, 0, 20, 32)),
    );

    expect(_pixelAt(pixels, 32, 18, 4).a, 1);
    expect(_pixelAt(pixels, 32, 24, 4).a, 0);
  });

  test('magnified cells keep their colors and grid', () async {
    final pixels = await _render(64, 64, (canvas) {
      canvas.scale(4);
      _pattern.paint(canvas, const Rect.fromLTWH(0, 0, 16, 16), pixelScale: 4);
    });

    expect(_pixelAt(pixels, 64, 16, 16), _even);
    expect(_pixelAt(pixels, 64, 48, 16), _odd);
    expect(_pixelAt(pixels, 64, 48, 48), _even);
  });

  test('area and repaints do not create new textures', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _pattern.paint(canvas, const Rect.fromLTWH(0, 0, 32, 32));
    _pattern.paint(canvas, const Rect.fromLTWH(0, 0, 4096, 4096));
    recorder.endRecording().dispose();

    expect(CheckerboardPattern.debugTileBuildCount, 1);
  });

  test('pixel scales within one power-of-two bucket share a texture', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, 32, 32);
    _pattern.paint(canvas, rect, pixelScale: 2.5);
    _pattern.paint(canvas, rect, pixelScale: 3.75);
    expect(CheckerboardPattern.debugTileBuildCount, 1);

    _pattern.paint(canvas, rect, pixelScale: 4.5);
    _pattern.paint(canvas, rect, pixelScale: 1000);
    recorder.endRecording().dispose();

    expect(CheckerboardPattern.debugTileBuildCount, 3);
  });

  test('texture cache keeps a bounded number of tiles', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 1; i <= 12; i++) {
      CheckerboardPattern(
        cellSize: i.toDouble(),
        evenColor: _even,
        oddColor: _odd,
      ).paint(canvas, const Rect.fromLTWH(0, 0, 16, 16));
    }
    recorder.endRecording().dispose();

    expect(CheckerboardPattern.debugTileBuildCount, 12);
    expect(CheckerboardPattern.debugCachedTileCount, 8);
  });
}
