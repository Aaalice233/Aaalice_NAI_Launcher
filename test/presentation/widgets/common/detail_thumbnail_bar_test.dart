import 'dart:typed_data';

import 'package:flutter/gestures.dart';
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

  testWidgets('replacing an identifier resets thumbnail interaction state', (
    tester,
  ) async {
    final firstProvider = MemoryImage(Uint8List.fromList(const [1]));
    final secondProvider = MemoryImage(Uint8List.fromList(const [2]));
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    Widget buildThumbnail(_TestImageDetailData data) {
      return MaterialApp(
        home: DetailThumbnailBar(
          images: [data],
          currentIndex: -1,
          scrollController: scrollController,
          onTap: (_) {},
        ),
      );
    }

    await tester.pumpWidget(
      buildThumbnail(_TestImageDetailData(firstProvider, identifier: 'first')),
    );
    final thumbnail = find.byType(AnimatedContainer);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(thumbnail));
    await tester.pumpAndSettle();
    expect(tester.getSize(thumbnail).width, 86);

    await tester.pumpWidget(
      buildThumbnail(
        _TestImageDetailData(secondProvider, identifier: 'second'),
      ),
    );
    await tester.pump();

    expect(tester.getSize(thumbnail).width, 80);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as ResizeImage).imageProvider, same(secondProvider));
  });
}

class _TestImageDetailData implements ImageDetailData {
  _TestImageDetailData(this.provider, {this.identifier = 'test'});

  final ImageProvider<Object> provider;

  @override
  final String identifier;

  @override
  ImageProvider<Object> getImageProvider() => provider;

  @override
  Future<Uint8List> getImageBytes() async => Uint8List(0);

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get isFavorite => false;

  @override
  FileInfo? get fileInfo => null;

  @override
  bool get showSaveButton => false;

  @override
  bool get showCopyButton => false;

  @override
  bool get showFavoriteButton => false;

  @override
  bool get preserveOriginalBytesOnSave => false;
}
