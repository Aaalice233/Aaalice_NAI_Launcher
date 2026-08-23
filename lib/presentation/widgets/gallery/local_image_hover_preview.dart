import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/utils/byte_format.dart';
import '../../../data/models/gallery/local_image_record.dart';
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../utils/local_gallery_metadata_resolver.dart';
import '../common/gallery_hover_controller.dart';

/// Adds a delayed, full-file hover preview to a local gallery card.
class LocalImageHoverPreview extends StatefulWidget {
  const LocalImageHoverPreview({
    super.key,
    required this.record,
    required this.child,
    this.hoverDelay = const Duration(milliseconds: 280),
  });

  final LocalImageRecord record;
  final Widget child;
  final Duration hoverDelay;

  @override
  State<LocalImageHoverPreview> createState() => _LocalImageHoverPreviewState();
}

class _LocalImageHoverPreviewState extends State<LocalImageHoverPreview> {
  final _layerLink = LayerLink();
  late final GalleryHoverController _hoverController;
  NaiImageMetadata? _resolvedMetadata;
  String? _resolvedMetadataPath;

  @override
  void initState() {
    super.initState();
    _hoverController = GalleryHoverController();
  }

  @override
  void didUpdateWidget(covariant LocalImageHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.path != widget.record.path) {
      _hoverController.dismissFor(oldWidget.record.path);
      _resolvedMetadata = null;
      _resolvedMetadataPath = null;
    }
  }

  void _schedulePreview() {
    unawaited(_resolveMetadata());
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
        record: _resolvedMetadataPath == widget.record.path
            ? widget.record.copyWith(metadata: _resolvedMetadata)
            : widget.record,
        maxWidth: previewSize.width,
        maxHeight: previewSize.height,
      ),
    );
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
  });

  final LocalImageRecord record;
  final double maxWidth;
  final double maxHeight;

  @override
  State<LocalImageHoverPreviewCard> createState() =>
      _LocalImageHoverPreviewCardState();
}

class _LocalImageHoverPreviewCardState
    extends State<LocalImageHoverPreviewCard> {
  ImageProvider? _imageProvider;
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
    if (oldWidget.record.path != widget.record.path) {
      _resolvedWidth = null;
      _resolvedHeight = null;
      _metadata = widget.record.metadata?.upgradeFromRawJsonIfNeeded();
      _prepareImageProvider(_devicePixelRatio ?? 1);
      if (!_hasMetadataDimensions) _loadImageDimensions();
      _loadMetadata();
    }
  }

  void _prepareImageProvider(double pixelRatio) {
    final targetWidth = math.max(1, (widget.maxWidth * pixelRatio).round());
    _imageProvider = ResizeImage.resizeIfNeeded(
      targetWidth,
      null,
      FileImage(File(widget.record.path)),
    );
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

  Future<void> _loadImageDimensions() async {
    final requestId = ++_dimensionRequestId;
    final path = widget.record.path;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final decoder = img.findDecoderForData(bytes);
      final info = decoder?.startDecode(bytes);
      if (!mounted || requestId != _dimensionRequestId || info == null) return;
      setState(() {
        _resolvedWidth = info.width;
        _resolvedHeight = info.height;
      });
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
    final metadataHeight = hasGenerationInfo ? 80.0 : 56.0;
    const borderExtent = 4.0;
    final contentMaxWidth = math.max(1, widget.maxWidth - borderExtent);
    final maxImageHeight = math.max(
      1,
      widget.maxHeight - metadataHeight - borderExtent,
    );
    final ratio = _aspectRatio ?? 1;
    final naturalHeight = contentMaxWidth / ratio;
    final imageHeight = math
        .min(maxImageHeight, math.max(150, naturalHeight))
        .toDouble();
    final widthForFullHeight = imageHeight * ratio;
    final cardWidth =
        (naturalHeight > maxImageHeight ? widthForFullHeight : contentMaxWidth)
            .clamp(math.min(220, contentMaxWidth), contentMaxWidth)
            .toDouble();

    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('local-gallery-hover-preview'),
        width: cardWidth,
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 32,
              spreadRadius: 6,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: SizedBox(
                key: const ValueKey('local-gallery-hover-image'),
                width: cardWidth,
                height: imageHeight,
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: _imageProvider == null
                      ? const Center(child: CircularProgressIndicator())
                      : Image(
                          image: _imageProvider!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 36,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(
              height: metadataHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName(widget.record.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: _PreviewStat(
                            icon: Icons.photo_size_select_actual_outlined,
                            value: _resolutionText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PreviewStat(
                            icon: Icons.data_usage_outlined,
                            value: formatBytes(widget.record.size),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PreviewStat(
                            icon: Icons.calendar_today_outlined,
                            value: _formatDate(widget.record.modifiedAt),
                          ),
                        ),
                      ],
                    ),
                    if (hasGenerationInfo) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (model?.isNotEmpty ?? false)
                            Expanded(
                              child: _PreviewStat(
                                icon: Icons.auto_awesome_outlined,
                                value: model!,
                              ),
                            ),
                          if (metadata?.seed != null) ...[
                            if (model?.isNotEmpty ?? false)
                              const SizedBox(width: 8),
                            _PreviewStat(
                              icon: Icons.casino_outlined,
                              value: '${metadata!.seed}',
                            ),
                          ],
                          if (metadata?.steps != null) ...[
                            const SizedBox(width: 8),
                            _PreviewStat(
                              icon: Icons.stairs_outlined,
                              value: '${metadata!.steps}',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
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
    super.dispose();
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}
