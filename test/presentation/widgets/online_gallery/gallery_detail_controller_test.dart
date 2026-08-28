import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/widgets/online_gallery/gallery_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recomputes media index when only focused media index changes', () {
    const media = [GalleryMedia(id: 'first'), GalleryMedia(id: 'second')];
    const initialItem = GalleryItem(
      id: 1,
      workId: 'work-1',
      sourceId: GallerySourceId.aiTag,
      focusedMediaIndex: 0,
    );
    const updatedItem = GalleryItem(
      id: 1,
      workId: 'work-1',
      sourceId: GallerySourceId.aiTag,
      focusedMediaIndex: 1,
    );
    const detail = GalleryDetail(item: initialItem, media: media);
    final controller = GalleryDetailController(
      item: initialItem,
      detail: detail,
      isFavorited: false,
    );
    addTearDown(controller.dispose);

    controller.update(item: updatedItem, detail: detail, isFavorited: false);

    expect(controller.mediaIndex, 1);
    expect(controller.currentMedia?.id, 'second');
  });
}
