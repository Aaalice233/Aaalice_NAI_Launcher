import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/models/image/image_stream_chunk.dart';

typedef StreamPreviewImageDecoder =
    Future<ui.Image> Function(
      Uint8List bytes, {
      required int? targetWidth,
      required int? targetHeight,
    });

/// Holds the last decoded frame until its replacement is ready.
class ImageCardStreamPreview extends StatefulWidget {
  const ImageCardStreamPreview({
    super.key,
    required this.previewBytes,
    this.placement,
    this.imageDecoder,
  });

  final Uint8List previewBytes;
  final FocusedStreamPreviewPlacement? placement;
  @visibleForTesting
  final StreamPreviewImageDecoder? imageDecoder;

  @override
  State<ImageCardStreamPreview> createState() => _ImageCardStreamPreviewState();
}

class _ImageCardStreamPreviewState extends State<ImageCardStreamPreview> {
  final _preview = _HeldImage();
  final _source = _HeldImage();
  final _mask = _HeldImage();
  bool _resolving = false;

  @override
  void dispose() {
    _preview.dispose();
    _source.dispose();
    _mask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.biggest.isEmpty) {
          _resolveImages(
            constraints.hasBoundedWidth
                ? math.max(1, (constraints.maxWidth * ratio).ceil())
                : null,
            constraints.hasBoundedHeight
                ? math.max(1, (constraints.maxHeight * ratio).ceil())
                : null,
          );
        }
        return CustomPaint(
          painter: ImageCardStreamPreviewPainter(
            previewImage: _preview.image,
            sourceImage: _source.image,
            maskImage: _mask.image,
            placement: widget.placement,
          ),
        );
      },
    );
  }

  void _resolveImages(int? width, int? height) {
    final placement = widget.placement;
    final composited = placement != null && placement.isValid;
    final decoder = widget.imageDecoder ?? _decodePreviewImage;
    _resolving = true;
    _preview.resolve(
      widget.previewBytes,
      width,
      height,
      decoder,
      _onImageChanged,
    );
    _source.resolve(
      composited ? placement.sourceImage : null,
      width,
      height,
      decoder,
      _onImageChanged,
    );
    _mask.resolve(
      composited ? placement.maskImage : null,
      width,
      height,
      decoder,
      _onImageChanged,
    );
    _resolving = false;
  }

  void _onImageChanged() {
    if (_resolving || !mounted) return;
    setState(() {});
  }
}

// Transient frames bypass ImageCache. Each layer owns one displayed image and
// at most one active decode; an incoming burst keeps only its newest request.
class _HeldImage {
  Uint8List? _bytes;
  int? _width;
  int? _height;
  StreamPreviewImageDecoder? _decoder;
  ui.Image? image;
  _PreviewDecodeRequest? _pending;
  int _revision = 0;
  bool _decoding = false;
  bool _disposed = false;

  void resolve(
    Uint8List? bytes,
    int? width,
    int? height,
    StreamPreviewImageDecoder decoder,
    VoidCallback onChanged,
  ) {
    if (_disposed) return;
    if (identical(_bytes, bytes) &&
        _width == width &&
        _height == height &&
        identical(_decoder, decoder)) {
      return;
    }
    _bytes = bytes;
    _width = width;
    _height = height;
    _decoder = decoder;
    final revision = ++_revision;
    if (bytes == null || bytes.isEmpty) {
      _pending = null;
      image?.dispose();
      image = null;
      onChanged();
      return;
    }
    _pending = _PreviewDecodeRequest(
      bytes,
      width,
      height,
      revision,
      decoder,
      onChanged,
    );
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_decoding || _disposed) return;
    _decoding = true;
    try {
      while (!_disposed && _pending != null) {
        final request = _pending!;
        _pending = null;
        final ui.Image decoded;
        try {
          decoded = await request.decoder(
            request.bytes,
            targetWidth: request.width,
            targetHeight: request.height,
          );
        } catch (_) {
          // Invalid replacement frames keep the last successfully decoded image.
          continue;
        }
        if (_disposed || request.revision != _revision) {
          decoded.dispose();
        } else {
          image?.dispose();
          image = decoded;
          request.onChanged();
        }
      }
    } finally {
      _decoding = false;
    }
  }

  void dispose() {
    _disposed = true;
    _pending = null;
    _bytes = null;
    image?.dispose();
    image = null;
  }
}

class _PreviewDecodeRequest {
  const _PreviewDecodeRequest(
    this.bytes,
    this.width,
    this.height,
    this.revision,
    this.decoder,
    this.onChanged,
  );
  final Uint8List bytes;
  final int? width;
  final int? height;
  final int revision;
  final StreamPreviewImageDecoder decoder;
  final VoidCallback onChanged;
}

Future<ui.Image> _decodePreviewImage(
  Uint8List bytes, {
  required int? targetWidth,
  required int? targetHeight,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final requestedScale = math.max(
      targetWidth == null ? 0.0 : targetWidth / descriptor.width,
      targetHeight == null ? 0.0 : targetHeight / descriptor.height,
    );
    final scale = requestedScale <= 0 ? 1.0 : math.min(1.0, requestedScale);
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * scale).ceil()),
      targetHeight: math.max(1, (descriptor.height * scale).ceil()),
    );
    return (await codec.getNextFrame()).image;
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

class ImageCardStreamPreviewPainter extends CustomPainter {
  ImageCardStreamPreviewPainter({
    required this.previewImage,
    required this.sourceImage,
    required this.maskImage,
    required this.placement,
  });

  final ui.Image? previewImage;
  final ui.Image? sourceImage;
  final ui.Image? maskImage;
  final FocusedStreamPreviewPlacement? placement;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;
    final preview = previewImage;
    final placement = this.placement;
    if (placement == null || !placement.isValid) {
      if (preview != null) {
        _drawCoverImage(canvas, preview, Offset.zero & size, paint);
      }
      return;
    }
    final source = sourceImage;
    if (source != null) {
      _drawCoverImage(canvas, source, Offset.zero & size, paint);
    }
    final mask = maskImage;
    // 蒙版还没解码时画补丁会露出未裁剪的矩形，宁可只留底图。
    if (preview == null || (placement.hasMask && mask == null)) return;
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
    if (mask == null) {
      canvas.drawImageRect(preview, _wholeImage(preview), output, paint);
      return;
    }
    canvas.saveLayer(output, Paint());
    canvas.drawImageRect(preview, _wholeImage(preview), output, paint);
    canvas.drawImageRect(
      mask,
      _wholeImage(mask),
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

  static Rect _wholeImage(ui.Image image) =>
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

  @override
  bool shouldRepaint(covariant ImageCardStreamPreviewPainter oldDelegate) =>
      oldDelegate.previewImage != previewImage ||
      oldDelegate.sourceImage != sourceImage ||
      oldDelegate.maskImage != maskImage ||
      oldDelegate.placement?.xPercent != placement?.xPercent ||
      oldDelegate.placement?.yPercent != placement?.yPercent ||
      oldDelegate.placement?.widthPercent != placement?.widthPercent ||
      oldDelegate.placement?.heightPercent != placement?.heightPercent;
}
