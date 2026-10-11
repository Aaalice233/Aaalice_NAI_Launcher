import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}

class _MemoryStorage extends LocalStorageService {
  final values = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] as T?) ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
