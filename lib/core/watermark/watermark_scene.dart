import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/watermark/watermark_settings.dart';
import 'watermark_font_catalog.dart';

enum WatermarkLayoutKind { universal, portrait, square, landscape }

enum WatermarkLayerKind { text, logo }

class WatermarkResolvedLayer {
  const WatermarkResolvedLayer({required this.kind, required this.bounds});

  final WatermarkLayerKind kind;
  final Rect bounds;
}

class WatermarkSceneResult {
  const WatermarkSceneResult(this.layers);

  final List<WatermarkResolvedLayer> layers;

  Rect? boundsFor(WatermarkLayerKind kind) {
    for (final layer in layers) {
      if (layer.kind == kind) return layer.bounds;
    }
    return null;
  }
}

class WatermarkScene {
  const WatermarkScene._();

  static WatermarkLayoutKind classify(Size size) {
    final ratio = size.width / size.height;
    if (ratio > 1.12) return WatermarkLayoutKind.landscape;
    if (ratio < 0.89) return WatermarkLayoutKind.portrait;
    return WatermarkLayoutKind.square;
  }

  static WatermarkLayout layoutFor(WatermarkSettings settings, Size size) {
    if (!settings.rememberLayoutsByOrientation) {
      return settings.universalLayout;
    }
    return switch (classify(size)) {
      WatermarkLayoutKind.portrait => settings.portraitLayout,
      WatermarkLayoutKind.square => settings.squareLayout,
      WatermarkLayoutKind.landscape => settings.landscapeLayout,
      WatermarkLayoutKind.universal => settings.universalLayout,
    };
  }

  static WatermarkSettings updateLayout(
    WatermarkSettings settings,
    WatermarkLayoutKind kind,
    WatermarkLayout layout,
  ) {
    if (!settings.rememberLayoutsByOrientation ||
        kind == WatermarkLayoutKind.universal) {
      return settings.copyWith(universalLayout: layout);
    }
    return switch (kind) {
      WatermarkLayoutKind.portrait => settings.copyWith(portraitLayout: layout),
      WatermarkLayoutKind.square => settings.copyWith(squareLayout: layout),
      WatermarkLayoutKind.landscape => settings.copyWith(
        landscapeLayout: layout,
      ),
      WatermarkLayoutKind.universal => settings.copyWith(
        universalLayout: layout,
      ),
    };
  }

  static WatermarkSceneResult paint({
    required Canvas canvas,
    required Size canvasSize,
    required WatermarkSettings settings,
    ui.Image? logo,
  }) {
    final layout = layoutFor(settings, canvasSize);
    final textPainter =
        settings.textStyle.enabled && settings.textStyle.text.trim().isNotEmpty
        ? _buildTextPainter(
            settings.textStyle,
            layout.textPlacement,
            canvasSize,
          )
        : null;
    final logoSize = settings.logoStyle.enabled && logo != null
        ? _logoSize(logo, layout.logoPlacement, canvasSize)
        : null;

    final specs = <_LayerSpec>[];
    if (textPainter != null) {
      specs.add(
        _LayerSpec(
          kind: WatermarkLayerKind.text,
          size: textPainter.size,
          placement: layout.textPlacement,
          zIndex: layout.textPlacement.zIndex,
          draw: (offset) => _paintText(
            canvas,
            textPainter,
            offset,
            settings.textStyle,
            math.min(canvasSize.width, canvasSize.height),
          ),
        ),
      );
    }
    if (logoSize != null && logo != null) {
      specs.add(
        _LayerSpec(
          kind: WatermarkLayerKind.logo,
          size: logoSize,
          placement: layout.logoPlacement,
          zIndex: layout.logoPlacement.zIndex,
          draw: (offset) => _paintLogo(
            canvas,
            logo,
            offset & logoSize,
            settings.logoStyle.opacity,
          ),
        ),
      );
    }
    if (specs.isEmpty) return const WatermarkSceneResult([]);

    final bounds =
        settings.composition.arrangement ==
            WatermarkLayerArrangement.independent
        ? _resolveIndependent(specs, canvasSize)
        : _resolveGroup(
            specs,
            canvasSize,
            settings.composition,
            layout.textPlacement,
          );

    final indexes = List<int>.generate(specs.length, (index) => index)
      ..sort((a, b) => specs[a].zIndex.compareTo(specs[b].zIndex));
    for (final index in indexes) {
      specs[index].draw(bounds[index].topLeft);
    }
    return WatermarkSceneResult([
      for (var index = 0; index < specs.length; index++)
        WatermarkResolvedLayer(kind: specs[index].kind, bounds: bounds[index]),
    ]);
  }

