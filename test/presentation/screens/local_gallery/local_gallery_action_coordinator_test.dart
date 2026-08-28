import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/presentation/screens/local_gallery/local_gallery_action_coordinator.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';

void main() {
  test('single-image route request keeps its typed record and action', () {
    final record = LocalImageRecord(
      path: 'gallery/image.png',
      size: 42,
      modifiedAt: DateTime(2025),
    );
    final request = LocalGalleryImageAction(
      record: record,
      action: LocalImageContextAction.sendToImg2Img,
    );

    expect(request.record, same(record));
    expect(request.action, LocalImageContextAction.sendToImg2Img);
    expect(request.metadata, isNull);
  });
}
