import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

/// 必保 #27 顺带的低清占位图：上游没有这个成员，详情页在原图解码完成前是纯色。
/// 占位刻意不复用 `LocalGalleryThumbnailProvider`——它的解码调度器被
/// `setGalleryVisible()` 门控，从生成页打开详情页时任务永远不会被 drain。
void main() {
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );

  test(
    'a file-backed image exposes a downscaled placeholder provider',
    () async {
      final directory = await Directory.systemTemp.createTemp('detail-ph');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/sample.png')
        ..writeAsBytesSync(pngBytes);

      final placeholder = await FileImageDetailData(
        filePath: file.path,
      ).getPlaceholderProvider();

      final resize = placeholder as ResizeImage;
      expect((resize.imageProvider as FileImage).file.path, file.path);
      // 降采样目标必须小于 getImageProvider 的 4096 上限，否则占位没有意义。
      expect(resize.width, lessThan(4096));
      expect(resize.height, lessThan(4096));
    },
  );

  test(
    'a missing file and in-memory bytes both degrade to no placeholder',
    () async {
      expect(
        await FileImageDetailData(
          filePath: '${Directory.systemTemp.path}/definitely-absent.png',
        ).getPlaceholderProvider(),
        isNull,
      );
      expect(
        await GeneratedImageDetailData(
          imageBytes: Uint8List.fromList(pngBytes),
        ).getPlaceholderProvider(),
        isNull,
      );
    },
  );
}
