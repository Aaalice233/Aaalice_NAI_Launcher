import '../../core/database/datasources/gallery_data_source.dart';

/// 批量操作使用的画廊读写面：只暴露按批次读取原状态与逐图写入所需的方法
abstract interface class BulkGalleryStore {
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths);
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds);
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds);
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    required DateTime createdAt,
    required DateTime modifiedAt,
  });
  Future<void> setImageTags(int imageId, List<String> tags);
  Future<bool> toggleFavorite(int imageId);
}

/// GalleryDataSource 上的实现
class GalleryDataSourceBulkStore implements BulkGalleryStore {
  const GalleryDataSourceBulkStore(this._dataSource);

  final GalleryDataSource _dataSource;

  @override
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) =>
      _dataSource.getImageIdsByPaths(filePaths);

  @override
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) =>
      _dataSource.getTagsByImageIds(imageIds);

  @override
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) =>
      _dataSource.getFavoritesByImageIds(imageIds);

  @override
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    required DateTime createdAt,
    required DateTime modifiedAt,
  }) => _dataSource.upsertImage(
    filePath: filePath,
    fileName: fileName,
    fileSize: fileSize,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );

  @override
  Future<void> setImageTags(int imageId, List<String> tags) =>
      _dataSource.setImageTags(imageId, tags);

  @override
  Future<bool> toggleFavorite(int imageId) =>
      _dataSource.toggleFavorite(imageId);
}
