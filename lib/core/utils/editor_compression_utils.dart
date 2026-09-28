import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import 'focused_inpaint_utils.dart';
import 'isolate_pool.dart';
import 'pica_lanczos_resizer.dart';

class EditorCompressionTarget {
  const EditorCompressionTarget({
    required this.width,
    required this.height,
    this.isOriginal = false,
  });

  final int width;
  final int height;
  final bool isOriginal;

  int get area => width * height;

  double linearScaleFor(int workWidth, int workHeight) {
    final workLongSide = math.max(workWidth, workHeight);
    if (workLongSide <= 0) return 1;
    return math.max(width, height) / workLongSide;
  }

  bool matches(int otherWidth, int otherHeight) {
    return width == otherWidth && height == otherHeight;
  }
}

class EditorCompressionPlan {
  const EditorCompressionPlan({
    required this.workWidth,
    required this.workHeight,
    required this.targets,
    required this.normalTarget,
    required this.minimumTarget,
  });

  static const int dimensionStep = FocusedInpaintUtils.dimensionStep;
  static const int normalAreaPixels =
      FocusedInpaintUtils.focusedTargetAreaPixels;
  static const int maxRequestAreaPixels =
      FocusedInpaintUtils.maxRequestAreaPixels;

  final int workWidth;
  final int workHeight;

  /// Targets are ordered from the smallest resolution to the largest.
  final List<EditorCompressionTarget> targets;
  final EditorCompressionTarget normalTarget;
  final EditorCompressionTarget minimumTarget;

  bool get canCompress => targets.any((target) => !target.isOriginal);

  EditorCompressionTarget get highestTarget => targets.last;

  int indexOf(EditorCompressionTarget? target) {
    if (target == null) return targets.length - 1;
    return targets.indexWhere(
      (candidate) => candidate.matches(target.width, target.height),
    );
  }

  EditorCompressionTarget targetAtOrBelowScale(double desiredScale) {
    EditorCompressionTarget? best;
    for (final target in targets) {
      final scale = target.linearScaleFor(workWidth, workHeight);
      if (scale <= desiredScale + 1e-9) {
        best = target;
      }
    }
    return best ?? targets.first;
  }

  static EditorCompressionPlan resolve({
    required int workWidth,
    required int workHeight,
    required bool focusedInpaintEnabled,
    Rect? focusedSelectionRect,
    double minimumContextPixels = 88,
  }) {
    if (workWidth <= 0 || workHeight <= 0) {
      throw ArgumentError('Editor work dimensions must be positive.');
    }

    final isLandscape = workWidth >= workHeight;
    final workLongSide = math.max(workWidth, workHeight);
    final workShortSide = math.min(workWidth, workHeight);
    final aspect = workShortSide / workLongSide;
    final normalOriented = _resolveNormalOriented(aspect);
    final minimumOriented = _resolveMinimumOriented(aspect, normalOriented);
    final normalTarget = _fromOriented(
      normalOriented,
      isLandscape: isLandscape,
    );
    final minimumTarget = _fromOriented(
      minimumOriented,
      isLandscape: isLandscape,
    );
    final original = EditorCompressionTarget(
      width: workWidth,
      height: workHeight,
      isOriginal: true,
    );

    if (workWidth < minimumTarget.width || workHeight < minimumTarget.height) {
      return EditorCompressionPlan(
        workWidth: workWidth,
        workHeight: workHeight,
        targets: [original],
        normalTarget: normalTarget,
        minimumTarget: minimumTarget,
      );
    }

    final candidates = <EditorCompressionTarget>[];
    final maximumGridLong = _floorToGrid(workLongSide);
    for (
      var longSide = minimumOriented.longSide;
      longSide <= maximumGridLong;
      longSide += dimensionStep
    ) {
      final shortSide = _resolveShortSide(
        longSide: longSide,
        aspect: aspect,
        maxShortSide: workShortSide,
        maxAreaInclusive: focusedInpaintEnabled ? null : maxRequestAreaPixels,
      );
      if (shortSide == null) continue;
      final target = _fromOriented((
        longSide: longSide,
        shortSide: shortSide,
      ), isLandscape: isLandscape);
      if (target.width > workWidth || target.height > workHeight) continue;
      if (!focusedInpaintEnabled && target.area > maxRequestAreaPixels) {
        continue;
      }
      if (!_isFocusedTargetLegal(
        target,
        workWidth: workWidth,
        workHeight: workHeight,
        focusedInpaintEnabled: focusedInpaintEnabled,
        focusedSelectionRect: focusedSelectionRect,
        minimumContextPixels: minimumContextPixels,
      )) {
        continue;
      }
      candidates.add(target);
    }

    if (_isFocusedTargetLegal(
      original,
      workWidth: workWidth,
      workHeight: workHeight,
      focusedInpaintEnabled: focusedInpaintEnabled,
      focusedSelectionRect: focusedSelectionRect,
      minimumContextPixels: minimumContextPixels,
    )) {
      candidates.add(original);
    }

    final unique = <String, EditorCompressionTarget>{};
    for (final candidate in candidates) {
      final key = '${candidate.width}x${candidate.height}';
      final previous = unique[key];
      if (previous == null || candidate.isOriginal) {
        unique[key] = candidate;
      }
    }
    final targets = unique.values.toList()
      ..sort((a, b) {
        final scaleComparison = a
            .linearScaleFor(workWidth, workHeight)
            .compareTo(b.linearScaleFor(workWidth, workHeight));
        if (scaleComparison != 0) return scaleComparison;
        return a.area.compareTo(b.area);
      });

    if (targets.isEmpty) {
      // The minimum target is always small enough for Focused Inpaint, but
      // retain a deterministic fallback for malformed extreme dimensions.
      targets.add(original);
    }

    return EditorCompressionPlan(
      workWidth: workWidth,
      workHeight: workHeight,
      targets: List.unmodifiable(targets),
      normalTarget: normalTarget,
      minimumTarget: minimumTarget,
    );
  }