  static TextPainter _buildTextPainter(
    WatermarkTextStyle style,
    WatermarkPlacement placement,
    Size canvasSize,
  ) {
    final shortEdge = math.min(canvasSize.width, canvasSize.height);
    final margin = placement.marginRatio * shortEdge;
    final maxWidth = math.max(1.0, canvasSize.width - margin * 2);
    final maxHeight = math.max(1.0, canvasSize.height - margin * 2);
    var fontSize = math.max(1.0, placement.sizeRatio * shortEdge);
    var painter = _createTextPainter(style, fontSize)
      ..layout(maxWidth: maxWidth);
    final scale = math.min(
      1.0,
      math.min(maxWidth / painter.width, maxHeight / painter.height),
    );
    if (scale < 1) {
      fontSize *= scale;
      painter = _createTextPainter(style, fontSize)..layout(maxWidth: maxWidth);
    }
    return painter;
  }

  static TextPainter _createTextPainter(
    WatermarkTextStyle style,
    double fontSize,
  ) => TextPainter(
    text: TextSpan(
      text: style.text,
      style: TextStyle(
        fontFamily: WatermarkFontCatalog.contains(style.fontFamily)
            ? style.fontFamily
            : WatermarkFontCatalog.options.first.family,
        fontFamilyFallback: WatermarkFontCatalog.fallbackFamilies,
        fontSize: fontSize,
        height: 1.05,
        letterSpacing: style.letterSpacingRatio * fontSize,
      ),
    ),
    textAlign: switch (style.alignment) {
      WatermarkTextAlignment.left => TextAlign.left,
      WatermarkTextAlignment.center => TextAlign.center,
      WatermarkTextAlignment.right => TextAlign.right,
    },
    textDirection: TextDirection.ltr,
    maxLines: 8,
    ellipsis: '…',
  );

  static Size _logoSize(
    ui.Image logo,
    WatermarkPlacement placement,
    Size canvasSize,
  ) {
    final shortEdge = math.min(canvasSize.width, canvasSize.height);
    final longest = math.max(1, math.max(logo.width, logo.height));
    final scale = placement.sizeRatio * shortEdge / longest;
    return Size(logo.width * scale, logo.height * scale);
  }

  static List<Rect> _resolveIndependent(
    List<_LayerSpec> specs,
    Size canvasSize,
  ) => [
    for (final spec in specs)
      _anchoredRect(spec.size, spec.placement, canvasSize),
  ];

  static List<Rect> _resolveGroup(
    List<_LayerSpec> specs,
    Size canvasSize,
    WatermarkComposition composition,
    WatermarkPlacement placement,
  ) {
    final shortEdge = math.min(canvasSize.width, canvasSize.height);
    final gap = composition.gapRatio * shortEdge;
    final horizontal =
        composition.arrangement == WatermarkLayerArrangement.horizontal;
    final rawSize = horizontal
        ? Size(
            specs.fold<double>(0, (value, spec) => value + spec.size.width) +
                gap * math.max(0, specs.length - 1),
            specs.fold<double>(
              0,
              (value, spec) => math.max(value, spec.size.height),
            ),
          )
        : Size(
            specs.fold<double>(
              0,
              (value, spec) => math.max(value, spec.size.width),
            ),
            specs.fold<double>(0, (value, spec) => value + spec.size.height) +
                gap * math.max(0, specs.length - 1),
          );
    final margin = placement.marginRatio * shortEdge;
    final scale = math.min(
      1.0,
      math.min(
        (canvasSize.width - margin * 2) / rawSize.width,
        (canvasSize.height - margin * 2) / rawSize.height,
      ),
    );
    final groupSize = rawSize * scale;
    final groupRect = _anchoredRect(
      groupSize,
      placement.copyWith(sizeRatio: 1),
      canvasSize,
    );
    final result = <Rect>[];
    var cursor = 0.0;
    for (final spec in specs) {
      final size = spec.size * scale;
      final offset = horizontal
          ? Offset(
              groupRect.left + cursor,
              groupRect.center.dy - size.height / 2,
            )
          : Offset(
              groupRect.center.dx - size.width / 2,
              groupRect.top + cursor,
            );
      result.add(offset & size);
      cursor += (horizontal ? size.width : size.height) + gap * scale;
    }
    return result;
  }

