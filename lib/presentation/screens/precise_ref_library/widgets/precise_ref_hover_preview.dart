import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../widgets/common/library_card_badges.dart';

/// 精准参考卡片的桌面悬浮预览。
///
/// 原图异步读取期间先展示已有缩略图，避免把磁盘 IO 阻塞在 hover 事件中。
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
        final image = snapshot.data ?? widget.fallbackImage;
        return _PreciseRefHoverPreviewContent(
          entry: widget.entry,
          image: image,
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
  Future<double>? _aspectRatioFuture;

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
    final image = widget.image;
    _aspectRatioFuture = image == null ? Future.value(1) : _decodeRatio(image);
  }

  Future<double> _decodeRatio(Uint8List bytes) async {
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      codec = await ui.instantiateImageCodec(bytes);
      frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      return width > 0 && height > 0 ? width / height : 1;
    } catch (_) {
      return 1;
    } finally {
      frame?.image.dispose();
      codec?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _aspectRatioFuture,
      initialData: 1,
      builder: (context, snapshot) =>
          _buildCard((snapshot.data ?? 1).clamp(0.1, 10).toDouble()),
    );
  }

  Widget _buildCard(double aspectRatio) {
    final theme = Theme.of(context);
    const metadataHeight = 118.0;
    final imageSize = computePreciseRefHoverImageSize(
      aspectRatio: aspectRatio,
      maxWidth: widget.maxWidth,
      maxHeight: math.max(80, widget.maxHeight - metadataHeight),
    );
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final typeLabel = widget.entry.type.getDisplayName(
      character: context.l10n.preciseRef_typeCharacter,
      style: context.l10n.preciseRef_typeStyle,
      characterAndStyle: context.l10n.preciseRef_typeCharacterAndStyle,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('precise-ref-hover-preview'),
        width: imageSize.width,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: overlaySurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                key: const ValueKey('precise-ref-hover-media'),
                width: imageSize.width,
                height: imageSize.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(color: overlaySurfaceColor(theme.colorScheme)),
                    if (widget.image != null)
                      Image.memory(
                        widget.image!,
                        fit: BoxFit.contain,
                        cacheWidth: (imageSize.width * pixelRatio).round(),
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => _imageFallback(theme),
                      )
                    else
                      _imageFallback(theme),
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
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _PreviewStat(
                            label: context.l10n.preciseRef_strength,
                            value: _formatParam(widget.entry.strength),
                          ),
                        ),
                        Expanded(
                          child: _PreviewStat(
                            label: context.l10n.preciseRef_fidelity,
                            value: _formatParam(widget.entry.fidelity),
                          ),
                        ),
                        Expanded(
                          child: _PreviewStat(
                            label: context.l10n.vibeDetail_usageCount,
                            value: '${widget.entry.usedCount}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(ThemeData theme) {
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

  static String _formatParam(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('0') ? value.toStringAsFixed(1) : text;
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$label $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      ),
    );
  }
}

Size computePreciseRefHoverPreviewBounds(Size viewport) {
  return Size(
    math.min(380.0, math.max(0.0, viewport.width - 20)),
    math.min(680.0, math.max(0.0, viewport.height - 20)),
  );
}

@visibleForTesting
Size computePreciseRefHoverImageSize({
  required double aspectRatio,
  required double maxWidth,
  required double maxHeight,
}) {
  final safeRatio = aspectRatio > 0 ? aspectRatio : 1.0;
  final width = safeRatio >= 1
      ? maxWidth
      : math.min(maxWidth, math.max(240.0, maxHeight * safeRatio));
  final naturalHeight = width / safeRatio;
  final height = math.min(maxHeight, math.max(120.0, naturalHeight));
  return Size(width, height);
}
