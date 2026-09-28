import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/cache/gallery_image_request.dart';
import '../../../core/cache/online_gallery_image_cache_manager.dart';

class QueueTaskThumbnail extends StatelessWidget {
  const QueueTaskThumbnail({
    super.key,
    required this.source,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cacheWidth = GalleryImageSizing.gridTargetWidth(
      layoutWidth: width,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    if (_isRemoteSource(source)) {
      return CachedNetworkImage(
        imageUrl: source,
        httpHeaders: onlineGalleryImageHeadersForUrl(source),
        cacheKey: onlineGalleryImageCacheKeyForUrl(source),
        cacheManager: OnlineGalleryImageCacheManager.instance,
        memCacheWidth: cacheWidth,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _placeholder(context, loading: true),
        errorWidget: (context, url, error) => _placeholder(context),
      );
    }

    return Image.file(
      File(source),
      cacheWidth: cacheWidth,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _placeholder(context),
    );
  }

  bool _isRemoteSource(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Widget _placeholder(BuildContext context, {bool loading = false}) {
    final theme = Theme.of(context);
    final compact = width <= 64 || height <= 64;
    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: loading && !compact
          ? CircularProgressIndicator(
              strokeWidth: 2,
              value: MediaQuery.disableAnimationsOf(context) ? 0.72 : null,
            )
          : Icon(
              loading ? Icons.image_rounded : Icons.broken_image_rounded,
              size: compact ? 20 : 48,
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
    );
  }
}