  static bool _isFocusedTargetLegal(
    EditorCompressionTarget target, {
    required int workWidth,
    required int workHeight,
    required bool focusedInpaintEnabled,
    required Rect? focusedSelectionRect,
    required double minimumContextPixels,
  }) {
    if (!focusedInpaintEnabled || focusedSelectionRect == null) {
      return true;
    }
    final projected = EditorCompressionGeometry.projectRect(
      focusedSelectionRect,
      sourceWidth: workWidth,
      sourceHeight: workHeight,
      targetWidth: target.width,
      targetHeight: target.height,
    );
    final geometry = FocusedInpaintUtils.resolveGeometryForSelection(
      sourceWidth: target.width,
      sourceHeight: target.height,
      selectionRect: projected,
      minContextMegaPixels: minimumContextPixels,
    );
    return geometry != null && !geometry.wasDynamicallyConstrained;
  }

  static ({int longSide, int shortSide}) _resolveNormalOriented(double aspect) {
    final idealLongSide = math.sqrt(normalAreaPixels / aspect);
    final idealShortSide = idealLongSide * aspect;
    final longCandidates = _adjacentGridValues(idealLongSide);
    final shortCandidates = _adjacentGridValues(idealShortSide);
    final candidates = <({int longSide, int shortSide})>[];
    for (final longSide in longCandidates) {
      for (final shortSide in shortCandidates) {
        if (longSide * shortSide <= normalAreaPixels) {
          candidates.add((longSide: longSide, shortSide: shortSide));
        }
      }
    }
    if (candidates.isEmpty) {
      return (
        longSide: _floorToGrid(normalAreaPixels ~/ dimensionStep),
        shortSide: dimensionStep,
      );
    }
    candidates.sort((a, b) {
      final aspectComparison = _aspectError(
        a.longSide,
        a.shortSide,
        aspect,
      ).compareTo(_aspectError(b.longSide, b.shortSide, aspect));
      if (aspectComparison != 0) return aspectComparison;
      final areaComparison = (b.longSide * b.shortSide).compareTo(
        a.longSide * a.shortSide,
      );
      if (areaComparison != 0) return areaComparison;
      return a.shortSide.compareTo(b.shortSide);
    });
    return candidates.first;
  }

  static ({int longSide, int shortSide}) _resolveMinimumOriented(
    double aspect,
    ({int longSide, int shortSide}) normal,
  ) {
    final longSide = math.max(dimensionStep, normal.longSide - dimensionStep);
    final shortSide = _resolveShortSide(
      longSide: longSide,
      aspect: aspect,
      maxAreaExclusive: normal.longSide * normal.shortSide,
    );
    return (
      longSide: longSide,
      shortSide: shortSide ?? math.max(dimensionStep, normal.shortSide),
    );
  }

  static int? _resolveShortSide({
    required int longSide,
    required double aspect,
    int? maxShortSide,
    int? maxAreaExclusive,
    int? maxAreaInclusive,
  }) {
    final candidates = _adjacentGridValues(longSide * aspect)
        .where((shortSide) => maxShortSide == null || shortSide <= maxShortSide)
        .where(
          (shortSide) =>
              maxAreaExclusive == null ||
              longSide * shortSide < maxAreaExclusive,
        )
        .where(
          (shortSide) =>
              maxAreaInclusive == null ||
              longSide * shortSide <= maxAreaInclusive,
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final aspectComparison = _aspectError(
        longSide,
        a,
        aspect,
      ).compareTo(_aspectError(longSide, b, aspect));
      if (aspectComparison != 0) return aspectComparison;
      return a.compareTo(b);
    });
    return candidates.first;
  }

  static List<int> _adjacentGridValues(double value) {
    final floor = math.max(dimensionStep, _floorToGrid(value.floor()));
    final ceil = math.max(dimensionStep, _ceilToGrid(value.ceil()));
    return floor == ceil ? [floor] : [floor, ceil];
  }

  static double _aspectError(int longSide, int shortSide, double aspect) {
    return ((shortSide / longSide) - aspect).abs() / aspect;
  }

  static EditorCompressionTarget _fromOriented(
    ({int longSide, int shortSide}) oriented, {
    required bool isLandscape,
  }) {
    return EditorCompressionTarget(
      width: isLandscape ? oriented.longSide : oriented.shortSide,
      height: isLandscape ? oriented.shortSide : oriented.longSide,
    );
  }

  static int _floorToGrid(int value) {
    return math.max(dimensionStep, (value ~/ dimensionStep) * dimensionStep);
  }

  static int _ceilToGrid(int value) {
    return math.max(
      dimensionStep,
      ((value + dimensionStep - 1) ~/ dimensionStep) * dimensionStep,
    );
  }
}

