import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/utils/encoded_image_dimensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads the encoded size and releases the buffer', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 7, height: 3)),
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);

    expect(await readEncodedImageDimensions(buffer), (7, 3));
    expect(buffer.debugDisposed, isTrue);
  });

  test('releases the buffer when the bytes are not an image', () async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(const [1, 2, 3, 4, 5, 6, 7, 8]),
    );

    await expectLater(readEncodedImageDimensions(buffer), throwsA(anything));
    expect(buffer.debugDisposed, isTrue);
  });
}
