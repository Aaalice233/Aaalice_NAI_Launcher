import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../themes/core/layered_surface_style.dart';

/// Desktop quick-look for a Vibe library entry.
///
/// The frame deliberately keeps a stable width and height while the full image
/// loads. This prevents the overlay from jumping when the thumbnail and source
/// image have different encoded dimensions.
class VibeHoverPreview extends StatelessWidget {
  const VibeHoverPreview({
    super.key,
    required this.displayEntry,
    required this.detailFuture,
    required this.fallbackImage,
    required this.maxWidth,
    required this.maxHeight,
  });

  final VibeLibraryEntry displayEntry;
  final Future<VibeLibraryDetailData?> detailFuture;
  final Uint8List? fallbackImage;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VibeLibraryDetailData?>(
      future: detailFuture,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final entry = detail?.entry ?? displayEntry;
        return _VibeHoverPreviewFrame(
          entry: entry,
          image: _bestPreviewImage(detail, fallbackImage),
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          isLoading: snapshot.connectionState != ConnectionState.done,
          loadFailed: snapshot.hasError,
        );
      },
    );
  }

  Uint8List? _bestPreviewImage(
    VibeLibraryDetailData? detail,
    Uint8List? fallback,
  ) {
    final entry = detail?.entry;
    final candidates = <Uint8List?>[
      entry?.rawImageData,
      if (detail != null && detail.bundleVibes.isNotEmpty)
        detail.bundleVibes.first.rawImageData,
      entry?.thumbnail,
      entry?.vibeThumbnail,
      if (detail != null && detail.bundleVibes.isNotEmpty)
        detail.bundleVibes.first.thumbnail,
      fallback,
    ];
    for (final candidate in candidates) {
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }
}

class _VibeHoverPreviewFrame extends StatelessWidget {
  const _VibeHoverPreviewFrame({
    required this.entry,
    required this.image,
    required this.maxWidth,
    required this.maxHeight,
    required this.isLoading,
    required this.loadFailed,
  });

  final VibeLibraryEntry entry;
  final Uint8List? image;
  final double maxWidth;
  final double maxHeight;
  final bool isLoading;
  final bool loadFailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('vibe-hover-preview'),
        width: maxWidth,
        height: maxHeight,
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  key: const ValueKey('vibe-hover-media'),
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: overlaySurfaceColor(theme.colorScheme)),
                    if (image != null)
                      Image.memory(
                        image!,
                        fit: BoxFit.contain,
                        cacheWidth: (maxWidth * pixelRatio).round(),
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            _imageFallback(context, loadFailed: true),
                      )
                    else
                      _imageFallback(context, loadFailed: loadFailed),
                    if (isLoading)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withValues(alpha: 0.9),
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.5
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (entry.isBundle)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: _BundleCountBadge(count: entry.bundledVibeCount),
                      ),
                  ],
                ),
              ),
              _VibeHoverMetadata(entry: entry),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(BuildContext context, {required bool loadFailed}) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              loadFailed
                  ? Icons.broken_image_outlined
                  : entry.isBundle
                  ? Icons.style
                  : Icons.auto_fix_high,
              size: 46,
              color: theme.colorScheme.outline,
            ),
            if (loadFailed) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.common_previewLoadFailed,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VibeHoverMetadata extends StatelessWidget {
  const _VibeHoverMetadata({required this.entry});

  final VibeLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final usesLargeText = textScaler.scale(12) / 12 > 1.45;
    final visibleTags = entry.tags.take(4).toList(growable: false);
    final remainingTags = entry.tags.length - visibleTags.length;
    final tagText = [
      ...visibleTags.map((tag) => '#$tag'),
      if (remainingTags > 0) '+$remainingTags',
    ].join('  ');

    return ColoredBox(
      color: overlaySurfaceColor(colorScheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.displayName,
              key: const ValueKey('vibe-hover-title'),
              maxLines: usesLargeText ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (entry.encodingModel case final model?) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.memory_outlined,
                      size: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      model,
                      key: const ValueKey('vibe-hover-model'),
                      maxLines: usesLargeText ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _VibeHoverStats(entry: entry),
            if (tagText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tagText,
                key: const ValueKey('vibe-hover-tags'),
                maxLines: usesLargeText ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VibeHoverStats extends StatelessWidget {
  const _VibeHoverStats({required this.entry});

  final VibeLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        key: const ValueKey('vibe-hover-strength'),
        label: context.l10n.vibe_strength,
        value: '${(entry.strength * 100).round()}%',
      ),
      (
        key: const ValueKey('vibe-hover-info-extracted'),
        label: context.l10n.vibe_infoExtracted,
        value: '${(entry.infoExtracted * 100).round()}%',
      ),
      (
        key: const ValueKey('vibe-hover-usage-count'),
        label: context.l10n.vibeDetail_usageCount,
        value: '${entry.usedCount}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 ? 1 : 3;
        const spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 6,
          children: [
            for (final stat in stats)
              SizedBox(
                key: stat.key,
                width: itemWidth,
                child: _VibeHoverStat(label: stat.label, value: stat.value),
              ),
          ],
        );
      },
    );
  }
}

class _VibeHoverStat extends StatelessWidget {
  const _VibeHoverStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final usesLargeText = textScaler.scale(12) / 12 > 1.45;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    if (usesLargeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
          Text(
            value,
            maxLines: 1,
            style: style?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      );
    }
    return Text.rich(
      TextSpan(
        text: '$label ',
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _BundleCountBadge extends StatelessWidget {
  const _BundleCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Size computeVibeHoverPreviewBounds(Size viewport) {
  return Size(
    math.min(420.0, math.max(0.0, viewport.width - 20)),
    math.min(620.0, math.max(0.0, viewport.height - 20)),
  );
}
