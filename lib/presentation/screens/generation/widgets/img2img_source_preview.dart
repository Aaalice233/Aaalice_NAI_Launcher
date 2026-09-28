import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/image_editor/painters/focused_overlay_painter.dart';
import 'img2img_preview_cache.dart';

class Img2ImgSourcePreview extends StatefulWidget {
  const Img2ImgSourcePreview({
    super.key,
    required this.sourceBytes,
    required this.imageWidth,
    required this.imageHeight,
    this.maskBytes,
    this.focusedInpaintEnabled = false,
    this.focusedSelectionRect,
    this.minimumContextMegaPixels = 88.0,
  });

  final Uint8List sourceBytes;
  final Uint8List? maskBytes;
  final bool focusedInpaintEnabled;
  final Rect? focusedSelectionRect;
  final double minimumContextMegaPixels;
  final int imageWidth;
  final int imageHeight;

  @override
  State<Img2ImgSourcePreview> createState() => _Img2ImgSourcePreviewState();
}

class _Img2ImgSourcePreviewState extends State<Img2ImgSourcePreview> {
  final Img2ImgPreviewCache _cache = Img2ImgPreviewCache();
  Img2ImgPreviewDerivedData _data = const Img2ImgPreviewDerivedData();

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant Img2ImgSourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolve();
  }

  void _resolve() {
    _data = _cache.resolve(
      sourceImage: widget.sourceBytes,
      maskImage: widget.maskBytes,
      focusedInpaintEnabled: widget.focusedInpaintEnabled,
      focusedSelectionRect: widget.focusedSelectionRect,
      minContextMegaPixels: widget.minimumContextMegaPixels,
      sourceWidth: widget.imageWidth,
      sourceHeight: widget.imageHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: ImageViewportSurface.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = _containedSize(constraints);
          return Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecodedMemoryImage(
                    bytes: widget.sourceBytes,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    maxLogicalWidth: size.width,
                    maxLogicalHeight: size.height,
                  ),
                  if (_data.maskOverlayBytes != null)
                    IgnorePointer(
                      child: DecodedMemoryImage(
                        bytes: _data.maskOverlayBytes!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        maxLogicalWidth: size.width,
                        maxLogicalHeight: size.height,
                      ),
                    ),
                  if (_data.focusedFrame?.contextCrop != null)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _FocusedCropPainter(
                          crop: _data.focusedFrame!.contextCrop,
                          focusBounds: _data.focusedFrame!.focusBounds,
                          imageWidth: widget.imageWidth,
                          imageHeight: widget.imageHeight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Size _containedSize(BoxConstraints constraints) {
    if (widget.imageWidth <= 0 || widget.imageHeight <= 0) {
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    final scale = math.min(
      constraints.maxWidth / widget.imageWidth,
      constraints.maxHeight / widget.imageHeight,
    );
    return Size(widget.imageWidth * scale, widget.imageHeight * scale);
  }
}

class _FocusedCropPainter extends CustomPainter {
  const _FocusedCropPainter({
    required this.crop,
    required this.focusBounds,
    required this.imageWidth,
    required this.imageHeight,
  });

  final FocusedInpaintCrop crop;
  final FocusedInpaintCrop? focusBounds;
  final int imageWidth;
  final int imageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    Path path(FocusedInpaintCrop value) => Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            value.x / imageWidth * size.width,
            value.y / imageHeight * size.height,
            value.width / imageWidth * size.width,
            value.height / imageHeight * size.height,
          ),
          const Radius.circular(2),
        ),
      );
    FocusedOverlayPainter(
      contextPath: path(crop),
      focusPath: focusBounds == null ? null : path(focusBounds!),
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _FocusedCropPainter oldDelegate) =>
      crop != oldDelegate.crop ||
      focusBounds != oldDelegate.focusBounds ||
      imageWidth != oldDelegate.imageWidth ||
      imageHeight != oldDelegate.imageHeight;
}
