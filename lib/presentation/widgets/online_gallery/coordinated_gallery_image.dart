import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';
import '../../../core/cache/online_gallery_prefetch_coordinator.dart';
import '../../../core/utils/app_logger.dart';
import '../../themes/theme_extension.dart';

typedef GalleryImageErrorBuilder =
    Widget Function(BuildContext context, VoidCallback retry);

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
    this.errorBuilder,
    this.enabled = true,
    this.fadeIn = true,
  });

  final GalleryImageRequest request;
  final OnlineGalleryPrefetchCoordinator coordinator;
  final GalleryImagePriority priority;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Widget? placeholder;
  final Widget? errorWidget;
  final GalleryImageErrorBuilder? errorBuilder;
  final bool enabled;
  final bool fadeIn;

  @override
  State<CoordinatedGalleryImage> createState() =>
      _CoordinatedGalleryImageState();
}

class _CoordinatedGalleryImageState extends State<CoordinatedGalleryImage> {
  bool _ready = false;
  bool _failed = false;
  bool _requesting = false;
  bool _showImmediately = false;
  Future<void> _failedImageEviction = Future<void>.value();
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _ready = widget.coordinator.isReady(widget.request);
    _showImmediately = _ready;
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
    final enabledChanged = oldWidget.enabled != widget.enabled;
    if (coordinatorChanged) {
      oldWidget.coordinator.removeListener(_handleCoordinatorChanged);
      widget.coordinator.addListener(_handleCoordinatorChanged);
    }
    if (oldWidget.enabled &&
        (coordinatorChanged || requestChanged || !widget.enabled)) {
      oldWidget.coordinator.releasePending(oldWidget.request, this);
    }
    if (coordinatorChanged || requestChanged || enabledChanged) {
      _revision += 1;
      _requesting = false;
      if (requestChanged) {
        _ready = widget.coordinator.isReady(widget.request);
        _showImmediately = _ready;
        _failed = false;
        _failedImageEviction = Future<void>.value();
      } else if (!_ready && widget.enabled) {
        _failed = false;
      }
      _requestImage();
    }
  }

  @override
  void dispose() {
    _revision += 1;
    widget.coordinator.removeListener(_handleCoordinatorChanged);
    if (widget.enabled) {
      widget.coordinator.releasePending(widget.request, this);
    }
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    if (!mounted || !widget.enabled || _ready || widget.coordinator.isPaused) {
      return;
    }
    if (_failed && !widget.coordinator.isNegativelyCached(widget.request)) {
      setState(() => _failed = false);
    }
    if (!_failed) _requestImage();
  }

  void _requestImage({bool retry = false}) {
    if (!widget.enabled ||
        _ready ||
        _failed ||
        _requesting ||
        widget.request.url.isEmpty) {
      return;
    }
    _requesting = true;
    final revision = ++_revision;
    widget.coordinator
        .submit(
          widget.request,
          priority: widget.priority,
          retry: retry,
          consumer: this,
        )
        .then((loaded) {
          if (!mounted || revision != _revision) return;
          final negativelyCached = widget.coordinator.isNegativelyCached(
            widget.request,
          );
          setState(() {
            _requesting = false;
            _ready = loaded;
            _failed = negativelyCached;
          });
        });
  }

  void _retryImage() {
    if (_requesting) return;
    final revision = ++_revision;
    setState(() {
      _failed = false;
      _ready = false;
      _requesting = true;
    });
    unawaited(_retryAfterFailedImageEviction(revision));
  }

  Future<void> _retryAfterFailedImageEviction(int revision) async {
    await _failedImageEviction;
    if (!mounted || revision != _revision) return;
    _requesting = false;
    _requestImage(retry: true);
  }

  Widget _buildError(BuildContext context) {
    final builder = widget.errorBuilder;
    if (builder != null) return builder(context, _retryImage);
    return widget.errorWidget ?? const SizedBox.shrink();
  }

  Future<void> _evictFailedImage(
    ImageProvider<Object> imageProvider,
    GalleryImageRequest request,
    OnlineGalleryPrefetchCoordinator coordinator,
  ) async {
    try {
      await Future.wait([
        imageProvider.evict(),
        OnlineGalleryImageCacheManager.instance.removeFile(
          request.canonicalCacheKey,
        ),
      ]);
    } catch (error) {
      AppLogger.w(
        'Failed to evict undecodable gallery image: '
            'source=${request.sourceKey}, error=$error',
        'GalleryImage',
      );
    } finally {
      // Keep the completion marker until cleanup finishes so a retry cannot
      // publish fresh bytes before this eviction has finished.
      coordinator.invalidateCompleted(request);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _buildError(context);
    if (!_ready) return widget.placeholder ?? const SizedBox.shrink();
    final placeholder = widget.placeholder ?? const SizedBox.shrink();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final motion = Theme.of(context).appTheme;
    final fadeDuration = Duration(
      milliseconds: motion.fastDuration.inMilliseconds.clamp(120, 160),
    );
    final cacheManager = OnlineGalleryImageCacheManager.instance;
    final request = widget.request;
    final coordinator = widget.coordinator;
    final imageProvider = request.createImageProvider(cacheManager);
    return Image(
      image: imageProvider,
      fit: widget.fit,
      alignment: widget.alignment,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null) return placeholder;
        if (!widget.fadeIn ||
            wasSynchronouslyLoaded ||
            disableAnimations ||
            _showImmediately) {
          return child;
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            placeholder,
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: fadeDuration,
              curve: Curves.easeOutCubic,
              builder: (_, opacity, image) =>
                  Opacity(opacity: opacity, child: image),
              child: child,
            ),
          ],
        );
      },
      errorBuilder: (_, error, __) {
        if (request.stableRequestKey != widget.request.stableRequestKey ||
            !identical(coordinator, widget.coordinator)) {
          return placeholder;
        }
        if (!_failed) {
          _failed = true;
          _ready = false;
          _failedImageEviction = _evictFailedImage(
            imageProvider,
            request,
            coordinator,
          );
          unawaited(_failedImageEviction);
          AppLogger.w(
            'Gallery image decode failed after coordinated preload: '
                'source=${request.sourceKey}, errorType=${error.runtimeType}',
            'GalleryImage',
          );
        }
        return _buildError(context);
      },
    );
  }
}
