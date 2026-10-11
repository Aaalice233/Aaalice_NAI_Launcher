import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/models/gallery/local_image_record.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';

void main() {
  test(
    'generated detail data can hide actions while keeping metadata',
    () async {
      const metadata = NaiImageMetadata(
        prompt: 'snapshot prompt',
        negativePrompt: 'snapshot negative',
        width: 512,
        height: 768,
      );
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 16, height: 16)),
      );

      final detail = GeneratedImageDetailData(
        imageBytes: bytes,
        metadata: metadata,
        id: 'failed-snapshot',
        showSaveButton: false,
        showCopyButton: false,
      );

      expect(detail.identifier, equals('failed-snapshot'));
      expect(detail.metadata, same(metadata));
      expect(await detail.getMetadataAsync(), same(metadata));
      expect(detail.showSaveButton, isFalse);
      expect(detail.showCopyButton, isFalse);
      expect(detail.showFavoriteButton, isFalse);
      expect(await detail.getImageBytes(), orderedEquals(bytes));
    },
  );

  test('file detail data keeps the sync file info free of disk access', () {
    final detail = FileImageDetailData(filePath: 'C:/tmp/never_created.png');

    final info = detail.fileInfo;
    expect(info.path, 'C:/tmp/never_created.png');
    expect(info.fileName, 'never_created.png');
    expect(info.size, isNull);
    expect(info.modifiedAt, isNull);
  });

  test(
    'file detail data reads size and modified time asynchronously',
    () async {
      final directory = await Directory.systemTemp.createTemp('file_detail_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}image.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 4)));

      final info = await FileImageDetailData(
        filePath: file.path,
      ).getFileInfoAsync();

      expect(info.fileName, 'image.png');
      expect(info.size, file.lengthSync());
      expect(info.modifiedAt, isNotNull);
    },
  );

  test('file detail data reports unknown stat for a missing file', () async {
    final directory = await Directory.systemTemp.createTemp('file_detail_');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}absent.png';

    final info = await FileImageDetailData(filePath: path).getFileInfoAsync();

    expect(info.fileName, 'absent.png');
    expect(info.size, isNull);
    expect(info.modifiedAt, isNull);
  });

  test('file detail data can hide copy without changing save visibility', () {
    final detail = FileImageDetailData(
      filePath: 'C:\\tmp\\failed_snapshot.png',
      showCopyButton: false,
    );

    expect(detail.showSaveButton, isFalse);
    expect(detail.showCopyButton, isFalse);
    expect(detail.showFavoriteButton, isTrue);
  });

  test('local detail data keeps copy and favorite visible by default', () {
    final record = LocalImageRecord(
      path: 'C:\\tmp\\local_image.png',
      metadata: null,
      size: 128,
      modifiedAt: DateTime(2026),
    );

    final detail = LocalImageDetailData(record);

    expect(detail.showSaveButton, isFalse);
    expect(detail.showCopyButton, isTrue);
    expect(detail.showFavoriteButton, isTrue);
  });

  test('local detail data caps decode size even without metadata', () {
    final record = LocalImageRecord(
      path: 'C:\\tmp\\large_plain.png',
      metadata: null,
      size: 128,
      modifiedAt: DateTime(2026),
    );

    final detail = LocalImageDetailData(record);
    final provider = detail.getImageProvider();

    expect(provider, isA<ResizeImage>());
    final resized = provider as ResizeImage;
    expect(resized.width, 4096);
    expect(resized.height, 4096);
    expect(resized.policy, ResizeImagePolicy.fit);
  });
}
