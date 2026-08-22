import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../data/models/online_gallery/gallery_source.dart';
import 'online_gallery_image_cache_manager.dart';

enum GalleryImageTier { thumbnail, sample, original }

enum GalleryImagePriority { interactiveDetail, hover, visible, lookahead }

class GalleryImageSizing {
  const GalleryImageSizing._();

  static int gridTargetWidth({
    required double layoutWidth,
    required double devicePixelRatio,
    int? naturalWidth,
    int? naturalHeight,
  }) {
    return _targetWidth(
      logicalWidth: layoutWidth,
      devicePixelRatio: devicePixelRatio,
      maxLongestEdge: 1600,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }

  static int hoverTargetWidth(
    double devicePixelRatio, {
    int? naturalWidth,
    int? naturalHeight,
  }) {
    return _targetWidth(
      logicalWidth: 320,
      devicePixelRatio: devicePixelRatio,
      maxLongestEdge: 1280,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }

  static int detailViewportTargetWidth(
    double devicePixelRatio,
    double viewportWidth, {
    int? naturalWidth,
    int? naturalHeight,
  }) {
    return _targetWidth(
      logicalWidth: viewportWidth,
      devicePixelRatio: devicePixelRatio,
      maxLongestEdge: 2560,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }

  static int originalTargetWidth(
    double devicePixelRatio,
    double viewportWidth, {
    int? naturalWidth,
    int? naturalHeight,
  }) {
    return _targetWidth(
      logicalWidth: viewportWidth * 2,
      devicePixelRatio: devicePixelRatio,
      maxLongestEdge: 4096,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
    );
  }

  static int _targetWidth({
    required double logicalWidth,
    required double devicePixelRatio,
    required int maxLongestEdge,
    int? naturalWidth,
    int? naturalHeight,
  }) {
    var target = (logicalWidth * devicePixelRatio)
        .ceil()
        .clamp(1, maxLongestEdge)
        .toInt();
    if (naturalWidth != null && naturalWidth > 0) {
      target = target.clamp(1, naturalWidth).toInt();
      if (naturalHeight != null && naturalHeight > naturalWidth) {
        final widthAtLongestEdge =
            maxLongestEdge * naturalWidth / naturalHeight;
        target = target.clamp(1, widthAtLongestEdge.ceil()).toInt();
      }
    }
    return target;
  }
}

class GalleryImageRequest {
  const GalleryImageRequest({
    required this.sourceId,
    required this.url,
    this.cacheKey,
    this.headers = const <String, String>{},
    required this.tier,
    this.targetDecodeWidth,
  });

  factory GalleryImageRequest.forUrl({
    GallerySourceId? sourceId,
    required String url,
    required GalleryImageTier tier,
    required int targetDecodeWidth,
  }) {
    return GalleryImageRequest(
      sourceId: sourceId ?? _sourceIdForUrl(url),
      url: url,
      cacheKey: onlineGalleryImageCacheKeyForUrl(url),
      headers: onlineGalleryImageHeadersForUrl(url),
      tier: tier,
      targetDecodeWidth: targetDecodeWidth,
    );
  }

  factory GalleryImageRequest.gelbooru({
    required String url,
    required GalleryImageTier tier,
    int? targetDecodeWidth,
  }) {
    final isGelbooru = Uri.tryParse(url)?.host.contains('gelbooru') == true;
    return GalleryImageRequest(
      sourceId: GallerySourceId.gelbooru.key,
      url: url,
      cacheKey: isGelbooru ? onlineGalleryImageCacheKeyForUrl(url) : null,
      headers: isGelbooru ? onlineGalleryImageHeadersForUrl(url) : const {},
      tier: tier,
      targetDecodeWidth: targetDecodeWidth,
    );
  }

  final Object sourceId;
  final String url;
  final String? cacheKey;
  final Map<String, String> headers;
  final GalleryImageTier tier;
  final int? targetDecodeWidth;

  static GallerySourceId _sourceIdForUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('gelbooru')) return GallerySourceId.gelbooru;
    if (host.contains('safebooru')) return GallerySourceId.safebooru;
    if (host.contains('aitag')) return GallerySourceId.aiTag;
    return GallerySourceId.danbooru;
  }

  String get canonicalCacheKey => cacheKey ?? url;

  String get sourceKey => sourceId is GallerySourceId
      ? (sourceId as GallerySourceId).key
      : sourceId.toString();

  String get stableRequestKey =>
      '$sourceKey:$canonicalCacheKey:${tier.name}:${targetDecodeWidth ?? 'auto'}';

  ImageProvider<Object> createImageProvider(CacheManager cacheManager) {
    final provider = CachedNetworkImageProvider(
      url,
      cacheManager: cacheManager,
      cacheKey: cacheKey,
      headers: headers,
    );
    final width = targetDecodeWidth;
    return width == null
        ? provider
        : ResizeImage.resizeIfNeeded(width, null, provider);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GalleryImageRequest &&
          other.stableRequestKey == stableRequestKey;

  @override
  int get hashCode => stableRequestKey.hashCode;

  @override
  String toString() => 'GalleryImageRequest($stableRequestKey)';
}
