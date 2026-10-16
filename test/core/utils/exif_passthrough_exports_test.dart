import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/image_save_utils.dart';
import 'package:nai_launcher/core/utils/image_share_sanitizer.dart';

import '../../helpers/exif_orientation_fixture.dart';

// 原字节直通的导出路径像素未动，EXIF 方向必须随原字节原样保留。
void main() {
  test(
    'copy and drag without stripping keep an oriented jpeg intact',
    () async {
      final jpeg = orientedCameraJpeg(orientation: 6);

      for (final prepare in [
        ImageShareSanitizer.prepareForCopyOrDrag,
        ImageShareSanitizer.prepareForCopyOrDragInBackground,
      ]) {
        final prepared = await prepare(
          jpeg,
          fileName: 'photo.jpg',
          stripMetadata: false,
        );

        expect(identical(prepared.bytes, jpeg), isTrue);
      }
    },
  );

  test('saving original bytes keeps an oriented jpeg intact', () async {
    final jpeg = orientedCameraJpeg(orientation: 6);

    final prepared = await ImageSaveUtils.prepareResultBytes(
      imageBytes: jpeg,
      preserveOriginalBytes: true,
    );

    expect(identical(prepared.bytes, jpeg), isTrue);
  });
}
