import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../../widgets/common/image_hover_preview.dart';
import '../../../widgets/common/library_card_badges.dart';

class PreciseRefHoverPreview extends StatefulWidget {
  const PreciseRefHoverPreview({
    super.key,
    required this.entry,
    required this.imageFuture,
    required this.fallbackImage,
    required this.maxWidth,
    required this.maxHeight,
  });

  final PreciseRefLibraryEntry entry;
  final Future<Uint8List?> imageFuture;
  final Uint8List? fallbackImage;
  final double maxWidth;
  final double maxHeight;

  @override
  State<PreciseRefHoverPreview> createState() => _PreciseRefHoverPreviewState();
}

class _PreciseRefHoverPreviewState extends State<PreciseRefHoverPreview> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: widget.imageFuture,
      builder: (context, snapshot) {
        return _PreciseRefHoverPreviewContent(
          entry: widget.entry,
          image: snapshot.data ?? widget.fallbackImage,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          isLoading: snapshot.connectionState != ConnectionState.done,
        );
      },
    );
  }
}

class _PreciseRefHoverPreviewContent extends StatefulWidget {
  const _PreciseRefHoverPreviewContent({
    required this.entry,
    required this.image,
    required this.maxWidth,
    required this.maxHeight,
    required this.isLoading,
  });

  final PreciseRefLibraryEntry entry;
  final Uint8List? image;
  final double maxWidth;
  final double maxHeight;
  final bool isLoading;

  @override
  State<_PreciseRefHoverPreviewContent> createState() =>
      _PreciseRefHoverPreviewContentState();
}

class _PreciseRefHoverPreviewContentState
    extends State<_PreciseRefHoverPreviewContent> {
  late Future<double> _aspectRatioFuture;

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _PreciseRefHoverPreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.image, widget.image)) _resolveAspectRatio();
  }

  void _resolveAspectRatio() {
    _aspectRatioFuture = decodeMemoryImageAspectRatio(widget.image);
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.entry.type.getDisplayName(
      character: context.l10n.preciseRef_typeCharacter,
      style: context.l10n.preciseRef_typeStyle,
      characterAndStyle: context.l10n.preciseRef_typeCharacterAndStyle,
    );
    return FutureBuilder<double>(
      future: _aspectRatioFuture,
      initialData: 1,
      builder: (context, snapshot) {
        return ImageHoverPreviewSurface(
          key: const ValueKey('precise-ref-hover-preview'),
          sourceAspectRatio: snapshot.data ?? 1,
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
          mediaBuilder: _buildMedia,
          overlays: [
            Positioned(
              left: 10,
              top: 10,
              child: LibraryCardCategoryBadge(
                icon: widget.entry.type.icon,
                label: typeLabel,
              ),
            ),
            if (widget.entry.isFavorite)
              Positioned(
                right: 10,
                top: 10,
                child: LibraryCardFavoriteBadge(
                  semanticLabel: context.l10n.common_favorite,
                ),
              ),
            if (widget.isLoading)
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
                        value: MediaQuery.disableAnimationsOf(context)
                            ? 0.5
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
          ],
          footer: _PreciseRefHoverFooter(entry: widget.entry),
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
      key: const ValueKey('precise-ref-hover-media'),
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

  Widget _imageFallback(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 46,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

class _PreciseRefHoverFooter extends StatelessWidget {
  const _PreciseRefHoverFooter({required this.entry});

  final PreciseRefLibraryEntry entry;

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
              Icon(entry.type.icon, size: 17, color: theme.colorScheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ImageHoverPreviewMetric(
                  icon: Icons.tune,
                  label: context.l10n.preciseRef_strength,
                  value: _formatParam(entry.strength),
                  tone: ImageHoverPreviewTone.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ImageHoverPreviewMetric(
                  icon: Icons.center_focus_strong_outlined,
                  label: context.l10n.preciseRef_fidelity,
                  value: _formatParam(entry.fidelity),
                  tone: ImageHoverPreviewTone.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ImageHoverPreviewMetric(
                  icon: Icons.history,
                  label: context.l10n.vibeDetail_usageCount,
                  value: '${entry.usedCount}',
                  tone: ImageHoverPreviewTone.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatParam(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('0') ? value.toStringAsFixed(1) : text;
  }
}

Size computePreciseRefHoverPreviewBounds(Size viewport) {
  return Size(
    math.min(380.0, math.max(0.0, viewport.width - 20)),
    math.min(680.0, math.max(0.0, viewport.height - 20)),
  );
}
