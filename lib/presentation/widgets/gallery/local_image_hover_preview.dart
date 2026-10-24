import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../common/model_family_icon.dart';

import '../../../core/cache/local_gallery_thumbnail_provider.dart';
import '../../../core/utils/byte_format.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../utils/local_gallery_metadata_resolver.dart';
import '../common/image_hover_preview.dart';
import '../common/image_hover_preview_controller.dart';

/// Adds a delayed, full-file hover preview to a local gallery card.
class LocalImageHoverPreview extends StatefulWidget {
  const LocalImageHoverPreview({
    super.key,
    required this.record,
    required this.child,
    this.hoverDelay = const Duration(milliseconds: 280),
    this.enabled = true,
  });

  final LocalImageRecord record;
  final Widget child;
  final Duration hoverDelay;
  final bool enabled;

  @override
  State<LocalImageHoverPreview> createState() => _LocalImageHoverPreviewState();
}

class _LocalImageHoverPreviewState extends State<LocalImageHoverPreview> {
  final _layerLink = LayerLink();
  late final ImageHoverPreviewController _hoverController;
  NaiImageMetadata? _resolvedMetadata;
  String? _resolvedMetadataPath;

  @override
  void initState() {
    super.initState();
    _hoverController = ImageHoverPreviewController();
  }

  @override
  void didUpdateWidget(covariant LocalImageHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _hoverController.dismiss();
    if (oldWidget.record.path != widget.record.path) {
      _hoverController.dismissFor(oldWidget.record.path);
      _resolvedMetadata = null;
      _resolvedMetadataPath = null;
    }
  }

  void _schedulePreview() {
    if (!widget.enabled) return;
    unawaited(_resolveMetadata());
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final mediaQuery = MediaQuery.of(context);
    final safeViewport = _safeViewportRect(mediaQuery);
    final targetRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;

    final previewSize = Size(
      math.max(0.0, safeViewport.width),
      math.max(0.0, safeViewport.height),
    );
    if (previewSize.isEmpty) return;

    _hoverController.schedule(
      context: context,
      stableKey: widget.record.path,
      layerLink: _layerLink,
      targetRect: targetRect,
      previewSize: previewSize,
      delay: widget.hoverDelay,
      builder: (_) => LocalImageHoverPreviewCard(
        record: _resolvedMetadataPath == widget.record.path
            ? widget.record.copyWith(metadata: _resolvedMetadata)
            : widget.record,
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
        targetRect: targetRect,
        safeViewport: safeViewport,
      ),
    );
  }

  Rect _safeViewportRect(MediaQueryData mediaQuery) {
    const margin = 12.0;
    final left = mediaQuery.padding.left + margin;
    final top = mediaQuery.padding.top + margin;
    final right = mediaQuery.size.width - mediaQuery.padding.right - margin;
    final obstructedBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewInsets.bottom,
    );
    final bottom = mediaQuery.size.height - obstructedBottom - margin;
    return Rect.fromLTRB(left, top, math.max(left, right), math.max(top, bottom));
  }

  Future<void> _resolveMetadata() async {
    final path = widget.record.path;
    if (_resolvedMetadataPath == path) return;
    final metadata = await resolveLocalGalleryMetadata(widget.record);
    if (!mounted || widget.record.path != path) return;
    _resolvedMetadata = metadata;
    _resolvedMetadataPath = path;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _schedulePreview(),
        onExit: (_) => _hoverController.dismissFor(widget.record.path),
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }
}

/// Full-resolution local image preview with a deliberately compact info footer.
class LocalImageHoverPreviewCard extends StatefulWidget {
  const LocalImageHoverPreviewCard({
    super.key,
    required this.record,
    required this.maxWidth,
    required this.maxHeight,
    this.targetRect,
    this.safeViewport,
  });

  final LocalImageRecord record;
  final double maxWidth;
  final double maxHeight;
  final Rect? targetRect;
  final Rect? safeViewport;

