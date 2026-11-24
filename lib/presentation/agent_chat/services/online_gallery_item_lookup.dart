import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../providers/online_gallery_provider.dart';
import 'online_gallery_resource_identity.dart';

GalleryItem? visibleOnlineGalleryItem(
  Ref ref,
  OnlineGalleryResourceIdentity identity,
) => ref
    .read(onlineGalleryNotifierProvider)
    .posts
    .where(identity.matches)
    .firstOrNull;

Future<GalleryItem?> locateOnlineGalleryItem(
  OnlineGalleryResourceIdentity identity, {
  required GalleryItem? visibleItem,
  required GallerySourceAdapter adapter,
  CancelToken? cancelToken,
}) async {
  if (visibleItem != null) return visibleItem;
  switch (identity.source) {
    case GallerySourceId.danbooru:
    case GallerySourceId.safebooru:
    case GallerySourceId.gelbooru:
      final page = await adapter.search(
        GallerySearchRequest(
          cursor: '1',
          pageSize: 1,
          query: 'id:${identity.workId}',
        ),
        cancelToken: cancelToken,
      );
      return page.items
          .where((item) => item.sourceWorkId == identity.workId)
          .firstOrNull;
    case GallerySourceId.aiTag:
    case GallerySourceId.quickTagCloud:
      return GalleryItem(
        id: int.tryParse(identity.workId) ?? 0,
        workId: identity.workId,
        sourceId: identity.source,
        focusedMediaId: identity.mediaId,
      );
  }
}
