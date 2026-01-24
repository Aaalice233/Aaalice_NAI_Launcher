import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/nai_metadata_parser.dart';
import '../models/gallery/local_image_record.dart';
import '../models/gallery/nai_image_metadata.dart';
import '../services/local_metadata_cache_service.dart';

/// 顶级函数：在 Isolate 中解析 NAI 隐写元数据 (用于 compute)
///
/// 避免主线程阻塞，提升 UI 流畅度
Future<NaiImageMetadata?> parseNaiMetadataInIsolate(
  Map<String, dynamic> data,
) async {
  try {
    final bytes = data['bytes'] as Uint8List;
    return await NaiMetadataParser.extractFromBytes(bytes);
  } catch (e) {
    return null; // 解析失败返回 null
  }
}

/// 本地画廊仓库
///
/// 负责扫描 App 生成的图片目录并解析元数据
class LocalGalleryRepository {
  LocalGalleryRepository._();

  /// 元数据缓存服务
  final _cacheService = LocalMetadataCacheService();

  /// 获取收藏 Box
  Box get _favoritesBox => Hive.box(StorageKeys.localFavoritesBox);

  /// 获取图片保存目录（公共方法）
  ///
  /// 优先使用用户设置的自定义路径,否则使用默认路径
  /// 这是唯一的保存路径获取方法，保证保存和扫描使用同一目录
  Future<Directory> getImageDirectory() async {
    return _getImageDirectory();
  }

  /// 获取图片保存目录（内部方法）
  ///
  /// 优先使用用户设置的自定义路径,否则使用默认路径
  Future<Directory> _getImageDirectory() async {
    // 1. 获取图片保存路径（优先使用用户设置的自定义路径）
    // 从 Hive 读取,与 LocalStorageService 保持一致
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    final customPath = settingsBox.get(StorageKeys.imageSavePath) as String?;

    final Directory imageDir;
    if (customPath != null && customPath.isNotEmpty) {
      // 使用用户设置的自定义路径
      imageDir = Directory(customPath);
      AppLogger.i(
        'Using custom save path: ${imageDir.path}',
        'LocalGalleryRepo',
      );
    } else {
      // 使用默认路径：App 文档目录下的 nai_launcher/images
      final appDir = await getApplicationDocumentsDirectory();
      imageDir = Directory('${appDir.path}/nai_launcher/images');
      AppLogger.i(
        'Using default save path: ${imageDir.path}',
        'LocalGalleryRepo',
      );
    }

    return imageDir;
  }

  /// 快速路径：获取所有文件路径而不解析元数据
  ///
  /// 返回按修改时间降序排列的文件列表（最新优先）
  Future<List<File>> getAllImageFiles() async {
    final stopwatch = Stopwatch()..start();
    final dir = await _getImageDirectory();
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync(recursive: false)
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.png'))
        .toList()
      // 降序排序（最新优先）- 业务需求
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    stopwatch.stop();
    AppLogger.i(
      'Indexing completed: ${files.length} files in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );
    return files;
  }

  /// 加载文件记录（批量解析元数据，带缓存）
  ///
  /// [files] 要加载的文件列表
  /// 返回解析后的记录列表
  Future<List<LocalImageRecord>> loadRecords(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    int cacheHits = 0;
    int cacheMisses = 0;

    final records = await Future.wait(
      files.map((file) async {
        if (!file.existsSync()) {
          return LocalImageRecord(
            path: file.path,
            size: 0,
            modifiedAt: DateTime.now(),
            metadataStatus: MetadataStatus.none,
            isFavorite: isFavorite(file.path),
          );
        }

        final filePath = file.path;
        final fileModified = file.lastModifiedSync();

        // 尝试从缓存获取
        final cached = _cacheService.get(filePath);
        if (cached != null) {
          final cachedTs = cached['ts'] as DateTime;
          // 时间戳匹配 → 缓存命中
          if (cachedTs.millisecondsSinceEpoch ==
              fileModified.millisecondsSinceEpoch) {
            cacheHits++;
            final meta = cached['meta'] as NaiImageMetadata;
            return LocalImageRecord(
              path: filePath,
              size: file.lengthSync(),
              modifiedAt: fileModified,
              metadata: meta,
              metadataStatus:
                  meta.hasData ? MetadataStatus.success : MetadataStatus.none,
              isFavorite: isFavorite(filePath),
            );
          }
        }

        // 缓存未命中，解析文件
        cacheMisses++;
        try {
          final bytes = await file.readAsBytes();
          final meta =
              await compute(parseNaiMetadataInIsolate, {'bytes': bytes});

          // 写入缓存
          if (meta != null) {
            await _cacheService.put(filePath, meta, fileModified);
          }

          return LocalImageRecord(
            path: filePath,
            size: bytes.length,
            modifiedAt: fileModified,
            metadata: meta,
            metadataStatus: meta != null && meta.hasData
                ? MetadataStatus.success
                : MetadataStatus.none,
            isFavorite: isFavorite(filePath),
          );
        } catch (e) {
          AppLogger.w(
            'Failed to parse metadata for $filePath: $e',
            'LocalGalleryRepo',
          );
          return LocalImageRecord(
            path: filePath,
            size: 0,
            modifiedAt: fileModified,
            metadataStatus: MetadataStatus.failed,
            isFavorite: isFavorite(filePath),
          );
        }
      }),
    );
    stopwatch.stop();

    // 统计解析成功数量
    final successCount =
        records.where((r) => r.metadataStatus == MetadataStatus.success).length;
    AppLogger.i(
      'Page load completed: ${records.length} records ($successCount with metadata) '
          'in ${stopwatch.elapsedMilliseconds}ms [cache: $cacheHits hits, $cacheMisses misses]',
      'LocalGalleryRepo',
    );
    return records;
  }

  /// 从单个文件解析元数据
  ///
  /// 用于拖放等场景，需要即时解析
  Future<NaiImageMetadata?> parseMetadataFromFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await NaiMetadataParser.extractFromBytes(bytes);
    } catch (e) {
      AppLogger.e(
        'Failed to parse metadata from file: ${file.path}',
        e,
        null,
        'LocalGalleryRepo',
      );
      return null;
    }
  }

  /// 从字节数据解析元数据
  ///
  /// 用于拖放等场景
  Future<NaiImageMetadata?> parseMetadataFromBytes(Uint8List bytes) async {
    try {
      return await NaiMetadataParser.extractFromBytes(bytes);
    } catch (e) {
      AppLogger.e(
        'Failed to parse metadata from bytes',
        e,
        null,
        'LocalGalleryRepo',
      );
      return null;
    }
  }

  /// 获取图片的收藏状态
  bool isFavorite(String filePath) {
    return _favoritesBox.get(filePath, defaultValue: false) as bool;
  }

  /// 设置图片的收藏状态
  Future<void> setFavorite(String filePath, bool isFavorite) async {
    await _favoritesBox.put(filePath, isFavorite);
    AppLogger.d(
      'Set favorite: $filePath -> $isFavorite',
      'LocalGalleryRepo',
    );
  }

  /// 切换图片的收藏状态
  Future<bool> toggleFavorite(String filePath) async {
    final current = isFavorite(filePath);
    final newState = !current;
    await setFavorite(filePath, newState);
    return newState;
  }

  /// 单例实例
  static final LocalGalleryRepository instance = LocalGalleryRepository._();
}
