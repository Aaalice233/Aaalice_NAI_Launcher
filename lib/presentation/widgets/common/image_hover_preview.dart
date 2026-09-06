import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'image_viewport_surface.dart';
import '../../themes/core/layered_surface_style.dart';

enum ImageHoverPreviewTone { primary, secondary, tertiary, neutral }

@immutable
class ImageHoverPreviewMediaLayout {
  const ImageHoverPreviewMediaLayout({
    required this.size,
    required this.fit,
    required this.alignment,
    required this.isCropped,
  });

  final Size size;
  final BoxFit fit;
  final Alignment alignment;
  final bool isCropped;
}

typedef ImageHoverPreviewMediaBuilder =
    Widget Function(BuildContext context, ImageHoverPreviewMediaLayout layout);

/// Shared overlay surface for image-led hover previews.
///
/// The footer keeps its natural height. The media takes the remaining space,
/// preserves the source ratio while it fits, then crops instead of introducing
/// letterboxing once either height bound is reached.
class ImageHoverPreviewSurface extends StatelessWidget {
  const ImageHoverPreviewSurface({
    super.key,
    required this.sourceAspectRatio,
    required this.maxWidth,
    required this.maxHeight,
    required this.mediaBuilder,
    required this.footer,
    this.overlays = const [],
    this.minMediaHeight = 150,
  });

  final double sourceAspectRatio;
  final double maxWidth;
  final double maxHeight;
  final double minMediaHeight;
  final ImageHoverPreviewMediaBuilder mediaBuilder;
  final List<Widget> overlays;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.hasBoundedWidth
              ? math.min(maxWidth, constraints.maxWidth)
              : maxWidth;
          final cardMaxHeight = constraints.hasBoundedHeight
              ? math.min(maxHeight, constraints.maxHeight)
              : maxHeight;
          return Container(
            width: cardWidth,
            constraints: BoxConstraints(maxHeight: cardMaxHeight),
            decoration: BoxDecoration(
              color: overlaySurfaceColor(theme.colorScheme),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: LayoutBuilder(
                    builder: (context, mediaConstraints) {
                      final layout = resolveImageHoverPreviewMediaLayout(
                        sourceAspectRatio: sourceAspectRatio,
                        width: cardWidth,
                        maxHeight: mediaConstraints.maxHeight,
                        minHeight: minMediaHeight,
                      );
                      return SizedBox(
                        width: layout.size.width,
                        height: layout.size.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(
                              color: ImageViewportSurface.background,
                            ),
                            mediaBuilder(context, layout),
                            ...overlays,
                          ],
                        ),
                      );
                    },
                  ),
                ),
                footer,
              ],
            ),
          );
        },
      ),
    );
  }
}

class ImageHoverPreviewMetric extends StatelessWidget {
  const ImageHoverPreviewMetric({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.tone = ImageHoverPreviewTone.neutral,
  });

  final IconData icon;
  final String? label;
  final String value;
  final ImageHoverPreviewTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(theme.colorScheme, tone);
    final text = label == null || label!.isEmpty ? value : '$label $value';
    return Semantics(
      label: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageHoverPreviewTagRow extends StatelessWidget {
  const ImageHoverPreviewTagRow({
    super.key,
    required this.icon,
    required this.tags,
    this.tone = ImageHoverPreviewTone.neutral,
    this.maxVisibleTags = 4,
    this.totalCount,
    this.prefix = '#',
  });

  final IconData icon;
  final List<String> tags;
  final ImageHoverPreviewTone tone;
  final int maxVisibleTags;
  final int? totalCount;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _toneColor(theme.colorScheme, tone);
    final visible = tags.take(maxVisibleTags).toList(growable: false);
    final remaining = math.max(0, (totalCount ?? tags.length) - visible.length);
    final text = [
      ...visible.map((tag) => '$prefix$tag'),
      if (remaining > 0) '+$remaining',
    ].join('  ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

Color _toneColor(ColorScheme colors, ImageHoverPreviewTone tone) =>
    switch (tone) {
      ImageHoverPreviewTone.primary => colors.primary,
      ImageHoverPreviewTone.secondary => colors.secondary,
      ImageHoverPreviewTone.tertiary => colors.tertiary,
      ImageHoverPreviewTone.neutral => colors.onSurfaceVariant,
    };

@visibleForTesting
ImageHoverPreviewMediaLayout resolveImageHoverPreviewMediaLayout({
  required double sourceAspectRatio,
  required double width,
  required double maxHeight,
  double minHeight = 150,
}) {
  final safeWidth = math.max(1.0, width);
  final safeMaxHeight = math.max(1.0, maxHeight);
  final safeRatio = sourceAspectRatio.isFinite && sourceAspectRatio > 0
      ? sourceAspectRatio.clamp(0.05, 20.0).toDouble()
      : 1.0;
  final idealHeight = safeWidth / safeRatio;
  final effectiveMinHeight = math.min(math.max(1.0, minHeight), safeMaxHeight);
  final height = idealHeight
      .clamp(effectiveMinHeight, safeMaxHeight)
      .toDouble();
  final cropsTallImage = idealHeight > safeMaxHeight;
  final isCropped = (height - idealHeight).abs() > 0.01;
  return ImageHoverPreviewMediaLayout(
    size: Size(safeWidth, height),
    fit: BoxFit.cover,
    alignment: cropsTallImage ? Alignment.topCenter : Alignment.center,
    isCropped: isCropped,
  );
}

Future<double> decodeMemoryImageAspectRatio(
  Uint8List? bytes, {
  double fallback = 1,
}) async {
  if (bytes == null || bytes.isEmpty) return fallback;
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 || descriptor.height <= 0) return fallback;
    return descriptor.width / descriptor.height;
  } catch (_) {
    return fallback;
  } finally {
    descriptor?.dispose();
    buffer?.dispose();
  }
}
