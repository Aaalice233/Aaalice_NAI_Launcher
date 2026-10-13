import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/screens/online_gallery/online_gallery_download_plan.dart';

void main() {
  test('single-media AI TAG list item downloads the detail media', () async {
    final requested = <String>[];
    final plan = await planGalleryDownloads(
      [_pendingAiTagItem(101, mediaCount: 1)],
      loadDetail: (item) async {
        requested.add(item.sourceWorkId);
        return _detail(item, mediaCount: 1);
      },
    );

    expect(requested, ['101']);
    expect(plan.jobs, hasLength(1));
    expect(
      plan.jobs.single.media.downloadUrl,
      'https://example.test/101_p0.webp',
    );
    expect(plan.jobs.single.post.hasPendingCover, isFalse);
    expect(plan.skippedCount, 0);
    expect(plan.unresolvedCount, 0);
  });

  test('multi-media AI TAG item downloads every media', () async {
    final plan = await planGalleryDownloads(
      [_pendingAiTagItem(102, mediaCount: 3)],
      loadDetail: (item) async => _detail(item, mediaCount: 3),
    );

    expect(
      [for (final job in plan.jobs) (job.media.id, job.mediaIndex)],
      [('102_p0', 1), ('102_p1', 2), ('102_p2', 3)],
    );
  });

  test('failed or empty details count as unresolved, not skipped', () async {
    final plan = await planGalleryDownloads(
      [_pendingAiTagItem(103), _pendingAiTagItem(104)],
      loadDetail: (item) async {
        if (item.id == 103) throw StateError('offline');
        return GalleryDetail(item: item, media: const []);
      },
    );

    expect(plan.jobs, isEmpty);
    expect(plan.unresolvedCount, 2);
    expect(plan.skippedCount, 0);
  });

  test('items with a resolved cover never request details', () async {
    final plan = await planGalleryDownloads(
      [
        _resolvedItem(GallerySourceId.danbooru, 201),
        _resolvedItem(
          GallerySourceId.aiTag,
          202,
          mediaCount: 4,
          focusedMediaId: '202_p2',
          focusedMediaIndex: 2,
        ),
      ],
      loadDetail: (_) => fail('detail must not be requested'),
    );

    expect(
      [for (final job in plan.jobs) (job.post.sourceWorkId, job.mediaIndex)],
      [('201', 1), ('202', 3)],
    );
  });

  test('media-less items are skipped without a detail request', () async {
    const empty = GalleryItem(
      id: 7,
      workId: 'codex-7',
      sourceId: GallerySourceId.quickTagCloud,
      cover: GalleryMedia.noImage,
    );

    final plan = await planGalleryDownloads(
      [empty],
      loadDetail: (_) => fail('detail must not be requested'),
    );

    expect(canDownloadGalleryItem(empty), isFalse);
    expect(plan.jobs, isEmpty);
    expect(plan.skippedCount, 1);
    expect(plan.unresolvedCount, 0);
  });
}

GalleryItem _pendingAiTagItem(int id, {int mediaCount = 2}) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.aiTag,
  mediaCount: mediaCount,
  cover: GalleryMedia.pending('$id'),
);

GalleryItem _resolvedItem(
  GallerySourceId source,
  int id, {
  int mediaCount = 1,
  String? focusedMediaId,
  int? focusedMediaIndex,
}) => GalleryItem(
  id: id,
  sourceId: source,
  mediaCount: mediaCount,
  focusedMediaId: focusedMediaId,
  focusedMediaIndex: focusedMediaIndex,
  cover: _media(id, focusedMediaIndex ?? 0),
);

GalleryMedia _media(int id, int index) => GalleryMedia(
  id: '${id}_p$index',
  previewUrl: 'https://example.test/${id}_p$index.webp',
  displayUrl: 'https://example.test/${id}_p$index.webp',
  downloadUrl: 'https://example.test/${id}_p$index.webp',
  mediaType: 'image',
);

GalleryDetail _detail(GalleryItem item, {required int mediaCount}) {
  final media = [
    for (var index = 0; index < mediaCount; index++) _media(item.id, index),
  ];
  return GalleryDetail(
    item: item.copyWith(cover: media.first, mediaCount: mediaCount),
    media: media,
  );
}
