import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/focused_inpaint_utils.dart';
import '../../../../core/utils/inpaint_mask_utils.dart';
import '../../../../core/utils/last_result_memo.dart';
import '../../../../core/utils/nai_resolution_adapter.dart';

typedef MaskOverlayBuilder = Future<Uint8List> Function(Uint8List maskImage);

typedef SourcePreviewSizeReader = (int, int)? Function(Uint8List sourceImage);

(int, int) resolveSourcePreviewDimensions({
  required Uint8List sourceBytes,
  int? sourceWidth,
  int? sourceHeight,
  int? fallbackWidth,
  int? fallbackHeight,
  SourcePreviewSizeReader? imageSizeReader,
}) {
  if (sourceWidth != null &&
      sourceHeight != null &&
      sourceWidth > 0 &&
      sourceHeight > 0) {
    return (sourceWidth, sourceHeight);
  }

  final encodedSize = (imageSizeReader ?? NaiResolutionAdapter.readImageSize)(
    sourceBytes,
  );
  if (encodedSize != null && encodedSize.$1 > 0 && encodedSize.$2 > 0) {
    return encodedSize;
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
///
/// 蒙版叠加图在后台计算，完成后经 onUpdated 通知；蒙版外接矩形取自与费用预估共用的
/// provider。同一张源图上重算期间沿用上一次的结果，换了源图或清除过蒙版则先不显示。
class Img2ImgPreviewCache {
  Img2ImgPreviewCache({
    required VoidCallback onUpdated,
    MaskOverlayBuilder? maskOverlayBuilder,
  }) : _maskOverlay = _MaskOverlayDerivation(
         maskOverlayBuilder ?? InpaintMaskUtils.maskToEditorOverlayAsync,
         onUpdated,
       );

  final _MaskOverlayDerivation _maskOverlay;
  final _frames = LastResultMemo<Object, FocusedInpaintFrame?>();

  Uint8List? _lastSourceImage;
  FocusedInpaintFrame? _lastFrame;

  /// [maskExtent] 是 [maskImage] 的外接矩形，只在聚焦框取自蒙版时用到。
  Img2ImgPreviewDerivedData resolve({
    required Uint8List sourceImage,
    Uint8List? maskImage,
    AsyncValue<FocusedInpaintMaskExtent?> maskExtent = const AsyncData(null),
    required bool focusedInpaintEnabled,
    Rect? focusedSelectionRect,
    Rect? focusedContextCrop,
    required double minContextMegaPixels,
    required int sourceWidth,
    required int sourceHeight,
  }) {
    final keepStale = identical(sourceImage, _lastSourceImage);
    _lastSourceImage = sourceImage;

    final Uint8List? maskOverlayBytes;
    if (maskImage == null) {
      _maskOverlay.clear();
      maskOverlayBytes = null;
    } else {
      maskOverlayBytes = _maskOverlay.resolve(maskImage, keepStale: keepStale);
    }

    final FocusedInpaintFrame? focusedFrame;
    if (!focusedInpaintEnabled) {
      focusedFrame = null;
    } else if (focusedContextCrop != null) {
      focusedFrame = _frames.resolve(
        (focusedContextCrop, sourceWidth, sourceHeight),
        (_) => FocusedInpaintUtils.resolveGeometryForCrop(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          crop: focusedContextCrop,
        ),
      );
    } else if (focusedSelectionRect != null) {
      focusedFrame = _frames.resolve(
        (focusedSelectionRect, minContextMegaPixels, sourceWidth, sourceHeight),
        (_) => FocusedInpaintUtils.resolveGeometryForSelection(
          sourceWidth: sourceWidth,
          sourceHeight: sourceHeight,
          selectionRect: focusedSelectionRect,
          minContextMegaPixels: minContextMegaPixels,
        ),
      );
    } else if (maskImage == null || maskExtent.hasError) {
      focusedFrame = null;
    } else if (maskExtent.isLoading) {
      // provider 重算期间的旧值可能来自换图前，只沿用这张源图上显示过的框
      focusedFrame = keepStale ? _lastFrame : null;
    } else {
      final extent = maskExtent.valueOrNull;
      // 蒙版与源图同尺寸，几何与费用预估、请求裁剪取自同一外接矩形
      focusedFrame = extent == null
          ? null
          : _frames.resolve(
              (extent, minContextMegaPixels),
              (_) => FocusedInpaintUtils.resolveGeometryForMaskExtent(
                extent,
                minContextMegaPixels: minContextMegaPixels,
              ),
            );
    }
    _lastFrame = focusedFrame;

    return Img2ImgPreviewDerivedData(
      maskOverlayBytes: maskOverlayBytes,
      focusedFrame: focusedFrame,
    );
  }

  /// 丢弃尚未完成的后台结果，之后不再通知。
  void dispose() => _maskOverlay.dispose();
}

/// 以蒙版字节的引用为键记住一次后台计算；蒙版换了才重算，过期请求的结果丢弃。
class _MaskOverlayDerivation {
  _MaskOverlayDerivation(this._compute, this._onUpdated);

  final MaskOverlayBuilder _compute;
  final VoidCallback _onUpdated;

  Uint8List? _input;
  int _generation = 0;
  bool _ready = false;
  bool _disposed = false;
  Uint8List? _value;

  /// 返回 [input] 的结果；仍在计算时按 [keepStale] 给出上一次的结果或 null。
  Uint8List? resolve(Uint8List input, {required bool keepStale}) {
    if (!identical(input, _input)) {
      _start(input);
    }
    if (!_ready && !keepStale) {
      _value = null;
    }
    return _value;
  }

  /// 输入已不存在：丢弃结果与未完成的计算，之后的输入不再沿用它。
  void clear() {
    _input = null;
    _value = null;
    _ready = false;
    _generation++;
  }

  void dispose() {
    _disposed = true;
    _generation++;
  }

  void _start(Uint8List input) {
    _input = input;
    _ready = false;
    final generation = ++_generation;
    _compute(input).then(
      (value) => _complete(generation, value),
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e(
          'Img2Img mask overlay failed',
          error,
          stackTrace,
          'Img2ImgPreview',
        );
        _complete(generation, null);
      },
    );
  }

  void _complete(int generation, Uint8List? value) {
    if (_disposed || generation != _generation) {
      return;
    }
    _value = value;
    _ready = true;
    _onUpdated();
  }
}
