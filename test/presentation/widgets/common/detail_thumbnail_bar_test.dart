import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  testWidgets('thumbnail bar does not compose ResizeImage providers', (
    tester,
  ) async {
    final sourceProvider = MemoryImage(Uint8List.fromList(const [1]));
    final data = _TestImageDetailData(
      ResizeImage(ResizeImage(sourceProvider, width: 4096), height: 4096),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DetailThumbnailBar(
          images: [data],
          currentIndex: 0,
          scrollController: ScrollController(),
          onTap: (_) {},
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final thumbnailProvider = image.image as ResizeImage;

    expect(thumbnailProvider.width, 160);
    expect(thumbnailProvider.imageProvider, same(sourceProvider));
    expect(thumbnailProvider.imageProvider, isNot(isA<ResizeImage>()));
  });
}

class _TestImageDetailData implements ImageDetailData {
  _TestImageDetailData(this.provider);

  final ImageProvider<Object> provider;

  @override
  ImageProvider<Object> getImageProvider() => provider;

  @override
  Future<Uint8List> getImageBytes() async => Uint8List(0);

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get isFavorite => false;

  @override
  String get identifier => 'test';

  @override
  FileInfo? get fileInfo => null;

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => false;

  @override
  bool get showFavoriteButton => false;
}
