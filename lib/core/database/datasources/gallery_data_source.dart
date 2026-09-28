import '../../../data/models/gallery/gallery_dashboard_snapshot.dart';
import '../../../data/models/gallery/local_image_record.dart'
    show MetadataStatus;
import '../../../data/models/gallery/nai_image_metadata.dart';
import '../../utils/app_logger.dart';
import '../base_data_source.dart';
import '../data_source.dart' show DataSourceHealth, DataSourceType;
import 'gallery_album_repository.dart';
import 'gallery_database_gateway.dart';
import 'gallery_favorite_tag_repository.dart';
import 'gallery_image_repository.dart';
import 'gallery_metadata_repository.dart';
import 'gallery_query.dart';
import 'gallery_records.dart';
import 'gallery_schema.dart';
import 'gallery_store_context.dart';

export 'gallery_album_repository.dart';
export 'gallery_database_gateway.dart';
export 'gallery_favorite_tag_repository.dart';
export 'gallery_image_repository.dart';
export 'gallery_metadata_repository.dart';
export 'gallery_query.dart';
export 'gallery_records.dart';
export 'gallery_store_context.dart';

/// Backward-compatible gallery facade.
///
/// Storage behavior lives in mockable repositories composed through a shared
/// gateway and store context. Existing callers can keep using this singleton.
class GalleryDataSource extends EnhancedBaseDataSource {
  static final GalleryDataSource _instance = GalleryDataSource._internal();

  factory GalleryDataSource() => _instance;

  GalleryDataSource._internal() {
    _gateway = EnhancedGalleryDatabaseGateway(this);
    _schema = GallerySchema(gateway: _gateway, context: _context);
    _images = SqliteGalleryImageRepository(
      gateway: _gateway,
      context: _context,
    );
    _metadata = SqliteGalleryMetadataRepository(
      gateway: _gateway,
      context: _context,
      images: _images,
    );
    _favoriteTags = SqliteGalleryFavoriteTagRepository(
      gateway: _gateway,
      context: _context,
    );
    _albums = SqliteGalleryAlbumRepository(
      gateway: _gateway,
      context: _context,
    );
    _query = SqliteGalleryQuery(gateway: _gateway, context: _context);
  }

  final GalleryStoreContext _context = GalleryStoreContext();
  late final GalleryDatabaseGateway _gateway;
  late final GallerySchema _schema;
  late final GalleryImageRepository _images;
  late final GalleryMetadataRepository _metadata;
  late final GalleryFavoriteTagRepository _favoriteTags;
  late final GalleryAlbumRepository _albums;
  late final GalleryQuery _query;

  @override
  String get name => 'gallery';

  @override
  DataSourceType get type => DataSourceType.gallery;

  @override
  Set<String> get dependencies => const {};

  int get dataRevision => _context.dataRevision;

