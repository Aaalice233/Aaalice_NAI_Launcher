import 'dart:io';

import '../../core/utils/app_logger.dart';
import '../models/gallery/local_image_record.dart';

export '../models/gallery/local_image_record.dart' show LocalImageRecord;

/// 扫描结果
class ScanResult {
  final int totalFiles;
  final int newFiles;
  final int updatedFiles;
  final int failedFiles;
  final Duration duration;

  const ScanResult({
    required this.totalFiles,
    required this.newFiles,
    required this.updatedFiles,
    required this.failedFiles,
    required this.duration,
  });
}

/// 批量操作结果
class BulkOperationResult {
  final int successCount;
  final int failedCount;
  final List<String> errors;

  const BulkOperationResult({
    required this.successCount,
    required this.failedCount,
    required this.errors,
  });
}

/// 本地画廊仓库（兼容层）
///
/// 这是一个简化的兼容层，用于支持尚未完全迁移到 V2 架构的代码。
/// 所有实际的数据操作已移至 GalleryDataSource。
class LocalGalleryRepository {
  static final LocalGalleryRepository _instance = LocalGalleryRepository._();
  static LocalGalleryRepository get instance => _instance;

  LocalGalleryRepository._();

  final List<File> _files = [];
  final Set<String> _favorites = {};
  final Map<String, List<String>> _tags = {};
  String? _imageDirectory;

  /// 获取图片目录
  String? getImageDirectory() => _imageDirectory;

  /// 设置图片目录
  void setImageDirectory(String? path) {
    _imageDirectory = path;
  }

  /// 获取所有图片文件
  Future<List<File>> getAllImageFiles() async {
    return List.unmodifiable(_files);
  }

  /// 初始化
  Future<void> initialize({
    required void Function({
      required int processed,
      required int total,
      String? currentFile,
      required String phase,
    }) onProgress,
  }) async {
    // 兼容层：空实现
    AppLogger.w('LocalGalleryRepository.initialize() called - this is a compatibility stub', 'LocalGalleryRepository');
    onProgress(processed: 0, total: 0, phase: 'completed');
  }

  /// 加载记录
  Future<List<LocalImageRecord>> loadRecords(List<File> files) async {
    return files.map((f) => LocalImageRecord(path: f.path, size: 0, modifiedAt: DateTime.now())).toList();
  }

  /// 增量扫描
  Future<void> performIncrementalScan() async {
    AppLogger.w('LocalGalleryRepository.performIncrementalScan() called - this is a compatibility stub', 'LocalGalleryRepository');
  }

  /// 全量扫描
  Future<ScanResult> performFullScan({
    required void Function({
      required int processed,
      required int total,
      String? currentFile,
      required String phase,
    }) onProgress,
  }) async {
    AppLogger.w('LocalGalleryRepository.performFullScan() called - this is a compatibility stub', 'LocalGalleryRepository');
    return const ScanResult(
      totalFiles: 0,
      newFiles: 0,
      updatedFiles: 0,
      failedFiles: 0,
      duration: Duration.zero,
    );
  }

  /// 高级搜索
  Future<List<LocalImageRecord>> advancedSearch({
    String? textQuery,
    bool favoritesOnly = false,
    DateTime? dateStart,
    DateTime? dateEnd,
    int? limit,
  }) async {
    return [];
  }

  /// 切换收藏
  Future<void> toggleFavorite(String filePath) async {
    if (_favorites.contains(filePath)) {
      _favorites.remove(filePath);
    } else {
      _favorites.add(filePath);
    }
  }

  /// 设置收藏状态
  Future<void> setFavorite(String filePath, bool isFavorite) async {
    if (isFavorite) {
      _favorites.add(filePath);
    } else {
      _favorites.remove(filePath);
    }
  }

  /// 是否收藏
  Future<bool> isFavorite(String filePath) async {
    return _favorites.contains(filePath);
  }

  /// 获取收藏总数
  int getTotalFavoriteCount() => _favorites.length;

  /// 获取标签
  Future<List<String>> getTags(String filePath) async {
    return _tags[filePath] ?? [];
  }

  /// 设置标签
  Future<void> setTags(String filePath, List<String> tags) async {
    _tags[filePath] = tags;
  }
}
