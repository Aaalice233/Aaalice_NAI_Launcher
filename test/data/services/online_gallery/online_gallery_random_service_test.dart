import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/services/online_gallery/online_gallery_random_service.dart';

void main() {
  test('accept removes duplicates and preserves the stable seen set', () {
    const service = OnlineGalleryRandomService(seenLimit: 3);
    final result = service.accept(
      candidates: [_item(1), _item(2), _item(2), _item(3), _item(4)],
      seenStableKeys: {'danbooru:1'},
    );

    expect(result.items.map((item) => item.stableKey), [
      'danbooru:2',
      'danbooru:3',
    ]);
    expect(result.seenStableKeys, {'danbooru:1', 'danbooru:2', 'danbooru:3'});
    expect(service.isExhausted(result.seenStableKeys), isTrue);
  });

  test('artist hunt de-duplicates candidates by detail identity', () {
    const service = OnlineGalleryRandomService();
    final candidates = service.unseenCandidates(
      items: [
        _item(1, workId: 'work-a'),
        _item(2, workId: 'work-b'),
      ],
      artistHuntActive: true,
      seenStableKeys: const {},
      seenCandidateStableKeys: {'danbooru:work-a'},
    );

    expect(candidates.map((item) => item.workId), ['work-b']);
  });
}

GalleryItem _item(int id, {String? workId}) => GalleryItem(
  id: id,
  workId: workId,
  sourceId: GallerySourceId.danbooru,
  cover: GalleryMedia(id: '$id'),
  createdAt: '2026-01-01',
);
