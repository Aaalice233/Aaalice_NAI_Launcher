import 'dart:io';

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

  /// 文件已不存在时返回 `false`，删除失败时抛出原始异常。
  Future<bool> delete(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    await file.delete();
    await _watermarks.remove(path);
    await _mosaics.remove(path);
    return true;
  }
}