  void clearCache() => _context.clearCache();
  void clearQueryCache() => _context.clearQueryCache();
  Map<String, dynamic> getCacheStatistics() => _context.cacheStatistics;
  List<SlowQueryLog> getSlowQueryLogs() => _context.slowQueryLogs;

  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    int? width,
    int? height,
    double? aspectRatio,
    required DateTime createdAt,
    required DateTime modifiedAt,
    String? resolutionKey,
    MetadataStatus? metadataStatus,
    bool? isFavorite,
    DateTime? lastScannedAt,
  }) => _images.upsertImage(
    filePath: filePath,
    fileName: fileName,
    fileSize: fileSize,
    width: width,
    height: height,
    aspectRatio: aspectRatio,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    resolutionKey: resolutionKey,
    metadataStatus: metadataStatus,
    isFavorite: isFavorite,
    lastScannedAt: lastScannedAt,
  );

  Future<int?> getImageIdByPath(String filePath) =>
      _images.getImageIdByPath(filePath);
  Future<void> updateFilePath(
    int imageId,
    String newPath, {
    String? newFileName,
  }) => _images.updateFilePath(imageId, newPath, newFileName: newFileName);
  Future<Map<String, int?>> getImageIdsByPaths(List<String> filePaths) =>
      _images.getImageIdsByPaths(filePaths);
  Future<GalleryImageRecord?> getImageById(int id) => _images.getImageById(id);
  Future<List<GalleryImageRecord>> getImagesByIds(List<int> ids) =>
      _images.getImagesByIds(ids);
  Future<List<GalleryImageRecord>> queryImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) => _images.queryImages(
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );
  Future<List<GalleryImageRecord>> queryFavoriteImages({
    int limit = 50,
    int offset = 0,
    String orderBy = 'modified_at',
    bool descending = true,
  }) => _images.queryFavoriteImages(
    limit: limit,
    offset: offset,
    orderBy: orderBy,
    descending: descending,
  );
  Future<void> markAsDeleted(String filePath) =>
      _images.markAsDeleted(filePath);
  Future<List<int>> batchUpsertImages(
    List<GalleryImageRecord> records, {
    int batchSize = 50,
  }) => _images.batchUpsertImages(records, batchSize: batchSize);
  Future<void> batchMarkAsDeleted(List<String> filePaths) =>
      _images.batchMarkAsDeleted(filePaths);
  Future<int> countImages({bool includeDeleted = false}) =>
      _images.countImages(includeDeleted: includeDeleted);
  Future<Map<String, int>> countImagesByMetadataStatus() =>
      _images.countImagesByMetadataStatus();

  Future<void> upsertMetadata(int imageId, NaiImageMetadata metadata) =>
      _metadata.upsertMetadata(imageId, metadata);
  Future<void> batchUpsertMetadata(
    List<MapEntry<int, NaiImageMetadata>> metadataList, {
    int batchSize = 50,
  }) => _metadata.batchUpsertMetadata(metadataList, batchSize: batchSize);
  Future<GalleryMetadataRecord?> getMetadataByImageId(int imageId) =>
      _metadata.getMetadataByImageId(imageId);
  Future<Map<int, GalleryMetadataRecord?>> getMetadataByImageIds(
    List<int> imageIds,
  ) => _metadata.getMetadataByImageIds(imageIds);

  Future<bool> toggleFavorite(int imageId) =>
      _favoriteTags.toggleFavorite(imageId);
  Future<bool> isFavorite(int imageId) => _favoriteTags.isFavorite(imageId);
  Future<void> loadFavoritesCache() => _favoriteTags.loadFavoritesCache();
  Future<int> getFavoriteCount() => _favoriteTags.getFavoriteCount();
  Future<List<int>> getFavoriteImageIds() =>
      _favoriteTags.getFavoriteImageIds();
  Future<Map<int, bool>> getFavoritesByImageIds(List<int> imageIds) =>
      _favoriteTags.getFavoritesByImageIds(imageIds);
  Future<void> addTag(int imageId, String tagName) =>
      _favoriteTags.addTag(imageId, tagName);
  Future<void> removeTag(int imageId, String tagName) =>
      _favoriteTags.removeTag(imageId, tagName);
  Future<List<String>> getImageTags(int imageId) =>
      _favoriteTags.getImageTags(imageId);
  Future<Map<int, List<String>>> getTagsByImageIds(List<int> imageIds) =>
      _favoriteTags.getTagsByImageIds(imageIds);
  Future<void> setImageTags(int imageId, List<String> tags) =>
      _favoriteTags.setImageTags(imageId, tags);

  GalleryAlbumRepository get albums => _albums;

  Future<List<int>> searchFullText(String query, {int limit = 100}) =>
      _query.searchFullText(query, limit: limit);
  Future<List<int>> searchByFileName(String query, {int limit = 100}) =>
      _query.searchByFileName(query, limit: limit);
  Future<List<int>> searchByMetadataText(String query, {int limit = 100}) =>
      _query.searchByMetadataText(query, limit: limit);
  Future<List<int>> searchByDelimitedTextSegments(
    List<String> segments, {
    int limit = 100,
    List<String>? candidatePaths,
  }) => _query.searchByDelimitedTextSegments(
    segments,
    limit: limit,
    candidatePaths: candidatePaths,
  );
  Future<List<int>> advancedSearch({
    String? textQuery,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool favoritesOnly = false,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    int? minFileSize,
    int? maxFileSize,
    List<String>? metadataStatuses,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfgScale,
    double? maxCfgScale,
    String? resolution,
    int limit = 100,
  }) => _query.advancedSearch(
    textQuery: textQuery,
    dateStart: dateStart,
    dateEnd: dateEnd,
    favoritesOnly: favoritesOnly,
    minWidth: minWidth,
    minHeight: minHeight,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    minFileSize: minFileSize,
    maxFileSize: maxFileSize,
    metadataStatuses: metadataStatuses,
    model: model,
    sampler: sampler,
    minSteps: minSteps,
    maxSteps: maxSteps,
    minCfgScale: minCfgScale,
    maxCfgScale: maxCfgScale,
    resolution: resolution,
    limit: limit,
  );

  Future<List<GalleryImageRecord>> getAllImages() => _query.getAllImages();
  Future<List<Map<String, dynamic>>> getModelDistribution() =>
      _query.getModelDistribution();
  Future<List<Map<String, dynamic>>> getSamplerDistribution() =>
      _query.getSamplerDistribution();
  Future<GalleryDashboardSnapshot> getDashboardStatistics() =>
      _query.getDashboardStatistics();

  Future<void> deleteAllImages() => _images.deleteAllImages();
  Future<void> deleteAllMetadata() => _metadata.deleteAllMetadata();

  @override
  Future<void> doInitialize() => _schema.initialize();

  @override
  Future<DataSourceHealth> doCheckHealth() => _schema.checkHealth();

  @override
  Future<void> doClear() => _schema.clear();

  @override
  Future<void> doRestore() => _schema.restore();

  @override
  Future<void> doDispose() async {
    clearCache();
    AppLogger.i('Gallery data source disposed', 'GalleryDS');
  }
}
