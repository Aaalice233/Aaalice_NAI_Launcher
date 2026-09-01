import 'dart:ui' show Offset, Rect;

import '../../../core/services/anlas_calculator.dart';
import '../../../core/utils/focused_inpaint_utils.dart';
import '../../../core/utils/inpaint_mask/inpaint_mask_geometry.dart';

enum InpaintFocusPreference { auto, enabled, disabled }

class InpaintMaskAuthoringException implements Exception {
  const InpaintMaskAuthoringException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class InpaintMaskAuthoringRequest {
  const InpaintMaskAuthoringRequest({
    required this.regions,
    required this.expandRatio,
    required this.focus,
    this.contextPadding,
  });

  final List<InpaintMaskRegion> regions;
  final double expandRatio;
  final InpaintFocusPreference focus;
  final int? contextPadding;
}

/// Decodes the model-facing mask geometry arguments and decides whether the
/// resulting mask should use focused inpainting.
abstract final class InpaintMaskAuthoring {
  static const int minContextPadding = FocusedInpaintUtils.minContextPadding;
  static const int maxContextPadding = FocusedInpaintUtils.maxContextPadding;
  static const double maxExpandRatio = 0.25;

  static InpaintMaskAuthoringRequest parse(Map<String, dynamic> args) {
    final rawRegions = args['regions'];
    if (rawRegions is! List || rawRegions.isEmpty) {
      throw const InpaintMaskAuthoringException(
        'invalid_regions',
        'regions must be a non-empty array.',
      );
    }
    if (rawRegions.length > 16) {
      throw const InpaintMaskAuthoringException(
        'invalid_regions',
        'regions must contain at most 16 shapes.',
      );
    }

    final regions = <InpaintMaskRegion>[
      for (var index = 0; index < rawRegions.length; index++)
        _parseRegion(rawRegions[index], index),
    ];

    final expandRatio = _parseExpandRatio(args['expand_ratio']);
    final contextPadding = _parseContextPadding(args['context_padding']);
    return InpaintMaskAuthoringRequest(
      regions: regions,
      expandRatio: expandRatio,
      focus: _parseFocus(args['focused']),
      contextPadding: contextPadding,
    );
  }

  /// Resolves [InpaintFocusPreference.auto] from the source image size.
  ///
  /// 判据是 Opus 免费额度线：线下的图整张请求本来就免费且是原生分辨率，再裁剪
  /// 放大只是把低分辨率像素插值撑大；线上的图若不裁剪，要么越过免费线，要么被
  /// 整体缩小到蒙版区剩不下多少有效像素。
  static bool resolveFocusedEnabled({
    required InpaintFocusPreference preference,
    required int maskedPixels,
    required int imagePixels,
  }) {
    if (preference == InpaintFocusPreference.enabled) return true;
    if (preference == InpaintFocusPreference.disabled) return false;
    if (maskedPixels <= 0 || imagePixels <= 0) return false;
    return imagePixels > AnlasCalculator.opusFreeMaxPixels;
  }

  static InpaintMaskRegion _parseRegion(Object? value, int index) {
    if (value is! Map) {
      throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index] must be an object.',
      );
    }
    final region = Map<String, dynamic>.from(value);
    final mode = switch (region['mode']) {
      null || 'add' => InpaintMaskRegionMode.add,
      'subtract' => InpaintMaskRegionMode.subtract,
      _ => throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index].mode must be add or subtract.',
      ),
    };

    switch (region['shape']) {
      case 'rect':
        return InpaintMaskRegion.rect(_parseBounds(region, index), mode: mode);
      case 'ellipse':
        return InpaintMaskRegion.ellipse(
          _parseBounds(region, index),
          mode: mode,
        );
      case 'polygon':
        return InpaintMaskRegion.polygon(
          _parsePoints(region, index),
          mode: mode,
        );
      default:
        throw InpaintMaskAuthoringException(
          'invalid_region',
          'regions[$index].shape must be rect, ellipse, or polygon.',
        );
    }
  }

  // 只接受一种坐标表达：两种混用时无法判断谁是权威，与其猜不如直接报错。
  static Rect _parseBounds(Map<String, dynamic> region, int index) {
    final hasEdges =
        region.containsKey('right') || region.containsKey('bottom');
    final hasExtent =
        region.containsKey('width') || region.containsKey('height');
    if (hasEdges == hasExtent) {
      throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index] must use either left/top/right/bottom or '
            'x/y/width/height, not both.',
      );
    }

    if (hasEdges) {
      return Rect.fromLTRB(
        _parseUnit(region['left'], index, 'left'),
        _parseUnit(region['top'], index, 'top'),
        _parseUnit(region['right'], index, 'right'),
        _parseUnit(region['bottom'], index, 'bottom'),
      );
    }
    final x = _parseUnit(region['x'] ?? region['left'], index, 'x');
    final y = _parseUnit(region['y'] ?? region['top'], index, 'y');
    final width = _parseUnit(region['width'], index, 'width');
    final height = _parseUnit(region['height'], index, 'height');
    return Rect.fromLTWH(x, y, width, height);
  }

  static List<Offset> _parsePoints(Map<String, dynamic> region, int index) {
    final raw = region['points'];
    if (raw is! List || raw.length < 3) {
      throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index].points must contain at least three points.',
      );
    }
    if (raw.length > 64) {
      throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index].points must contain at most 64 points.',
      );
    }
    return [
      for (final point in raw)
        if (point is Map)
          Offset(
            _parseUnit(point['x'], index, 'points[].x'),
            _parseUnit(point['y'], index, 'points[].y'),
          )
        else
          throw InpaintMaskAuthoringException(
            'invalid_region',
            'regions[$index].points entries must be objects with x and y.',
          ),
    ];
  }

  static double _parseUnit(Object? value, int index, String field) {
    final number = value is num ? value.toDouble() : null;
    if (number == null || !number.isFinite) {
      throw InpaintMaskAuthoringException(
        'invalid_region',
        'regions[$index].$field must be a number in 0..1.',
      );
    }
    return number;
  }

  static double _parseExpandRatio(Object? value) {
    if (value == null) return 0;
    final ratio = value is num ? value.toDouble() : null;
    if (ratio == null || !ratio.isFinite || ratio < 0) {
      throw const InpaintMaskAuthoringException(
        'invalid_expand_ratio',
        'expand_ratio must be a number of at least 0.',
      );
    }
    if (ratio > maxExpandRatio) {
      throw const InpaintMaskAuthoringException(
        'invalid_expand_ratio',
        'expand_ratio must not exceed $maxExpandRatio.',
      );
    }
    return ratio;
  }

  static int? _parseContextPadding(Object? value) {
    if (value == null) return null;
    final padding = value is num ? value.toInt() : null;
    if (padding == null ||
        padding < minContextPadding ||
        padding > maxContextPadding) {
      throw const InpaintMaskAuthoringException(
        'invalid_context_padding',
        'context_padding must be an integer from '
            '$minContextPadding to $maxContextPadding pixels.',
      );
    }
    return padding;
  }

  static InpaintFocusPreference _parseFocus(Object? value) => switch (value) {
    null || 'auto' => InpaintFocusPreference.auto,
    true || 'true' => InpaintFocusPreference.enabled,
    false || 'false' => InpaintFocusPreference.disabled,
    _ => throw const InpaintMaskAuthoringException(
      'invalid_focused',
      'focused must be auto, true, or false.',
    ),
  };
}
