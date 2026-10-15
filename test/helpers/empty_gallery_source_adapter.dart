import 'package:dio/dio.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

class EmptyGallerySourceAdapter extends GallerySourceAdapter {
  EmptyGallerySourceAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: const [],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    rawItemCount: 0,
  );
}