  static Rect _anchoredRect(
    Size size,
    WatermarkPlacement placement,
    Size canvasSize,
  ) {
    final shortEdge = math.min(canvasSize.width, canvasSize.height);
    final margin = placement.marginRatio * shortEdge;
    final available = Rect.fromLTWH(
      margin,
      margin,
      math.max(0, canvasSize.width - margin * 2),
      math.max(0, canvasSize.height - margin * 2),
    );
    final anchor = _anchorPoint(placement.anchor, available);
    final pivot = _anchorPivot(placement.anchor, size);
    final raw =
        anchor -
        pivot +
        Offset(
          placement.offsetXRatio * shortEdge,
          placement.offsetYRatio * shortEdge,
        );
    final left = raw.dx.clamp(
      0.0,
      math.max(0.0, canvasSize.width - size.width),
    );
    final top = raw.dy.clamp(
      0.0,
      math.max(0.0, canvasSize.height - size.height),
    );
    return Offset(left.toDouble(), top.toDouble()) & size;
  }

  static Offset _anchorPoint(WatermarkAnchor anchor, Rect rect) =>
      switch (anchor) {
        WatermarkAnchor.topLeft => rect.topLeft,
        WatermarkAnchor.topCenter => rect.topCenter,
        WatermarkAnchor.topRight => rect.topRight,
        WatermarkAnchor.centerLeft => rect.centerLeft,
        WatermarkAnchor.center => rect.center,
        WatermarkAnchor.centerRight => rect.centerRight,
        WatermarkAnchor.bottomLeft => rect.bottomLeft,
        WatermarkAnchor.bottomCenter => rect.bottomCenter,
        WatermarkAnchor.bottomRight => rect.bottomRight,
      };

  static Offset _anchorPivot(WatermarkAnchor anchor, Size size) =>
      switch (anchor) {
        WatermarkAnchor.topLeft => Offset.zero,
        WatermarkAnchor.topCenter => Offset(size.width / 2, 0),
        WatermarkAnchor.topRight => Offset(size.width, 0),
        WatermarkAnchor.centerLeft => Offset(0, size.height / 2),
        WatermarkAnchor.center => Offset(size.width / 2, size.height / 2),
        WatermarkAnchor.centerRight => Offset(size.width, size.height / 2),
        WatermarkAnchor.bottomLeft => Offset(0, size.height),
        WatermarkAnchor.bottomCenter => Offset(size.width / 2, size.height),
        WatermarkAnchor.bottomRight => Offset(size.width, size.height),
      };

  static void _paintText(
    Canvas canvas,
    TextPainter metrics,
    Offset offset,
    WatermarkTextStyle style,
    double shortEdge,
  ) {
    final baseText = metrics.text as TextSpan;
    final alpha = style.opacity.clamp(0.0, 1.0);
    if (style.strokeWidthRatio > 0) {
      final stroke = TextPainter(
        text: TextSpan(
          text: style.text,
          style: baseText.style?.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = style.strokeWidthRatio * shortEdge
              ..strokeJoin = StrokeJoin.round
              ..color = Color(style.strokeColorArgb).withValues(alpha: alpha),
          ),
        ),
        textAlign: metrics.textAlign,
        textDirection: TextDirection.ltr,
        maxLines: metrics.maxLines,
        ellipsis: metrics.ellipsis,
      )..layout(maxWidth: metrics.width);
      stroke.paint(canvas, offset);
    }
    final fill = TextPainter(
      text: TextSpan(
        text: style.text,
        style: baseText.style?.copyWith(
          color: Color(style.colorArgb).withValues(alpha: alpha),
          shadows: [
            Shadow(
              color: Color(style.shadowColorArgb).withValues(alpha: alpha),
              blurRadius: style.shadowBlurRatio * shortEdge,
              offset: Offset(
                style.shadowOffsetXRatio * shortEdge,
                style.shadowOffsetYRatio * shortEdge,
              ),
            ),
          ],
        ),
      ),
      textAlign: metrics.textAlign,
      textDirection: TextDirection.ltr,
      maxLines: metrics.maxLines,
      ellipsis: metrics.ellipsis,
    )..layout(maxWidth: metrics.width);
    fill.paint(canvas, offset);
  }

  static void _paintLogo(
    Canvas canvas,
    ui.Image logo,
    Rect destination,
    double opacity,
  ) {
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      destination,
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
  }
}

class _LayerSpec {
  const _LayerSpec({
    required this.kind,
    required this.size,
    required this.placement,
    required this.zIndex,
    required this.draw,
  });

  final WatermarkLayerKind kind;
  final Size size;
  final WatermarkPlacement placement;
  final int zIndex;
  final void Function(Offset offset) draw;
}
