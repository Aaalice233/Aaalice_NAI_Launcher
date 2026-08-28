import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/presentation/providers/local_gallery_provider.dart';

void main() {
  test('gallery state remains the file, filter, and page snapshot', () {
    final record = LocalImageRecord(
      path: 'gallery/image.png',
      size: 42,
      modifiedAt: DateTime(2025),
    );
    final state = LocalGalleryState(
      currentImages: [record],
      currentPage: 2,
      totalPages: 4,
      filteredCount: 11,
      totalCount: 20,
    );

    expect(state.allFiles, state.currentImages);
    expect(state.filteredFiles, state.currentImages);
    expect(state.currentPage, 2);
    expect(state.totalPages, 4);
    expect(state.filteredCount, 11);
    expect(state.totalCount, 20);
  });
}
