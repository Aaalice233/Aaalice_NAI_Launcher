import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/image_hover_preview.dart';
import '../../../widgets/common/library_card_badges.dart';

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

class _VibeHoverPreviewFrame extends StatefulWidget {
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
  State<_VibeHoverPreviewFrame> createState() => _VibeHoverPreviewFrameState();
}

class _VibeHoverPreviewFrameState extends State<_VibeHoverPreviewFrame> {
  late Future<double> _aspectRatioFuture;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _VibeHoverPreviewFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) _resolveAspectRatio();
  }

  void _resolveAspectRatio() {
    _aspectRatioFuture = decodeMemoryImageAspectRatio(widget.image);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectRatioFuture,
      initialData: 1,
      builder: (context, snapshot) {
        return ImageHoverPreviewSurface(
          key: const ValueKey('vibe-hover-preview'),
          sourceAspectRatio: snapshot.data ?? 1,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          mediaBuilder: _buildMedia,
          overlays: _buildOverlays(context),
          footer: _VibeHoverFooter(entry: widget.entry),
        );
      },
    );
  }

  Widget _buildMedia(
    BuildContext context,
    ImageHoverPreviewMediaLayout layout,
  ) {
    final image = widget.image;
    return SizedBox(
      key: const ValueKey('vibe-hover-media'),
      width: layout.size.width,
      height: layout.size.height,
      child: image == null
          ? _imageFallback(context)
          : DecodedMemoryImage(
              bytes: image,
              fit: layout.fit,
              alignment: layout.alignment,
              maxLogicalWidth: layout.size.width,
              maxLogicalHeight: layout.size.height,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => _imageFallback(context),
            ),
    );
  }

  List<Widget> _buildOverlays(BuildContext context) {
    final overlays = <Widget>[];
    if (widget.entry.isBundle) {
      overlays.add(
        Positioned(
          left: 10,
          top: 10,
          child: LibraryCardCategoryBadge(
            icon: Icons.layers_outlined,
            label: '${widget.entry.bundledVibeCount}',
          ),
        ),
      );
    }
    if (widget.entry.isFavorite) {
      overlays.add(
        Positioned(
          right: 10,
          top: 10,
          child: LibraryCardFavoriteBadge(
            semanticLabel: context.l10n.common_favorite,
          ),
        ),
      );
    }
    if (widget.isLoading) {
      overlays.add(
        Positioned(
          right: 10,
          bottom: 10,
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
                  value: MediaQuery.disableAnimationsOf(context) ? 0.5 : null,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return overlays;
  }

  Widget _imageFallback(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.loadFailed
                  ? Icons.broken_image_outlined
                  : widget.entry.isBundle
                  ? Icons.style
                  : Icons.auto_fix_high,
              size: 46,
              color: theme.colorScheme.outline,
            ),
            if (widget.loadFailed) ...[
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

class _VibeHoverFooter extends StatelessWidget {
  const _VibeHoverFooter({required this.entry});

  final VibeLibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                entry.isBundle ? Icons.layers_outlined : Icons.auto_fix_high,
                size: 17,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  entry.displayName,
                  key: const ValueKey('vibe-hover-title'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (entry.encodingModel case final model?) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(
                  Icons.memory_outlined,
                  size: 14,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    model,
                    key: const ValueKey('vibe-hover-model'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _VibeHoverStats(entry: entry),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            KeyedSubtree(
              key: const ValueKey('vibe-hover-tags'),
              child: ImageHoverPreviewTagRow(
                icon: Icons.tag,
                tags: entry.tags,
                tone: ImageHoverPreviewTone.tertiary,
              ),
            ),
          ],
        ],
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
        icon: Icons.tune,
        label: context.l10n.vibe_strength,
        value: '${(entry.strength * 100).round()}%',
        tone: ImageHoverPreviewTone.primary,
      ),
      (
        key: const ValueKey('vibe-hover-info-extracted'),
        icon: Icons.auto_awesome_outlined,
        label: context.l10n.vibe_infoExtracted,
        value: '${(entry.infoExtracted * 100).round()}%',
        tone: ImageHoverPreviewTone.secondary,
      ),
      (
        key: const ValueKey('vibe-hover-usage-count'),
        icon: Icons.history,
        label: context.l10n.vibeDetail_usageCount,
        value: '${entry.usedCount}',
        tone: ImageHoverPreviewTone.tertiary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 320 ? 1 : 3;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 8,
          children: [
            for (final stat in stats)
              SizedBox(
                key: stat.key,
                width: width,
                child: ImageHoverPreviewMetric(
                  icon: stat.icon,
                  label: stat.label,
                  value: stat.value,
                  tone: stat.tone,
                ),
              ),
          ],
        );
      },
    );
  }
}

Size computeVibeHoverPreviewBounds(Size viewport) {
  return Size(
    math.min(420.0, math.max(0.0, viewport.width - 20)),
    math.min(620.0, math.max(0.0, viewport.height - 20)),
  );
}
