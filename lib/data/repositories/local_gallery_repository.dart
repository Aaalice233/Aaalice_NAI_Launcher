import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../models/gallery/local_image_record.dart';
import '../models/vibe/vibe_reference_v4.dart';

/// 顶级函数：在 Isolate 中解析 PNG 元数据 (用于 compute)
///
/// 避免主线程阻塞，提升 UI 流畅度
Future<VibeReferenceV4?> parseMetadataInIsolate(
  Map<String, dynamic> data,
) async {
  try {
    // VibeFileParser.fromPng 是静态异步方法
    return await VibeFileParser.fromPng(
      data['name'] as String,
      data['bytes'] as Uint8List,
    );
  } catch (e) {
    return null; // 解析失败返回 null
  }
}

/// 本地画廊仓库
///
/// 负责扫描 App 生成的图片目录并解析元数据
class LocalGalleryRepository {
  LocalGalleryRepository._();

  /// 获取图片保存目录
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
    final files = dir.listSync(recursive: false)
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

  /// 加载文件记录（批量解析元数据）
  ///
  /// [files] 要加载的文件列表
  /// 返回解析后的记录列表
  Future<List<LocalImageRecord>> loadRecords(List<File> files) async {
    final stopwatch = Stopwatch()..start();
    final records = await Future.wait(
      files.map((file) async {
        if (!file.existsSync()) {
           return LocalImageRecord(
              path: file.path, 
              size: 0, 
              modifiedAt: DateTime.now(), 
              metadataStatus: MetadataStatus.none,
           );
        }
        try {
          final bytes = await file.readAsBytes();
          final meta = await compute(parseMetadataInIsolate, {'name': path.basename(file.path), 'bytes': bytes});
          return LocalImageRecord(
            path: file.path, 
            size: bytes.length, 
            modifiedAt: file.lastModifiedSync(),
            metadata: meta,
            metadataStatus: meta != null ? MetadataStatus.success : MetadataStatus.none,
          );
        } catch (e) {
          return LocalImageRecord(
             path: file.path, 
             size: 0, 
             modifiedAt: file.lastModifiedSync(), 
             metadataStatus: MetadataStatus.none,
          );
        }
      }),
    );
    stopwatch.stop();
    AppLogger.i(
      'Page load completed: ${records.length} records in ${stopwatch.elapsedMilliseconds}ms',
      'LocalGalleryRepo',
    );
    return records;
  }

  /// 扫描本地图片并逐批返回
  ///
  /// 批次大小为 50,平衡 UI 更新频率和流开销
  @Deprecated('Use getAllImageFiles() + loadRecords() for better performance')
  Stream<List<LocalImageRecord>> scanImages() async* {
    try {
      final imageDir = await _getImageDirectory();

      if (!imageDir.existsSync()) {
        AppLogger.w(
          'Image directory not found: ${imageDir.path}',
          'LocalGalleryRepo',
        );
        return;
      }

      // 2. 获取所有 PNG 文件
      final files = imageDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.png'))
          .toList();

      AppLogger.i(
        'Found ${files.length} PNG files in ${imageDir.path}',
        'LocalGalleryRepo',
      );

      // 3. 批量处理（每批 50 张）
      final List<LocalImageRecord> batch = [];

      for (final file in files) {
        try {
          final bytes = await file.readAsBytes();

          // 使用 compute 在独立 Isolate 中解析，避免主线程阻塞 UI
          final metadata = await compute(
            parseMetadataInIsolate,
            {
              'name': path.basename(file.path),
              'bytes': bytes,
            },
          );

          batch.add(
            LocalImageRecord(
              path: file.path,
              size: bytes.length,
              modifiedAt: file.lastModifiedSync(),
              metadata: metadata,
              metadataStatus: metadata != null
                  ? MetadataStatus.success
                  : MetadataStatus.none,
            ),
          );

          // 达到批次大小时，发送当前批次
          if (batch.length >= 50) {
            yield List.from(batch);
            batch.clear();
          }
        } catch (e) {
          AppLogger.e(
            'Failed to process image: ${file.path}, error: $e',
            'LocalGalleryRepo',
          );
        }
      }

      // 4. 发送最后一批（不足 50 张）
      if (batch.isNotEmpty) {
        yield batch;
      }

      AppLogger.i(
        'Scan completed. Total images processed: ${files.length}',
        'LocalGalleryRepo',
      );
    } catch (e) {
      AppLogger.e(
        'Scan failed: $e',
        'LocalGalleryRepo',
      );
      rethrow;
    }
  }

  /// 单例实例
  static final LocalGalleryRepository instance = LocalGalleryRepository._();
}
