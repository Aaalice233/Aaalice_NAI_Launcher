import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// How a decode box bounds the image before it is painted.
enum DecodeFit {
  /// The whole image stays inside the box.
  contain,

  /// The image fills the box and its overflowing axis is clipped.
  cover,
}

/// Image cache key of [BoxFitResizeImage].
@immutable
class BoxFitResizeImageKey {
  const BoxFitResizeImageKey._(
    this._providerCacheKey, {
    required this.width,
    required this.height,
    required this.fit,
  });

  final Object _providerCacheKey;
  final int? width;
  final int? height;
  final DecodeFit fit;

  @override
  bool operator ==(Object other) =>
      other is BoxFitResizeImageKey &&
      _providerCacheKey == other._providerCacheKey &&
      width == other.width &&
      height == other.height &&
      fit == other.fit;

  @override
  int get hashCode => Object.hash(_providerCacheKey, width, height, fit);

  @override
  String toString() =>
      'BoxFitResizeImageKey($_providerCacheKey, '
      '${width ?? '-'}×${height ?? '-'}, ${fit.name})';
}

/// Decodes [imageProvider] at least as large as a [BoxFit] paint samples it.
///
/// [ResizeImagePolicy.fit] only matches [BoxFit.contain]: under [BoxFit.cover]
/// it decodes the clipped axis below the box and the paint upscales it.
@immutable
class BoxFitResizeImage extends ImageProvider<BoxFitResizeImageKey> {
  const BoxFitResizeImage(
    this.imageProvider, {
    this.width,
    this.height,
    required this.fit,
  }) : assert(width != null || height != null);

  static const int maximumDecodedDimension = 4096;

  /// Wraps [provider] for painting with [fit] into a [width]×[height] physical
  /// box, or returns it unchanged when nothing bounds the decode.
  static ImageProvider<Object> resizeIfNeeded(
    ImageProvider<Object> provider, {
    required BoxFit fit,
    int? width,
    int? height,
  }) {
    final (boxWidth, boxHeight, decodeFit) = switch (fit) {
      BoxFit.contain || BoxFit.scaleDown => (width, height, DecodeFit.contain),
      // fill stretches each axis on its own; one uniform cover scale keeps
      // both axes at least box-sized.
      BoxFit.cover || BoxFit.fill => (width, height, DecodeFit.cover),
      BoxFit.fitWidth => (width, null, DecodeFit.contain),
      BoxFit.fitHeight => (null, height, DecodeFit.contain),
      // none paints at the decoded size, so any resize would shrink it.
      BoxFit.none => (null, null, DecodeFit.contain),
    };
    if (boxWidth == null && boxHeight == null) return provider;
    return BoxFitResizeImage(
      provider,
      width: boxWidth,
      height: boxHeight,
      fit: decodeFit,
    );
  }

  /// Smallest uniform decode that still covers what [fit] paints from the
  /// box. Never upscales; the longest edge is capped at [maximumDimension].
  static ui.TargetImageSize decodeTarget({
    required int intrinsicWidth,
    required int intrinsicHeight,
    required int? boxWidth,
    required int? boxHeight,
    required DecodeFit fit,
    int maximumDimension = maximumDecodedDimension,
  }) {
    if (intrinsicWidth <= 0 || intrinsicHeight <= 0) {
      return ui.TargetImageSize(width: boxWidth, height: boxHeight);
    }

    final widthScale = boxWidth == null ? null : boxWidth / intrinsicWidth;
    final heightScale = boxHeight == null ? null : boxHeight / intrinsicHeight;
    final requestedScale = switch ((widthScale, heightScale)) {
      (final width?, final height?) =>
        fit == DecodeFit.cover
            ? math.max(width, height)
            : math.min(width, height),
      (final width?, null) => width,
      (null, final height?) => height,
      (null, null) => 1.0,
    };
    var scale = math.min(1.0, requestedScale);
    final longestDecodedDimension = math.max(
      intrinsicWidth * scale,
      intrinsicHeight * scale,
    );
    if (longestDecodedDimension > maximumDimension) {
      scale *= maximumDimension / longestDecodedDimension;
    }
    return ui.TargetImageSize(
      width: math.max(1, (intrinsicWidth * scale).ceil()),
      height: math.max(1, (intrinsicHeight * scale).ceil()),
    );
  }

  final ImageProvider<Object> imageProvider;
  final int? width;
  final int? height;
  final DecodeFit fit;

  // SynchronousFuture.then stays synchronous, so a cache hit still paints in
  // the frame that resolves it.
  @override
  Future<BoxFitResizeImageKey> obtainKey(ImageConfiguration configuration) =>
      imageProvider
          .obtainKey(configuration)
          .then(
            (providerKey) => BoxFitResizeImageKey._(
              providerKey,
              width: width,
              height: height,
              fit: fit,
            ),
          );

  @override
  ImageStreamCompleter loadImage(
    BoxFitResizeImageKey key,
    ImageDecoderCallback decode,
  ) {
    Future<ui.Codec> decodeToBox(
      ui.ImmutableBuffer buffer, {
      ui.TargetImageSizeCallback? getTargetSize,
    }) {
      assert(
        getTargetSize == null,
        'BoxFitResizeImage cannot wrap a provider that applies getTargetSize.',
      );
      return decode(
        buffer,
        getTargetSize: (intrinsicWidth, intrinsicHeight) => decodeTarget(
          intrinsicWidth: intrinsicWidth,
          intrinsicHeight: intrinsicHeight,
          boxWidth: key.width,
          boxHeight: key.height,
          fit: key.fit,
        ),
      );
    }

    final completer = imageProvider.loadImage(
      key._providerCacheKey,
      decodeToBox,
    );
    if (!kReleaseMode) {
      completer.debugLabel =
          '${completer.debugLabel} - BoxFitResized('
          '${key.width ?? '-'}×${key.height ?? '-'}, ${key.fit.name})';
    }
    completer.addEphemeralErrorListener((_, _) {
      // The cache may not track the key yet when loading fails synchronously.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
    });
    return completer;
  }

  @override
  bool operator ==(Object other) =>
      other is BoxFitResizeImage &&
      imageProvider == other.imageProvider &&
      width == other.width &&
      height == other.height &&
      fit == other.fit;

  @override
  int get hashCode => Object.hash(imageProvider, width, height, fit);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'BoxFitResizeImage')}'
      '($imageProvider, ${width ?? '-'}×${height ?? '-'}, ${fit.name})';
}
