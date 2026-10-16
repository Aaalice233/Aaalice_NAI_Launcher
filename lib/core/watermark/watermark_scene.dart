import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/models/watermark/watermark_settings.dart';
import 'watermark_auto_placement.dart';
import 'watermark_font_catalog.dart';
import 'watermark_source_analysis.dart';
import 'watermark_tone.dart';

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

/// 按原图内容得出的自动调整；与画布缩放无关，在原尺寸上判定后可用于任意尺寸的预览
class WatermarkAutoDecision {
  const WatermarkAutoDecision({
    this.mirror = WatermarkMirror.none,
    this.textTone,
    this.logoFilter,
  });

  static const none = WatermarkAutoDecision();

  final WatermarkMirror mirror;
  final WatermarkTextTone? textTone;
  final ColorFilter? logoFilter;

  @override
  bool operator ==(Object other) =>
      other is WatermarkAutoDecision &&
      other.mirror == mirror &&
      other.textTone == textTone &&
      other.logoFilter == logoFilter;

  @override
  int get hashCode => Object.hash(mirror, textTone, logoFilter);
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

  static WatermarkAutoDecision decide({
    required Size canvasSize,
    required WatermarkSettings settings,
    required WatermarkSourceAnalysis analysis,
    ui.Image? logo,
    WatermarkLogoLuminance? logoLuminance,
  }) {
    if (!settings.usesSourceAnalysis) return WatermarkAutoDecision.none;
    final layers = _measure(settings, canvasSize, logo);
    if (layers.isEmpty) return WatermarkAutoDecision.none;
    WatermarkRegionStats regionOf(Rect bounds) => analysis.regionStats(
      Rect.fromLTRB(
        bounds.left / canvasSize.width,
        bounds.top / canvasSize.height,
        bounds.right / canvasSize.width,
        bounds.bottom / canvasSize.height,
      ),
    );

    final mirror = settings.autoPlacement
        ? WatermarkAutoPlacement.choose({
            for (final candidate in WatermarkMirror.values)
              candidate: _resolveBounds(layers, settings, canvasSize, candidate)
                  .fold(
                    0.0,
                    (cost, bounds) =>
                        cost +
                        WatermarkAutoPlacement.placementCost(regionOf(bounds)),
                  ),
          })
        : WatermarkMirror.none;
    final bounds = _resolveBounds(layers, settings, canvasSize, mirror);
    WatermarkTextTone? textTone;
    ColorFilter? logoFilter;
    for (var index = 0; index < layers.length; index++) {
      // 背景完全透明时无从取亮度，保留用户设定的颜色
      final background = regionOf(bounds[index]).meanLightness;
      if (background == null) continue;
      switch (layers[index].kind) {
        case WatermarkLayerKind.text when settings.textStyle.autoTone:
          textTone = WatermarkTextTone.forBackground(
            background: background,
            contrast: settings.textStyle.toneContrast,
          );
        case WatermarkLayerKind.logo
            when settings.logoStyle.autoTone && logoLuminance != null:
          logoFilter = logoLuminance.filterFor(
            WatermarkTone.targets(
              background: background,
              contrast: settings.logoStyle.toneContrast,
            ).foreground,
          );
        case WatermarkLayerKind.text || WatermarkLayerKind.logo:
          break;
      }
    }
    return WatermarkAutoDecision(
      mirror: mirror,
      textTone: textTone,
      logoFilter: logoFilter,
    );
  }

  static WatermarkSceneResult paint({
    required Canvas canvas,
    required Size canvasSize,
    required WatermarkSettings settings,
    ui.Image? logo,
    WatermarkAutoDecision decision = WatermarkAutoDecision.none,
  }) {
    final layers = _measure(settings, canvasSize, logo);
    if (layers.isEmpty) return const WatermarkSceneResult([]);
    final bounds = _resolveBounds(
      layers,
      settings,
      canvasSize,
      decision.mirror,
    );
    final textStyle =
        decision.textTone?.applyTo(settings.textStyle) ?? settings.textStyle;
    final textAlignment = decision.mirror.alignment(textStyle.alignment);
    final shortEdge = math.min(canvasSize.width, canvasSize.height);

    final indexes = List<int>.generate(layers.length, (index) => index)
      ..sort((a, b) => layers[a].zIndex.compareTo(layers[b].zIndex));
    for (final index in indexes) {
      final layer = layers[index];
      switch (layer.kind) {
        case WatermarkLayerKind.text:
          _paintText(
            canvas,
            layer.textPainter!,
            bounds[index],
            textStyle,
            textAlignment,
            shortEdge,
          );
        case WatermarkLayerKind.logo:
          _paintLogo(
            canvas,
            logo!,
            bounds[index],
            settings.logoStyle.opacity,
            decision.logoFilter,
          );
      }
    }
    return WatermarkSceneResult([
      for (var index = 0; index < layers.length; index++)
        WatermarkResolvedLayer(kind: layers[index].kind, bounds: bounds[index]),
    ]);
  }