  /// 根据图像宽高比与视口卡片坐标，计算预览卡片的目标尺寸（长边优先铺满）。
  static (double maxWidth, double maxHeight) calculatePreviewSize({
    required double? sourceAspectRatio,
    required Rect targetRect,
    required Rect safeViewport,
  }) {
    const gap = 12.0;
    const footerEstimatedHeight = 110.0;
    final leftSpace = (targetRect.left - gap) - safeViewport.left;
    final rightSpace = safeViewport.right - (targetRect.right + gap);
    final availableSideWidth = math.max(0.0, math.max(leftSpace, rightSpace));
    final availableHeight = math.max(0.0, safeViewport.height);

    final ratio = (sourceAspectRatio != null && sourceAspectRatio > 0)
        ? sourceAspectRatio
        : 1.0;

    if (ratio < 1.0) {
      // 竖图（宽高比 < 1.0）：长边（高度）占满视口可用高度
      final targetImageHeight =
          math.max(100.0, availableHeight - footerEstimatedHeight);
      final derivedWidth = targetImageHeight * ratio;
      // 宽度按原图比例自适应推导，不超过侧边可用宽度，且不小于 260
      final maxWidth = derivedWidth.clamp(
        math.min(260.0, availableSideWidth),
        math.max(260.0, availableSideWidth),
      );
      return (maxWidth.toDouble(), availableHeight.toDouble());
    } else {
      // 横图（宽高比 >= 1.0）：长边（宽度）占满侧边可用的视口宽度
      final maxImageHeight =
          math.max(100.0, availableHeight - footerEstimatedHeight);
      final maxWidthByHeight = maxImageHeight * ratio;
      final targetWidth = math.min(availableSideWidth, maxWidthByHeight);
      final maxWidth = targetWidth.clamp(
        math.min(320.0, availableSideWidth),
        math.max(320.0, availableSideWidth),
      );
      return (maxWidth.toDouble(), availableHeight.toDouble());
    }
  }

  @override
  State<LocalImageHoverPreviewCard> createState() =>
      _LocalImageHoverPreviewCardState();
}

