import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';

typedef FocusedPreviewFrameResolver =
    FocusedInpaintFrame? Function({
      required Uint8List sourceImage,
      Uint8List? maskImage,
      Rect? focusedSelectionRect,
      required double minContextMegaPixels,
    });

typedef SelectionPreviewFrameResolver =
    FocusedInpaintFrame? Function({
      required int sourceWidth,
      required int sourceHeight,
      required Rect selectionRect,
      required double minContextMegaPixels,
    });

typedef MaskOverlayBuilder = Uint8List Function(Uint8List maskImage);

typedef SourcePreviewImageDecoder = img.Image? Function(Uint8List sourceImage);

(int, int) resolveSourcePreviewDimensions({
  required Uint8List sourceBytes,
  int? fallbackWidth,
  int? fallbackHeight,
  SourcePreviewImageDecoder? imageDecoder,
}) {
  img.Image? decoded;
  try {
    decoded = (imageDecoder ?? img.decodeImage)(sourceBytes);
  } catch (_) {
    decoded = null;
  }
  if (decoded != null) {
    return (decoded.width, decoded.height);
  }

  if (fallbackWidth != null &&
      fallbackHeight != null &&
      fallbackWidth > 0 &&
      fallbackHeight > 0) {
    return (fallbackWidth, fallbackHeight);
  }

  return (1, 1);
}

class Img2ImgPreviewDerivedData {
  const Img2ImgPreviewDerivedData({this.maskOverlayBytes, this.focusedFrame});

  final Uint8List? maskOverlayBytes;
  final FocusedInpaintFrame? focusedFrame;
}

/// 缓存图生图预览区的重型派生数据，避免无关重建时反复解码大图。
class Img2ImgPreviewCache {
  Img2ImgPreviewCache({
    FocusedPreviewFrameResolver? focusedFrameResolver,
    SelectionPreviewFrameResolver? selectionPreviewFrameResolver,
    MaskOverlayBuilder? maskOverlayBuilder,
  }) : _focusedFrameResolver =
           focusedFrameResolver ?? FocusedInpaintUtils.resolvePreviewFrame,
       _selectionPreviewFrameResolver =
           selectionPreviewFrameResolver ??
           FocusedInpaintUtils.resolvePreviewFrameForSelection,
       _maskOverlayBuilder =
           maskOverlayBuilder ?? InpaintMaskUtils.maskToEditorOverlay;

  final FocusedPreviewFrameResolver _focusedFrameResolver;
  final SelectionPreviewFrameResolver _selectionPreviewFrameResolver;
  final MaskOverlayBuilder _maskOverlayBuilder;

  Uint8List? _lastMaskImageForOverlay;
  Uint8List? _cachedMaskOverlayBytes;

  Uint8List? _lastSourceImageForFrame;
  Uint8List? _lastMaskImageForFrame;
  Rect? _lastFocusedSelectionRect;
  double? _lastMinimumContextMegaPixels;
  bool? _lastFocusedInpaintEnabled;
  int? _lastSourceWidth;
  int? _lastSourceHeight;
  FocusedInpaintFrame? _cachedFocusedFrame;

  Img2ImgPreviewDerivedData resolve({
    required Uint8List sourceImage,
    Uint8List? maskImage,
    required bool focusedInpaintEnabled,
    Rect? focusedSelectionRect,
    required double minContextMegaPixels,
    int? sourceWidth,
    int? sourceHeight,
  }) {
    if (!identical(maskImage, _lastMaskImageForOverlay)) {
      _lastMaskImageForOverlay = maskImage;
      _cachedMaskOverlayBytes = maskImage == null
          ? null
          : _maskOverlayBuilder(maskImage);
    }

    final shouldResolveFocusedFrame =
        focusedInpaintEnabled &&
        (maskImage != null || focusedSelectionRect != null);
    final frameInputsChanged =
        !identical(sourceImage, _lastSourceImageForFrame) ||
        !identical(maskImage, _lastMaskImageForFrame) ||
        _lastFocusedSelectionRect != focusedSelectionRect ||
        _lastMinimumContextMegaPixels != minContextMegaPixels ||
        _lastFocusedInpaintEnabled != focusedInpaintEnabled ||
        _lastSourceWidth != sourceWidth ||
        _lastSourceHeight != sourceHeight;

    if (!shouldResolveFocusedFrame) {
      _cachedFocusedFrame = null;
    } else if (frameInputsChanged) {
      if (focusedSelectionRect != null &&
          sourceWidth != null &&
          sourceHeight != null) {
        _cachedFocusedFrame = _selectionPreviewFrameResolver(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          selectionRect: focusedSelectionRect,
          minContextMegaPixels: minContextMegaPixels,
        );
      } else {
        _cachedFocusedFrame = _focusedFrameResolver(
          sourceImage: sourceImage,
          maskImage: maskImage,
          focusedSelectionRect: focusedSelectionRect,
          minContextMegaPixels: minContextMegaPixels,
        );
      }
    }

    _lastSourceImageForFrame = sourceImage;
    _lastMaskImageForFrame = maskImage;
    _lastFocusedSelectionRect = focusedSelectionRect;
    _lastMinimumContextMegaPixels = minContextMegaPixels;
    _lastFocusedInpaintEnabled = focusedInpaintEnabled;
    _lastSourceWidth = sourceWidth;
    _lastSourceHeight = sourceHeight;

    return Img2ImgPreviewDerivedData(
      maskOverlayBytes: _cachedMaskOverlayBytes,
      focusedFrame: _cachedFocusedFrame,
    );
  }
}
