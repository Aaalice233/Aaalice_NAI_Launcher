import 'dart:io';

import 'package:hive_ce/hive.dart' show HiveError;

import '../../../core/mosaic/mosaic_derivative_registry.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/watermark/watermark_derivative_registry.dart';

/// 永久删除图库中的图片文件，并清理以该路径登记的水印/打码衍生关系。
class GalleryImageFileDeleter {
  GalleryImageFileDeleter(LocalStorageService storage)
    : _watermarks = WatermarkDerivativeRegistry(storage),
      _mosaics = MosaicDerivativeRegistry(storage);

  final WatermarkDerivativeRegistry _watermarks;
  final MosaicDerivativeRegistry _mosaics;

  Future<bool> delete(String path) async {
    final file = File(path);
    try {
      await file.delete();
    } on PathNotFoundException {
      if (await file.parent.exists() && !await file.exists()) return false;
      rethrow;
    }
    try {
      await Future.wait([_watermarks.remove(path), _mosaics.remove(path)]);
    } on FileSystemException catch (error) {
      throw GalleryImageCleanupException(error);
    } on HiveError catch (error) {
      throw GalleryImageCleanupException(error);
    } on StateError catch (error) {
      throw GalleryImageCleanupException(error);
    }
    return true;
  }
}

class GalleryImageCleanupException implements Exception {
  const GalleryImageCleanupException(this.cause);

  final Object cause;
}
