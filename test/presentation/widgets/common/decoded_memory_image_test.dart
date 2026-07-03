import 'package:flutter_test/flutter_test.dart';
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
}
