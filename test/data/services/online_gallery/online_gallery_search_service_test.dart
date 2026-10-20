import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_search_service.dart';

import '../../../helpers/database_error_probe.dart';
import '../../../helpers/log_capture.dart';

void main() {
  test('catalog failures never quote the search terms into the log', () async {
    final dbError = await databaseErrorCarrying('secret lighthouse keeper');

    final logs = await captureLogs(
      () => OnlineGallerySearchService().buildPlan(
        sourceId: GallerySourceId.danbooru,
        feedKind: GalleryFeedKind.search,
        serverTagLimit: 2,
        fuzzySearchEnabled: false,
        rawQuery: 'lighthouse',
        metadataLoader: (_) => Future.error(dbError),
      ),
    );

    expect(
      logs.where((line) => line.contains('Tag metadata unavailable')),
      hasLength(1),
    );
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
