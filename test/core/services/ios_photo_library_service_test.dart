import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/ios_photo_library_service.dart';

void main() {
  test(
    'non-iOS hosts report unsupported instead of calling the plugin',
    () async {
      // 这条服务只服务 iOS 的显式「保存到相册」动作；在其他平台必须安静地
      // 返回 unsupported，绝不能变成第二条自动写系统相册的通道。
      expect(IosPhotoLibraryService.isSupported, isFalse);

      final result = await IosPhotoLibraryService.saveImageBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'NAI_1234.png',
      );

      expect(result.outcome, PhotoLibrarySaveOutcome.unsupported);
      expect(result.isSaved, isFalse);
    },
  );

  test('album item names drop directories and extensions', () {
    expect(
      IosPhotoLibraryService.albumItemNameFor('a/b/NAI_1234.png'),
      'NAI_1234',
    );
    expect(
      IosPhotoLibraryService.albumItemNameFor('noextension'),
      'noextension',
    );
    expect(IosPhotoLibraryService.albumItemNameFor(null), 'image');
    expect(IosPhotoLibraryService.albumItemNameFor('   '), 'image');
  });
}
