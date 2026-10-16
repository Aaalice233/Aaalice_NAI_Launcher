import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../core/utils/picture_png_encoder.dart';

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
    try {
      return await resampleImageAsPng(
        source,
        width: width,
        height: height,
        filterQuality: quality,
      );
    } finally {
      source.dispose();
    }
  }
}
