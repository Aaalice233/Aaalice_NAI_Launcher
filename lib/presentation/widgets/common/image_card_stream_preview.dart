import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/models/image/image_stream_chunk.dart';

/// 流式预览的持帧渲染层：新帧解码完成前继续画上一帧。
class ImageCardStreamPreview extends StatefulWidget {
  const ImageCardStreamPreview({
    super.key,
    required this.previewBytes,
    this.placement,
  });

  final Uint8List previewBytes;
  final FocusedStreamPreviewPlacement? placement;

  @override
  State<ImageCardStreamPreview> createState() => _ImageCardStreamPreviewState();
}

class _ImageCardStreamPreviewState extends State<ImageCardStreamPreview> {
  final _preview = _HeldImage();
  final _source = _HeldImage();
  final _mask = _HeldImage();
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _resolveImages();
  }

  @override
  void didUpdateWidget(covariant ImageCardStreamPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveImages();
  }

  @override
  void dispose() {
    _preview.dispose();
    _source.dispose();
    _mask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ImageCardStreamPreviewPainter(
        previewImage: _preview.image,
        sourceImage: _source.image,
        maskImage: _mask.image,
        placement: widget.placement,
      ),
    );
  }

  void _resolveImages() {
    final placement = widget.placement;
    final composited = placement != null && placement.isValid;
    // 缓存命中时监听器同步回调，此时正处于 initState/didUpdateWidget，不能 setState。
    _resolving = true;
    _preview.resolve(widget.previewBytes, _onImageChanged);
    _source.resolve(composited ? placement.sourceImage : null, _onImageChanged);
    _mask.resolve(composited ? placement.maskImage : null, _onImageChanged);
    _resolving = false;
  }

  void _onImageChanged() {
    if (_resolving || !mounted) return;
    setState(() {});
  }
}

/// 一张经 ImageCache 解码并持有的图；换源时旧帧保留到新帧到达。
class _HeldImage {
  Uint8List? _bytes;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _info;

  ui.Image? get image => _info?.image;

  void resolve(Uint8List? bytes, VoidCallback onChanged) {
    if (identical(_bytes, bytes)) return;
    _bytes = bytes;
    _stopListening();
    if (bytes == null || bytes.isEmpty) {
      _replaceInfo(null);
      onChanged();
      return;
    }
    final stream = MemoryImage(bytes).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        _replaceInfo(info);
        onChanged();
      },
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  void dispose() {
    _stopListening();
    _replaceInfo(null);
  }

  void _stopListening() {
    final stream = _stream;
    final listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _replaceInfo(ImageInfo? info) {
    if (identical(_info, info)) return;
    _info?.dispose();
    _info = info;
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
