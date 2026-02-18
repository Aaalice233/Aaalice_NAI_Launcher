import 'dart:io';

import '../../../core/utils/app_logger.dart';

/// 画廊数据库服务（兼容层）
///
/// 这是一个简化的兼容层，用于支持尚未完全迁移到 V2 架构的代码。
/// 所有实际的数据操作已移至 GalleryDataSource。
class GalleryDatabaseService {
  static final GalleryDatabaseService _instance = GalleryDatabaseService._();
  static GalleryDatabaseService get instance => _instance;

  GalleryDatabaseService._();

  final Map<String, String> _fileHashes = {};

  /// 初始化
  Future<void> initialize() async {
    AppLogger.w('GalleryDatabaseService.initialize() called - this is a compatibility stub', 'GalleryDatabaseService');
  }

  /// 关闭
  Future<void> close() async {
    AppLogger.w('GalleryDatabaseService.close() called - this is a compatibility stub', 'GalleryDatabaseService');
  }

  /// 获取所有文件哈希
  Future<Map<String, String>> getAllFileHashes() async {
    return Map.unmodifiable(_fileHashes);
  }

  /// 批量插入或更新文件
  Future<void> batchInsertOrUpdateFiles(List<File> files, Map<String, dynamic> metadata) async {
    // 兼容层：空实现
  }

  /// 获取所有文件路径
  Future<List<String>> getAllFilePaths() async {
    return [];
  }

  /// 批量删除文件
  Future<void> batchDeleteFiles(List<String> paths) async {
    // 兼容层：空实现
  }

  /// 批量标记为已删除
  Future<void> batchMarkAsDeleted(List<String> paths) async {
    // 兼容层：空实现
  }

  /// 插入或更新图片（命名参数版本）
  Future<int> upsertImage({
    required String filePath,
    required String fileName,
    required int fileSize,
    required String fileHash,
    int? width,
    int? height,
    double? aspectRatio,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? resolutionKey,
  }) async {
    // 兼容层：返回模拟ID
    return 0;
  }

  /// 插入或更新元数据
  Future<void> upsertMetadata(int imageId, dynamic metadata) async {
    // 兼容层：空实现
  }

  /// 根据路径获取图片ID
  Future<int?> getImageIdByPath(String path) async {
    // 兼容层：返回null
    return null;
  }

  /// 全文搜索
  Future<List<int>> searchFullText(String query, {int? limit}) async {
    // 兼容层：返回空列表
    return [];
  }

  /// 查询图片
  Future<List<Map<String, dynamic>>> queryImages({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
    bool? favoritesOnly,
    List<String>? tags,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? model,
    String? sampler,
    int? minSteps,
    int? maxSteps,
    double? minCfg,
    double? maxCfg,
    String? resolution,
  }) async {
    // 兼容层：返回空列表
    return [];
  }

  /// 获取模型分布
  Future<List<Map<String, dynamic>>> getModelDistribution() async {
    // 兼容层：返回空列表
    return [];
  }

  /// 获取采样器分布
  Future<List<Map<String, dynamic>>> getSamplerDistribution() async {
    // 兼容层：返回空列表
    return [];
  }
}
