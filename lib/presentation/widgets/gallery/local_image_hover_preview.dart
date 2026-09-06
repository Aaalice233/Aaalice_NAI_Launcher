import 'dart:async';
import 'dart:io';
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
    this.metadataLoader,
  });

  final LocalImageRecord record;
  final Widget child;
  final Duration hoverDelay;
  final LocalGalleryMetadataLoader? metadataLoader;

  @override
  State<LocalImageHoverPreview> createState() => _LocalImageHoverPreviewState();
}

class _LocalImageHoverPreviewState extends State<LocalImageHoverPreview> {
  final _layerLink = LayerLink();
  late final ImageHoverPreviewController _hoverController;

  @override
  void initState() {
    super.initState();
    _hoverController = ImageHoverPreviewController();
  }

  @override
  void didUpdateWidget(covariant LocalImageHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.path != widget.record.path) {
      _hoverController.dismissFor(oldWidget.record.path);
    }
  }

  void _schedulePreview() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final viewport = MediaQuery.sizeOf(context);
    final previewSize = Size(
      math.min(360, math.max(0, viewport.width - 20)),
      math.max(0, viewport.height - 20),
    );
    if (previewSize.isEmpty) return;

    _hoverController.schedule(
      context: context,
      stableKey: widget.record.path,
      layerLink: _layerLink,
      targetRect: renderObject.localToGlobal(Offset.zero) & renderObject.size,
      previewSize: previewSize,
      delay: widget.hoverDelay,
      builder: (_) => LocalImageHoverPreviewCard(
        record: widget.record,
        metadataLoader: widget.metadataLoader,
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
      ),
    );
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
    this.metadataLoader,
  });

  final LocalImageRecord record;
  final double maxWidth;
  final double maxHeight;
  final LocalGalleryMetadataLoader? metadataLoader;

  @override
  State<LocalImageHoverPreviewCard> createState() =>
      _LocalImageHoverPreviewCardState();
}

class _LocalImageHoverPreviewCardState
    extends State<LocalImageHoverPreviewCard> {
  LocalGalleryThumbnailProvider? _imageProvider;
  int? _resolvedWidth;
  int? _resolvedHeight;
  double? _devicePixelRatio;
  NaiImageMetadata? _metadata;
  int _dimensionRequestId = 0;
  int _metadataRequestId = 0;

  int? get _width {
    final width = _metadata?.width;
    return width != null && width > 0 ? width : _resolvedWidth;
  }

  int? get _height {
    final height = _metadata?.height;
    return height != null && height > 0 ? height : _resolvedHeight;
  }

  bool get _hasMetadataDimensions =>
      (_metadata?.width ?? 0) > 0 && (_metadata?.height ?? 0) > 0;

  double? get _aspectRatio {
    final width = _width;
    final height = _height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return width / height;
  }

  @override
  void initState() {
    super.initState();
    _metadata = widget.record.metadata?.upgradeFromRawJsonIfNeeded();
    if (!_hasMetadataDimensions) _loadImageDimensions();
    _loadMetadata();
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
        oldWidget.record.modifiedAt != widget.record.modifiedAt) {
      _cancelPendingImage();
      _resolvedWidth = null;
      _resolvedHeight = null;
      _metadata = widget.record.metadata?.upgradeFromRawJsonIfNeeded();
      _prepareImageProvider(_devicePixelRatio ?? 1);
      if (!_hasMetadataDimensions) _loadImageDimensions();
      _loadMetadata();
    }
  }

  void _prepareImageProvider(double pixelRatio) {
    _cancelPendingImage();
    final target = LocalGalleryThumbnailTarget.fromLogicalSize(
      logicalWidth: widget.maxWidth,
      logicalHeight: widget.maxHeight,
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
    final metadata = await resolveLocalGalleryMetadata(
      widget.record,
      loadFromFile: widget.metadataLoader,
    );
    if (!mounted ||
        requestId != _metadataRequestId ||
        widget.record.path != path) {
      return;
    }
    setState(() => _metadata = metadata);
  }

  Future<void> _loadImageDimensions() async {
    final requestId = ++_dimensionRequestId;
    final path = widget.record.path;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      ui.ImageDescriptor? descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        if (!mounted || requestId != _dimensionRequestId) return;
        setState(() {
          _resolvedWidth = descriptor!.width;
          _resolvedHeight = descriptor.height;
        });
      } finally {
        descriptor?.dispose();
        buffer.dispose();
      }
    } catch (_) {
      // The image itself still reports a useful load error in the preview.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _metadata;
    final model = metadata?.effectiveModel?.trim();
    final hasGenerationInfo =
        (model?.isNotEmpty ?? false) ||
        metadata?.seed != null ||
        metadata?.steps != null;
    final ratio = _aspectRatio ?? 1;
    final imageProvider = _imageProvider;

    return ImageHoverPreviewSurface(
      key: const ValueKey('local-gallery-hover-preview'),
      sourceAspectRatio: ratio,
      maxWidth: widget.maxWidth,
      maxHeight: widget.maxHeight,
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
                    value: _resolutionText,
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

  String get _resolutionText {
    final width = _width;
    final height = _height;
    return width != null && height != null ? '$width×$height' : '—';
  }

  String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _dimensionRequestId++;
    _metadataRequestId++;
    _cancelPendingImage();
    super.dispose();
  }
}