class _LocalImageHoverPreviewCardState
    extends State<LocalImageHoverPreviewCard> {
  LocalGalleryThumbnailProvider? _imageProvider;
  late Future<(int, int)> _imageDimensions;
  double? _devicePixelRatio;
  NaiImageMetadata? _metadata;
  int _metadataRequestId = 0;

  @override
  void initState() {
    super.initState();
    _metadata = widget.record.metadata?.upgradeFromRawJsonIfNeeded();
    _imageDimensions = _loadImageDimensions();
    _loadMetadata();
  }

  (double, double) _resolveEffectiveSize(double ratio) {
    if (widget.targetRect != null && widget.safeViewport != null) {
      return LocalImageHoverPreviewCard.calculatePreviewSize(
        sourceAspectRatio: ratio,
        targetRect: widget.targetRect!,
        safeViewport: widget.safeViewport!,
      );
    }
    return (widget.maxWidth, widget.maxHeight);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    if (_imageProvider == null || _devicePixelRatio != pixelRatio) {
      _devicePixelRatio = pixelRatio;
      _prepareImageProvider(pixelRatio);
    }
  }

  @override
  void didUpdateWidget(covariant LocalImageHoverPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.path != widget.record.path ||
        oldWidget.record.size != widget.record.size ||
        oldWidget.record.modifiedAt != widget.record.modifiedAt ||
        oldWidget.targetRect != widget.targetRect ||
        oldWidget.safeViewport != widget.safeViewport) {
      _cancelPendingImage();
      _metadata = widget.record.metadata?.upgradeFromRawJsonIfNeeded();
      _prepareImageProvider(_devicePixelRatio ?? 1);
      _imageDimensions = _loadImageDimensions();
      _loadMetadata();
    }
  }

  void _prepareImageProvider(double pixelRatio, [double? ratio]) {
    _cancelPendingImage();
    final effectiveRatio = ratio ??
        (_metadata?.width != null &&
                _metadata?.height != null &&
                _metadata!.height! > 0
            ? _metadata!.width! / _metadata!.height!
            : 1.0);
    final (logicalWidth, logicalHeight) = _resolveEffectiveSize(effectiveRatio);
    final target = LocalGalleryThumbnailTarget.fromLogicalSize(
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: pixelRatio,
    );
    final provider = LocalGalleryThumbnailProvider(
      source: LocalGallerySourceIdentity.fromRecord(
        path: widget.record.path,
        size: widget.record.size,
        modifiedAt: widget.record.modifiedAt,
      ),
      target: target,
      fit: LocalGalleryThumbnailFit.contain,
    );
    LocalGalleryThumbnailMemoryCache.instance.register(provider);
    _imageProvider = provider;
  }

  void _cancelPendingImage() {
    final provider = _imageProvider;
    if (provider != null) {
      unawaited(
        LocalGalleryThumbnailMemoryCache.instance.cancelPending(provider),
      );
    }
  }

  Future<void> _loadMetadata() async {
    final requestId = ++_metadataRequestId;
    final path = widget.record.path;
    final metadata = await resolveLocalGalleryMetadata(widget.record);
    if (!mounted ||
        requestId != _metadataRequestId ||
        widget.record.path != path) {
      return;
    }
    setState(() => _metadata = metadata);
  }

  Future<(int, int)> _loadImageDimensions() async {
    // Generation metadata remains the original recipe after resizing or
    // enhancement. Only the encoded image describes the current pixel size.
    final buffer = await ui.ImmutableBuffer.fromFilePath(widget.record.path);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final dims = (descriptor.width, descriptor.height);
      if (mounted && dims.$2 > 0) {
        final ratio = dims.$1 / dims.$2;
        _prepareImageProvider(_devicePixelRatio ?? 1.0, ratio);
      }
      return dims;
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(int, int)>(
    key: const ValueKey('local-gallery-image-dimensions'),
    future: _imageDimensions,
    builder: (context, snapshot) => _buildPreview(
      context,
      snapshot.connectionState == ConnectionState.done ? snapshot.data : null,
    ),
  );

  Widget _buildPreview(BuildContext context, (int, int)? dimensions) {
    final theme = Theme.of(context);
    final metadata = _metadata;
    final model = metadata?.effectiveModel?.trim();
    final hasGenerationInfo =
        (model?.isNotEmpty ?? false) ||
        metadata?.seed != null ||
        metadata?.steps != null;
    final ratio = dimensions == null
        ? (_metadata?.width != null &&
                _metadata?.height != null &&
                _metadata!.height! > 0
            ? _metadata!.width! / _metadata!.height!
            : 1.0)
        : dimensions.$1 / dimensions.$2;
    final (resolvedMaxWidth, resolvedMaxHeight) = _resolveEffectiveSize(ratio);
    final imageProvider = _imageProvider;

    return ImageHoverPreviewSurface(
      key: const ValueKey('local-gallery-hover-preview'),
      sourceAspectRatio: ratio,
      maxWidth: resolvedMaxWidth,
      maxHeight: resolvedMaxHeight,
      mediaBuilder: (context, layout) => SizedBox(
        key: const ValueKey('local-gallery-hover-image'),
        width: layout.size.width,
        height: layout.size.height,
        child: imageProvider == null
            ? Center(
                child: CircularProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
                ),
              )
            : Image(
                image: imageProvider,
                fit: layout.fit,
                alignment: layout.alignment,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    LocalGalleryThumbnailMemoryCache.instance
                        .releasePendingOwner(imageProvider);
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: MediaQuery.disableAnimationsOf(context)
                          ? 0.72
                          : null,
                    ),
                  );
                },
                errorBuilder: (_, __, ___) {
                  LocalGalleryThumbnailMemoryCache.instance.releasePendingOwner(
                    imageProvider,
                  );
                  return Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 36,
                    ),
                  );
                },
              ),
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _fileName(widget.record.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ImageHoverPreviewMetric(
                    icon: Icons.photo_size_select_actual_outlined,
                    value: dimensions == null
                        ? '—'
                        : '${dimensions.$1}×${dimensions.$2}',
                    tone: ImageHoverPreviewTone.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ImageHoverPreviewMetric(
                    icon: Icons.data_usage_outlined,
                    value: formatBytes(widget.record.size),
                    tone: ImageHoverPreviewTone.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ImageHoverPreviewMetric(
                    icon: Icons.calendar_today_outlined,
                    value: _formatDate(widget.record.modifiedAt),
                    tone: ImageHoverPreviewTone.tertiary,
                  ),
                ),
              ],
            ),
            if (hasGenerationInfo) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  if (model?.isNotEmpty ?? false)
                    Expanded(
                      child: ImageHoverPreviewMetric(
                        icon: Icons.auto_awesome_outlined,
                        value: model!,
                        leading: ModelFamilyIcon(modelId: model, size: 13),
                        tone: ImageHoverPreviewTone.primary,
                      ),
                    ),
                  if (metadata?.seed != null) ...[
                    if (model?.isNotEmpty ?? false) const SizedBox(width: 6),
                    ImageHoverPreviewMetric(
                      icon: Icons.casino_outlined,
                      value: '${metadata!.seed}',
                      tone: ImageHoverPreviewTone.secondary,
                    ),
                  ],
                  if (metadata?.steps != null) ...[
                    const SizedBox(width: 6),
                    ImageHoverPreviewMetric(
                      icon: Icons.stairs_outlined,
                      value: '${metadata!.steps}',
                      tone: ImageHoverPreviewTone.tertiary,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _metadataRequestId++;
    _cancelPendingImage();
    super.dispose();
  }
}
