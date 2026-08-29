import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import 'coordinated_gallery_image.dart';

class ProgressiveGalleryImage extends StatefulWidget {
  const ProgressiveGalleryImage({
    super.key,
    required this.thumbnail,
    required this.sample,
    required this.coordinator,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final GalleryImageRequest thumbnail;
  final GalleryImageRequest sample;
  final OnlineGalleryPrefetchCoordinator coordinator;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  State<ProgressiveGalleryImage> createState() =>
      _ProgressiveGalleryImageState();
}

class _ProgressiveGalleryImageState extends State<ProgressiveGalleryImage> {
  bool _sampleReady = false;
  bool _showSampleImmediately = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_handleCoordinatorChanged);
    _sampleReady = widget.coordinator.isSampleReady(widget.sample);
    _showSampleImmediately = _sampleReady;
  }

  @override
  void dispose() {
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestSample();
  }

  @override
  void didUpdateWidget(ProgressiveGalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final coordinatorChanged = !identical(
      oldWidget.coordinator,
      widget.coordinator,
    );
    final sampleChanged =
        oldWidget.sample.stableRequestKey != widget.sample.stableRequestKey;
    if (coordinatorChanged) {
      oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
      widget.coordinator.addListener(_handleCoordinatorChanged);
    }
    if (coordinatorChanged || sampleChanged) {
      _revision++;
      _sampleReady = widget.coordinator.isSampleReady(widget.sample);
      _showSampleImmediately = _sampleReady;
      _requestSample();
    }
  }

  void _handleCoordinatorChanged() {
    if (!_sampleReady && !widget.coordinator.isPaused) _requestSample();
  }

  void _requestSample() {
    if (_sampleReady || widget.sample.url.isEmpty) return;
    final revision = ++_revision;
    widget.coordinator
        .submit(widget.sample, priority: GalleryImagePriority.hover)
        .then((loaded) {
          if (!mounted || revision != _revision || !loaded) return;
          setState(() {
            _sampleReady = true;
            _showSampleImmediately = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final manager = OnlineGalleryImageCacheManager.instance;
    final thumbnail = CoordinatedGalleryImage(
      request: widget.thumbnail,
      coordinator: widget.coordinator,
      priority: GalleryImagePriority.visible,
      fit: widget.fit,
      alignment: widget.alignment,
      errorWidget: const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
    if (!_sampleReady ||
        widget.sample.url.isEmpty ||
        widget.sample.url == widget.thumbnail.url) {
      return thumbnail;
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnail,
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: disableAnimations || _showSampleImmediately
              ? Duration.zero
              : const Duration(milliseconds: 140),
          builder: (_, opacity, child) =>
              Opacity(opacity: opacity, child: child),
          child: Image(
            image: widget.sample.createImageProvider(manager),
            fit: widget.fit,
            alignment: widget.alignment,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