  static List<_MeasuredLayer> _measure(
    WatermarkSettings settings,
    Size canvasSize,
    ui.Image? logo,
  ) {
    final layout = layoutFor(settings, canvasSize);
    final textStyle = settings.textStyle;
    return [
      if (textStyle.enabled && textStyle.text.trim().isNotEmpty)
        _MeasuredLayer.text(
          _buildTextPainter(textStyle, layout.textPlacement, canvasSize),
          layout.textPlacement,
        ),
      if (settings.logoStyle.enabled && logo != null)
        _MeasuredLayer.logo(
          size: _logoSize(logo, layout.logoPlacement, canvasSize),
          placement: layout.logoPlacement,
        ),
    ];
  }

  static List<Rect> _resolveBounds(
    List<_MeasuredLayer> layers,
    WatermarkSettings settings,
    Size canvasSize,
    WatermarkMirror mirror,
  ) {
    final composition = settings.composition;
    return switch (composition.arrangement) {
      WatermarkLayerArrangement.independent => [
        for (final layer in layers)
          _anchoredRect(
            layer.size,
            mirror.placement(layer.placement),
            canvasSize,
          ),
      ],
      // 镜像后紧贴边缘的仍是原来那一层，所以沿排列方向翻转时顺序也反过来
      WatermarkLayerArrangement.horizontal => _resolveGroup(
        layers,
        canvasSize,
        composition,
        mirror.placement(layoutFor(settings, canvasSize).textPlacement),
        reversed: mirror.flipsX,
      ),
      WatermarkLayerArrangement.vertical => _resolveGroup(
        layers,
        canvasSize,
        composition,
        mirror.placement(layoutFor(settings, canvasSize).textPlacement),
        reversed: mirror.flipsY,
      ),
    };
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
    textAlign: _textAlign(style.alignment),
    textDirection: TextDirection.ltr,
    maxLines: 8,
    ellipsis: '…',
  );

  static TextAlign _textAlign(WatermarkTextAlignment alignment) =>
      switch (alignment) {
        WatermarkTextAlignment.left => TextAlign.left,
        WatermarkTextAlignment.center => TextAlign.center,
        WatermarkTextAlignment.right => TextAlign.right,
      };

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

  static List<Rect> _resolveGroup(
    List<_MeasuredLayer> layers,
    Size canvasSize,
    WatermarkComposition composition,
    WatermarkPlacement placement, {
    required bool reversed,
  }) {
    final shortEdge = math.min(canvasSize.width, canvasSize.height);
    final gap = composition.gapRatio * shortEdge;
    final horizontal =
        composition.arrangement == WatermarkLayerArrangement.horizontal;
    final rawSize = horizontal
        ? Size(
            layers.fold<double>(0, (value, layer) => value + layer.size.width) +
                gap * math.max(0, layers.length - 1),
            layers.fold<double>(
              0,
              (value, layer) => math.max(value, layer.size.height),
            ),
          )
        : Size(
            layers.fold<double>(
              0,
              (value, layer) => math.max(value, layer.size.width),
            ),
            layers.fold<double>(
                  0,
                  (value, layer) => value + layer.size.height,
                ) +
                gap * math.max(0, layers.length - 1),
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
    final order = List<int>.generate(layers.length, (index) => index);
    final result = List<Rect>.filled(layers.length, Rect.zero);
    var cursor = 0.0;
    for (final index in reversed ? order.reversed : order) {
      final size = layers[index].size * scale;
      final offset = horizontal
          ? Offset(
              groupRect.left + cursor,
              groupRect.center.dy - size.height / 2,
            )
          : Offset(
              groupRect.center.dx - size.width / 2,
              groupRect.top + cursor,
            );
      result[index] = offset & size;
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
    Rect bounds,
    WatermarkTextStyle style,
    WatermarkTextAlignment alignment,
    double shortEdge,
  ) {
    // 组合超出画布时整组缩小，描边与阴影随文字一起缩放
    canvas
      ..save()
      ..translate(bounds.left, bounds.top)
      ..scale(bounds.width / metrics.width);
    final baseText = metrics.text as TextSpan;
    final alpha = style.opacity.clamp(0.0, 1.0);
    final textAlign = _textAlign(alignment);
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
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
        maxLines: metrics.maxLines,
        ellipsis: metrics.ellipsis,
      )..layout(maxWidth: metrics.width);
      stroke.paint(canvas, Offset.zero);
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
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: metrics.maxLines,
      ellipsis: metrics.ellipsis,
    )..layout(maxWidth: metrics.width);
    fill.paint(canvas, Offset.zero);
    canvas.restore();
  }

  static void _paintLogo(
    Canvas canvas,
    ui.Image logo,
    Rect destination,
    double opacity,
    ColorFilter? colorFilter,
  ) {
    canvas.drawImageRect(
      logo,
      Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
      destination,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = colorFilter
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
  }
}

class _MeasuredLayer {
  _MeasuredLayer.text(TextPainter painter, this.placement)
    : kind = WatermarkLayerKind.text,
      size = painter.size,
      textPainter = painter;

  const _MeasuredLayer.logo({required this.size, required this.placement})
    : kind = WatermarkLayerKind.logo,
      textPainter = null;

  final WatermarkLayerKind kind;
  final Size size;

  /// 用户设定的位置，镜像在求边界时才施加
  final WatermarkPlacement placement;
  final TextPainter? textPainter;

  int get zIndex => placement.zIndex;
}