class EditorCompressionGeometry {
  const EditorCompressionGeometry._();

  static Rect projectRect(
    Rect rect, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    final scaleX = targetWidth / sourceWidth;
    final scaleY = targetHeight / sourceHeight;
    return Rect.fromLTRB(
      rect.left * scaleX,
      rect.top * scaleY,
      rect.right * scaleX,
      rect.bottom * scaleY,
    );
  }

  static Offset projectOffset(
    Offset offset, {
    required int sourceWidth,
    required int sourceHeight,
    required int targetWidth,
    required int targetHeight,
  }) {
    return Offset(
      offset.dx * targetWidth / sourceWidth,
      offset.dy * targetHeight / sourceHeight,
    );
  }

  static FocusedInpaintGeometry? resolveFocusedGeometry({
    required int workWidth,
    required int workHeight,
    required EditorCompressionTarget target,
    required Rect workSelectionRect,
    required double minimumContextPixels,
  }) {
    final targetSelection = projectRect(
      workSelectionRect,
      sourceWidth: workWidth,
      sourceHeight: workHeight,
      targetWidth: target.width,
      targetHeight: target.height,
    );
    return FocusedInpaintUtils.resolveGeometryForSelection(
      sourceWidth: target.width,
      sourceHeight: target.height,
      selectionRect: targetSelection,
      minContextMegaPixels: minimumContextPixels,
    );
  }

  static Rect? constrainWorkSelection({
    required int workWidth,
    required int workHeight,
    required EditorCompressionTarget target,
    required Rect workSelectionRect,
    required double minimumContextPixels,
    Offset? fixedWorkAnchor,
  }) {
    final targetSelection = projectRect(
      workSelectionRect,
      sourceWidth: workWidth,
      sourceHeight: workHeight,
      targetWidth: target.width,
      targetHeight: target.height,
    );
    final targetAnchor = fixedWorkAnchor == null
        ? null
        : projectOffset(
            fixedWorkAnchor,
            sourceWidth: workWidth,
            sourceHeight: workHeight,
            targetWidth: target.width,
            targetHeight: target.height,
          );
    final constrained = FocusedInpaintUtils.constrainSelectionRect(
      sourceWidth: target.width,
      sourceHeight: target.height,
      selectionRect: targetSelection,
      minContextMegaPixels: minimumContextPixels,
      fixedAnchor: targetAnchor,
    );
    if (constrained == null) return null;
    return projectRect(
      constrained,
      sourceWidth: target.width,
      sourceHeight: target.height,
      targetWidth: workWidth,
      targetHeight: workHeight,
    );
  }

  static Rect projectTargetCropToWorkCanvas({
    required FocusedInpaintCrop targetCrop,
    required int workWidth,
    required int workHeight,
    required EditorCompressionTarget target,
  }) {
    return projectRect(
      targetCrop.rect,
      sourceWidth: target.width,
      sourceHeight: target.height,
      targetWidth: workWidth,
      targetHeight: workHeight,
    );
  }
}

class EditorRawRgbaImage {
  const EditorRawRgbaImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

class EditorCompressionEncoder {
  const EditorCompressionEncoder._();

  static Future<Uint8List> encodeRgbaPngAsync(
    EditorRawRgbaImage source, {
    required int targetWidth,
    required int targetHeight,
  }) {
    return ComputeGate().runIsolate(() {
      final rgba = source.width == targetWidth && source.height == targetHeight
          ? source.bytes
          : PicaLanczosResizer.resizeRgba(
              source.bytes,
              sourceWidth: source.width,
              sourceHeight: source.height,
              targetWidth: targetWidth,
              targetHeight: targetHeight,
            );
      final image = img.Image.fromBytes(
        width: targetWidth,
        height: targetHeight,
        bytes: rgba.buffer,
        bytesOffset: rgba.offsetInBytes,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return Uint8List.fromList(img.encodePng(image, level: 1));
    });
  }
}
