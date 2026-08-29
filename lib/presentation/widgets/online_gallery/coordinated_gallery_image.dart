import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/utils/app_logger.dart';

/// Routes gallery image downloads through the shared network QoS coordinator.
///
/// Already decoded pixels remain visible while critical requests pause gallery
/// traffic. Images that were still loading resume after the pause ends.
class CoordinatedGalleryImage extends StatefulWidget {
  const CoordinatedGalleryImage({
    super.key,
    required this.request,
    required this.coordinator,
    this.priority = GalleryImagePriority.visible,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  final GalleryImageRequest request;
  final OnlineGalleryPrefetchCoordinator coordinator;
  final GalleryImagePriority priority;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<CoordinatedGalleryImage> createState() =>
      _CoordinatedGalleryImageState();
}

class _CoordinatedGalleryImageState extends State<CoordinatedGalleryImage> {
  bool _ready = false;
  bool _failed = false;
  bool _requesting = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinator.addListener(_handleCoordinatorChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _requestImage();
  }

  @override
  void didUpdateWidget(CoordinatedGalleryImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final coordinatorChanged = !identical(
      oldWidget.coordinator,
      widget.coordinator,
    );
    final requestChanged =
        oldWidget.request.stableRequestKey != widget.request.stableRequestKey;
    if (coordinatorChanged) {
      oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
      widget.coordinator.addListener(_handleCoordinatorChanged);
    }
    if (coordinatorChanged || requestChanged) {
      _revision += 1;
      _requesting = false;
      if (requestChanged) {
        _ready = false;
        _failed = false;
      } else if (!_ready) {
        _failed = false;
      }
      _requestImage();
    }
  }

  @override
  void dispose() {
    _revision += 1;
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    if (_ready || widget.coordinator.isPaused) return;
    if (_failed && !widget.coordinator.isNegativelyCached(widget.request)) {
      setState(() => _failed = false);
    }
    if (!_failed) _requestImage();
  }

  void _requestImage() {
    if (_ready || _failed || _requesting || widget.request.url.isEmpty) return;
    _requesting = true;
    final revision = ++_revision;
    widget.coordinator.submit(widget.request, priority: widget.priority).then((
      loaded,
    ) {
      if (!mounted || revision != _revision) return;
      final negativelyCached = widget.coordinator.isNegativelyCached(
        widget.request,
      );
      setState(() {
        _requesting = false;
        _ready = loaded;
        _failed = negativelyCached;
      });
      if (!loaded &&
          !widget.coordinator.isDisposed &&
          !widget.coordinator.isPaused &&
          !negativelyCached) {
        scheduleMicrotask(_requestImage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.errorWidget ?? const SizedBox.shrink();
    if (!_ready) return widget.placeholder ?? const SizedBox.shrink();
    return Image(
      image: widget.request.createImageProvider(
        OnlineGalleryImageCacheManager.instance,
      ),
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      errorBuilder: (_, error, __) {
        if (!_failed) {
          _failed = true;
          AppLogger.w(
            'Gallery image decode failed after coordinated preload: '
                'source=${widget.request.sourceKey}, errorType=${error.runtimeType}',
            'GalleryImage',
          );
        }
        return widget.errorWidget ?? const SizedBox.shrink();
      },
    );
  }
}
