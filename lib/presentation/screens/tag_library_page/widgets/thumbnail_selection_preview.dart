import 'dart:io';

import 'package:flutter/material.dart';

const double tagLibraryCardAspectRatio = 2.5;

Size displayedThumbnailImageSize(Size imageSize, Size displaySize) {
  final imageAspectRatio = imageSize.width / imageSize.height;
  final displayAspectRatio = displaySize.width / displaySize.height;

  if (imageAspectRatio > displayAspectRatio) {
    final width = displaySize.width;
    return Size(width, width / imageAspectRatio);
  }

  final height = displaySize.height;
  return Size(height * imageAspectRatio, height);
}

Size thumbnailCropBoxSize(Size displayedSize, double scale) {
  final double baseWidth;
  final double baseHeight;
  if (displayedSize.width / displayedSize.height > tagLibraryCardAspectRatio) {
    baseHeight = displayedSize.height;
    baseWidth = baseHeight * tagLibraryCardAspectRatio;
  } else {
    baseWidth = displayedSize.width;
    baseHeight = baseWidth / tagLibraryCardAspectRatio;
  }

  final scaleFactor = 1 / scale.clamp(1.0, 3.0);
  return Size(baseWidth * scaleFactor, baseHeight * scaleFactor);
}

Rect thumbnailCropRect({
  required Size displayedSize,
  required Size cropBoxSize,
  required double offsetX,
  required double offsetY,
}) {
  final maxOffsetX = (displayedSize.width - cropBoxSize.width) / 2;
  final maxOffsetY = (displayedSize.height - cropBoxSize.height) / 2;
  final center = Offset(
    displayedSize.width / 2 + offsetX.clamp(-1.0, 1.0) * maxOffsetX,
    displayedSize.height / 2 + offsetY.clamp(-1.0, 1.0) * maxOffsetY,
  );
  return Rect.fromCenter(
    center: center,
    width: cropBoxSize.width,
    height: cropBoxSize.height,
  );
}

/// 在完整图像上标出词库卡片实际使用的长方形范围。
class ThumbnailSelectionPreview extends StatefulWidget {
  const ThumbnailSelectionPreview({
    super.key,
    required this.imagePath,
    required this.offsetX,
    required this.offsetY,
    required this.scale,
  });

  final String imagePath;
  final double offsetX;
  final double offsetY;
  final double scale;

  @override
  State<ThumbnailSelectionPreview> createState() =>
      _ThumbnailSelectionPreviewState();
}

class _ThumbnailSelectionPreviewState extends State<ThumbnailSelectionPreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  Size? _imageSize;
  bool _imageLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(ThumbnailSelectionPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _loadImageSize();
    }
  }

  void _loadImageSize() {
    _removeImageListener();
    _imageSize = null;
    _imageLoadFailed = false;
    final stream = FileImage(
      File(widget.imagePath),
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!mounted || stream != _imageStream) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
        stream.removeListener(listener);
        _imageStream = null;
        _imageStreamListener = null;
      },
      onError: (_, __) {
        if (stream != _imageStream) return;
        stream.removeListener(listener);
        _imageStream = null;
        _imageStreamListener = null;
        if (mounted) setState(() => _imageLoadFailed = true);
      },
    );
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySize = constraints.biggest;
        final imageSize = _imageSize;
        if (imageSize == null) {
          if (_imageLoadFailed) {
            return Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            );
          }
          return Center(
            child: CircularProgressIndicator(
              value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
            ),
          );
        }

        final displayedSize = displayedThumbnailImageSize(
          imageSize,
          displaySize,
        );
        final imageOffset = Offset(
          (displaySize.width - displayedSize.width) / 2,
          (displaySize.height - displayedSize.height) / 2,
        );
        final cropSize = thumbnailCropBoxSize(displayedSize, widget.scale);
        final cropRect = thumbnailCropRect(
          displayedSize: displayedSize,
          cropBoxSize: cropSize,
          offsetX: widget.offsetX,
          offsetY: widget.offsetY,
        ).shift(imageOffset);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: imageOffset.dx,
              top: imageOffset.dy,
              width: displayedSize.width,
              height: displayedSize.height,
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            CustomPaint(
              painter: _ThumbnailSelectionPainter(
                imageRect: imageOffset & displayedSize,
                cropRect: cropRect,
                scrimColor: theme.colorScheme.scrim.withValues(alpha: 0.48),
                borderColor: theme.colorScheme.onSurface,
              ),
            ),
            Positioned.fromRect(
              rect: cropRect,
              child: const IgnorePointer(
                child: SizedBox(key: ValueKey('entry-thumbnail-card-frame')),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThumbnailSelectionPainter extends CustomPainter {
  const _ThumbnailSelectionPainter({
    required this.imageRect,
    required this.cropRect,
    required this.scrimColor,
    required this.borderColor,
  });

  final Rect imageRect;
  final Rect cropRect;
  final Color scrimColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final outsideCrop = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(imageRect)
      ..addRect(cropRect);
    canvas.drawPath(outsideCrop, Paint()..color = scrimColor);
    canvas.drawRect(
      cropRect.deflate(1),
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ThumbnailSelectionPainter oldDelegate) {
    return oldDelegate.imageRect != imageRect ||
        oldDelegate.cropRect != cropRect ||
        oldDelegate.scrimColor != scrimColor ||
        oldDelegate.borderColor != borderColor;
  }
}
