import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/models/image/image_stream_chunk.dart';
import 'decoded_memory_image.dart';

class ImageCardFocusedPreview extends StatefulWidget {
  const ImageCardFocusedPreview({
    super.key,
    required this.previewImage,
    required this.placement,
  });

  final Uint8List previewImage;
  final FocusedStreamPreviewPlacement placement;

  @override
  State<ImageCardFocusedPreview> createState() =>
      _ImageCardFocusedPreviewState();
}

class _ImageCardFocusedPreviewState extends State<ImageCardFocusedPreview> {
  ui.Image? _sourceImage;
  ui.Image? _previewImage;
  ui.Image? _maskImage;
  Uint8List? _sourceBytes;
  Uint8List? _previewBytes;
  Uint8List? _maskBytes;
  int _decodeEpoch = 0;

  @override
  void initState() {
    super.initState();
    _decodeChangedImages();
  }

  @override
  void didUpdateWidget(covariant ImageCardFocusedPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _decodeChangedImages();
  }

  @override
  void dispose() {
    _decodeEpoch++;
    _sourceImage?.dispose();
    _previewImage?.dispose();
    _maskImage?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _sourceImage;
    final preview = _previewImage;
    final mask = _maskImage;
    if (source == null || preview == null || mask == null) {
      return DecodedMemoryImage(
        bytes: widget.placement.sourceImage,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return CustomPaint(
      painter: ImageCardFocusedPreviewPainter(
        sourceImage: source,
        previewImage: preview,
        maskImage: mask,
        placement: widget.placement,
      ),
    );
  }

  void _decodeChangedImages() {
    final maskBytes = widget.placement.maskImage;
    if (maskBytes == null || maskBytes.isEmpty) return;
    final sourceChanged = !_sameBytes(
      _sourceBytes,
      widget.placement.sourceImage,
    );
    final previewChanged = !_sameBytes(_previewBytes, widget.previewImage);
    final maskChanged = !_sameBytes(_maskBytes, maskBytes);
    if (!sourceChanged && !previewChanged && !maskChanged) return;
    final epoch = ++_decodeEpoch;
    unawaited(
      Future.wait<ui.Image?>([
        sourceChanged
            ? _decode(widget.placement.sourceImage)
            : Future.value(_sourceImage),
        previewChanged
            ? _decode(widget.previewImage)
            : Future.value(_previewImage),
        maskChanged ? _decode(maskBytes) : Future.value(_maskImage),
      ]).then((images) {
        if (!mounted || epoch != _decodeEpoch) {
          if (sourceChanged) images[0]?.dispose();
          if (previewChanged) images[1]?.dispose();
          if (maskChanged) images[2]?.dispose();
          return;
        }
        setState(() {
          if (sourceChanged) {
            _sourceImage?.dispose();
            _sourceImage = images[0];
            _sourceBytes = widget.placement.sourceImage;
          }
          if (previewChanged) {
            _previewImage?.dispose();
            _previewImage = images[1];
            _previewBytes = widget.previewImage;
          }
          if (maskChanged) {
            _maskImage?.dispose();
            _maskImage = images[2];
            _maskBytes = maskBytes;
          }
        });
      }),
    );
  }

  static bool _sameBytes(Uint8List? first, Uint8List second) =>
      identical(first, second) || (first != null && listEquals(first, second));

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      return await decodeImageFromList(bytes);
    } catch (_) {
      return null;
    }
  }
}

class ImageCardFocusedPreviewPainter extends CustomPainter {
  ImageCardFocusedPreviewPainter({
    required this.sourceImage,
    required this.previewImage,
    required this.maskImage,
    required this.placement,
  });

  final ui.Image sourceImage;
  final ui.Image previewImage;
  final ui.Image maskImage;
  final FocusedStreamPreviewPlacement placement;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;
    _drawCoverImage(canvas, sourceImage, Offset.zero & size, paint);
    final x = placement.xPercent.clamp(0.0, 1.0).toDouble();
    final y = placement.yPercent.clamp(0.0, 1.0).toDouble();
    final width = placement.widthPercent.clamp(0.0, 1.0 - x).toDouble();
    final height = placement.heightPercent.clamp(0.0, 1.0 - y).toDouble();
    if (width <= 0 || height <= 0) return;
    final output = Rect.fromLTWH(
      size.width * x,
      size.height * y,
      math.max(1, size.width * width),
      math.max(1, size.height * height),
    );
    canvas.saveLayer(output, Paint());
    canvas.drawImageRect(
      previewImage,
      Rect.fromLTWH(
        0,
        0,
        previewImage.width.toDouble(),
        previewImage.height.toDouble(),
      ),
      output,
      paint,
    );
    canvas.drawImageRect(
      maskImage,
      Rect.fromLTWH(
        0,
        0,
        maskImage.width.toDouble(),
        maskImage.height.toDouble(),
      ),
      output,
      Paint()
        ..filterQuality = FilterQuality.low
        ..isAntiAlias = false
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  void _drawCoverImage(
    Canvas canvas,
    ui.Image image,
    Rect output,
    Paint paint,
  ) {
    final input = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, input, output.size);
    canvas.drawImageRect(
      image,
      Alignment.center.inscribe(fitted.source, Offset.zero & input),
      Alignment.center.inscribe(fitted.destination, output),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ImageCardFocusedPreviewPainter oldDelegate) =>
      oldDelegate.sourceImage != sourceImage ||
      oldDelegate.previewImage != previewImage ||
      oldDelegate.maskImage != maskImage ||
      oldDelegate.placement.xPercent != placement.xPercent ||
      oldDelegate.placement.yPercent != placement.yPercent ||
      oldDelegate.placement.widthPercent != placement.widthPercent ||
      oldDelegate.placement.heightPercent != placement.heightPercent;
}
