import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

abstract interface class ImageEditorIo {
  Future<ui.Codec> instantiateCodec(Uint8List bytes);
}

class FlutterImageEditorIo implements ImageEditorIo {
  const FlutterImageEditorIo();

  @override
  Future<ui.Codec> instantiateCodec(Uint8List bytes) =>
      ui.instantiateImageCodec(bytes);
}

/// Decodes editor inputs and owns the codec lifetime.
class ImageDecodeService {
  const ImageDecodeService({ImageEditorIo io = const FlutterImageEditorIo()})
    : _io = io;

  final ImageEditorIo _io;

  Future<ui.Image> decode(Uint8List bytes) async {
    final codec = await _io.instantiateCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> resize(
    Uint8List bytes, {
    required int width,
    required int height,
    ui.FilterQuality quality = ui.FilterQuality.medium,
  }) async {
    final source = await decode(bytes);
    ui.Picture? picture;
    ui.Image? target;
    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
          0,
          0,
          source.width.toDouble(),
          source.height.toDouble(),
        ),
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint()..filterQuality = quality,
      );
      picture = recorder.endRecording();
      target = await picture.toImage(width, height);
      final data = await target.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Failed to encode editor image.');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      target?.dispose();
      picture?.dispose();
      source.dispose();
    }
  }
}
