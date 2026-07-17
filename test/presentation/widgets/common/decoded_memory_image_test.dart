import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/widgets/common/decoded_memory_image.dart';

void main() {
  test('DecodedMemoryImage 根据逻辑尺寸计算解码缓存尺寸', () {
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: null,
        constrainedSize: 100,
        pixelRatio: 2,
      ),
      200,
    );
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: 50,
        constrainedSize: 100,
        pixelRatio: 2,
        decodeScale: 1.5,
      ),
      150,
    );
    expect(
      DecodedMemoryImage.resolveCacheDimension(
        logicalSize: null,
        constrainedSize: null,
        pixelRatio: 2,
      ),
      isNull,
    );
  });

  testWidgets('DecodedMemoryImage keeps the encoded aspect ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 200,
            child: DecodedMemoryImage(
              bytes: _testPngBytes(width: 200, height: 100),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());

    final provider = image.image as ResizeImage;
    expect(provider.width, 100);
    expect(provider.height, 200);
    expect(provider.policy, ResizeImagePolicy.fit);
  });
}

Uint8List _testPngBytes({required int width, required int height}) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}
