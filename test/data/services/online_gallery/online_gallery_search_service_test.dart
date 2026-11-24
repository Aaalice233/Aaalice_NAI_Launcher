import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_search_service.dart';

import '../../../helpers/ai_tag_character_gallery.dart';
import '../../../helpers/database_error_probe.dart';
import '../../../helpers/log_capture.dart';

void main() {
  test('AI TAG residual search uses positive character tags', () async {
    final adapter = aiTagCharacterGallery();
    final service = OnlineGallerySearchService();
    final page = await adapter.search(
      const GallerySearchRequest(cursor: '1', pageSize: 60, query: 'anchor'),
    );

    const expected = {
      'silver_ribbon': [11],
      'main_negative': <int>[],
      'character_negative': <int>[],
    };
    for (final entry in expected.entries) {
      final plan = await service.buildPlan(
        sourceId: GallerySourceId.aiTag,
        feedKind: GalleryFeedKind.search,
        serverTagLimit: 1,
        fuzzySearchEnabled: false,
        rawQuery: 'anchor ${entry.key}',
        metadataLoader: (_) async => {},
      );
      expect(plan.residual.single.value, entry.key);
      final result = await service.filterByPlan(
        candidates: page.items,
        plan: plan,
        capabilities: adapter.capabilities.tagSearch,
        feedKind: GalleryFeedKind.search,
        cancelToken: CancelToken(),
        detailLoader: (item, token) => adapter.detail(item, cancelToken: token),
      );

      expect(result.detailFailures, 0);
      expect(result.items.map((item) => item.id), entry.value);
    }
  });

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
