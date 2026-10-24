import 'package:flutter/material.dart';

import '../../../core/cache/gallery_aspect_ratio_cache.dart';
import '../../../core/cache/local_gallery_thumbnail_provider.dart';
import '../../../data/models/gallery/local_image_record.dart';

/// 分组视图的单张卡片：宽高比在卡片内解析，读到结果只重建这张卡。
class GroupedGalleryCard extends StatefulWidget {
  const GroupedGalleryCard({
    super.key,
    required this.record,
    required this.aspectRatios,
    required this.builder,
  });

  final LocalImageRecord record;
  final GalleryAspectRatioCache aspectRatios;
  final Widget Function(BuildContext context, double aspectRatio) builder;

  @override
  State<GroupedGalleryCard> createState() => _GroupedGalleryCardState();
}

class _GroupedGalleryCardState extends State<GroupedGalleryCard> {
  late LocalGallerySourceIdentity _source;
  double _aspectRatio = GalleryAspectRatioCache.fallback;

  @override
  void initState() {
    super.initState();
    _syncAspectRatio();
  }

  @override
  void didUpdateWidget(GroupedGalleryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.record, widget.record) ||
        !identical(oldWidget.aspectRatios, widget.aspectRatios)) {
      _syncAspectRatio();
    }
  }

  void _syncAspectRatio() {
    final record = widget.record;
    final source = GalleryAspectRatioCache.sourceOf(record);
    _source = source;
    final known = widget.aspectRatios.peek(record);
    if (known != null) {
      _aspectRatio = known;
      return;
    }
    _aspectRatio = GalleryAspectRatioCache.fallback;
    widget.aspectRatios.resolve(record).then((value) {
      if (!mounted || _source != source || value == _aspectRatio) return;
      setState(() => _aspectRatio = value);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _aspectRatio);
}
