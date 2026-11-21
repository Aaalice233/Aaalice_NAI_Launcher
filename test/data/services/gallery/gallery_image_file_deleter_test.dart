import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/mosaic/mosaic_derivative_registry.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/watermark/watermark_derivative_registry.dart';
import 'package:nai_launcher/data/services/gallery/gallery_image_file_deleter.dart';

void main() {
  late Directory directory;
  late _MemoryStorage storage;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('nai_file_deleter_');
    storage = _MemoryStorage();
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('删除文件并清理以该路径登记的水印与打码衍生关系', () async {
    final source = File('${directory.path}/source.png');
    final output = File('${directory.path}/output.png');
    await source.writeAsBytes([1]);
    await output.writeAsBytes([2]);
    final watermarks = WatermarkDerivativeRegistry(storage);
    final mosaics = MosaicDerivativeRegistry(storage);
    await watermarks.register(outputPath: output.path, sourcePath: source.path);
    await mosaics.register(outputPath: output.path, sourcePath: source.path);

    final deleted = await GalleryImageFileDeleter(storage).delete(output.path);

    expect(deleted, isTrue);
    expect(await output.exists(), isFalse);
    expect(await source.exists(), isTrue);
    expect(watermarks.find(output.path), isNull);
    expect(mosaics.find(output.path), isNull);
  });

  test('文件已不存在时返回 false 且不改动登记', () async {
    final missing = '${directory.path}/missing.png';
    final watermarks = WatermarkDerivativeRegistry(storage);
    await watermarks.register(
      outputPath: missing,
      sourcePath: '${directory.path}/source.png',
    );

    final deleted = await GalleryImageFileDeleter(storage).delete(missing);

    expect(deleted, isFalse);
    expect(watermarks.find(missing), isNotNull);
  });

  test('文件的父目录不可达时保留路径异常', () async {
    final path = '${directory.path}/unreachable/image.png';
    await expectLater(
      GalleryImageFileDeleter(storage).delete(path),
      throwsA(isA<PathNotFoundException>()),
    );
  });

  test('登记写入失败时文件已消失，另一种登记仍完成清理', () async {
    final output = await File('${directory.path}/output.png').create();
    final watermarks = WatermarkDerivativeRegistry(storage);
    final mosaics = MosaicDerivativeRegistry(storage);
    for (final registry in [watermarks, mosaics]) {
      await registry.register(
        outputPath: output.path,
        sourcePath: 'source.png',
      );
    }
    storage.failWritesTo = StorageKeys.watermarkDerivativeRegistryV1;

    await expectLater(
      GalleryImageFileDeleter(storage).delete(output.path),
      throwsA(
        isA<GalleryImageCleanupException>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
    expect(await output.exists(), isFalse);
    expect(watermarks.find(output.path), isNotNull);
    expect(mosaics.find(output.path), isNull);
  });
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};
  String? failWritesTo;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (key == failWritesTo) throw StateError('registry write failed');
    values[key] = value;
  }
}
