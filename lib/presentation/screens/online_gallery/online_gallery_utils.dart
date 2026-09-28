import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../core/cache/gallery_image_request.dart';
import '../../../data/models/online_gallery/danbooru_post.dart';

GalleryImageRequest createGalleryImageRequest({
  required BuildContext context,
  required GalleryItem item,
  required String url,
  required GalleryImageTier tier,
  required double logicalWidth,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final decodeWidth = switch (tier) {
    GalleryImageTier.thumbnail => GalleryImageSizing.gridTargetWidth(
      layoutWidth: logicalWidth,
      devicePixelRatio: dpr,
      naturalWidth: item.width,
      naturalHeight: item.height,
    ),
    GalleryImageTier.sample => GalleryImageSizing.hoverTargetWidth(
      dpr,
      naturalWidth: item.width,
      naturalHeight: item.height,
    ),
    GalleryImageTier.original => GalleryImageSizing.originalTargetWidth(
      dpr,
      logicalWidth,
      naturalWidth: item.width,
      naturalHeight: item.height,
    ),
  };
  return GalleryImageRequest.forUrl(
    sourceId: item.sourceId,
    url: url,
    tier: tier,
    targetDecodeWidth: decodeWidth,
  );
}

String resolveGalleryDownloadExtension(GalleryMedia media, String url) {
  final candidate = (media.extension ?? path.extension(Uri.parse(url).path))
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^\.'), '');
  return RegExp(r'^[a-z0-9]{1,10}$').hasMatch(candidate) ? candidate : 'webp';
}

String? quickTagCloudCategoryLabel(Object? rawPath) {
  final parts = switch (rawPath) {
    final Iterable<dynamic> values => values,
    final String value => value.split('/'),
    _ => const <dynamic>[],
  };
  for (final part in parts.toList().reversed) {
    final label = part.toString().trim();
    if (label.isNotEmpty) return label;
  }
  return null;
}
