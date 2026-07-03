import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_category_tree_view.dart';

void main() {
  group('GalleryCategoryTreeView drag data', () {
    test('reads original gallery path from internal drag localData', () {
      expect(
        galleryInternalDragPathFromLocalData({
          'source': 'gallery_internal',
          'path': r'C:\gallery\image.png',
          'externalPayload': 'gallery_sanitized',
        }),
        r'C:\gallery\image.png',
      );
    });

    test('ignores non-gallery localData', () {
      expect(
        galleryInternalDragPathFromLocalData({
          'source': 'history_internal',
          'path': r'C:\gallery\image.png',
        }),
        isNull,
      );
    });
  });
}
