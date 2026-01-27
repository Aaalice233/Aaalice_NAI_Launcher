import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../models/gallery/nai_image_metadata.dart';
import 'gallery_database_service.dart';

/// 扫描结果
class ScanResult {
  int filesScanned = 0;
  int filesAdded = 0;
  int filesUpdated = 0;
  int filesDeleted = 0;
  Duration duration = Duration.zero;
  List<String> errors = [];

  @override
  String toString() {
    return 'ScanResult(scanned: $filesScanned, added: $filesAdded, '
        'updated: $filesUpdated, deleted: $filesDeleted, duration: $duration)';
  }
}

/// 画廊扫描服务
///
/// 实现增量扫描和文件指纹检测，高效处理大量图片
class GalleryScanService {
  final GalleryDatabaseService _db;

  /// 支持的图片扩展名
  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];

  /// 批量处理大小
  static const int _batchSize = 100;

  GalleryScanService({required GalleryDatabaseService db}) : _db = db;

  /// 单例实例
  static GalleryScanService? _instance;
  static GalleryScanService get instance {
    _instance ??= GalleryScanService(db: GalleryDatabaseService.instance);
    return _instance!;
  }

  /// 全量扫描
  Future<ScanResult> fullScan(Directory rootDir) async {
    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Starting full scan: ${rootDir.path}', 'GalleryScanService');

    try {
      // 收集所有图片文件
      final files = await _collectImageFiles(rootDir);
      result.filesScanned = files.length;

      AppLogger.i('Found ${files.length} image files', 'GalleryScanService');

      // 分批处理
      for (var i = 0; i < files.length; i += _batchSize) {
        final batch = files.skip(i).take(_batchSize).toList();
        await _processBatch(batch, result, isFullScan: true);

        // 进度日志
        if ((i + _batchSize) % 500 == 0 || i + _batchSize >= files.length) {
          AppLogger.d(
            'Processed ${i + batch.length}/${files.length} files',
            'GalleryScanService',
          );
        }
      }
    } catch (e, stack) {
      AppLogger.e('Full scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    // 记录扫描历史
    await _db.insertScanHistory(
      scanType: 'full',
      rootPath: rootDir.path,
      filesScanned: result.filesScanned,
      filesAdded: result.filesAdded,
      filesUpdated: result.filesUpdated,
      filesDeleted: result.filesDeleted,
      scanDurationMs: result.duration.inMilliseconds,
      startedAt: startTime,
      completedAt: DateTime.now(),
    );

    AppLogger.i('Full scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 增量扫描（仅扫描变化的文件）
  Future<ScanResult> incrementalScan(Directory rootDir) async {
    final startTime = DateTime.now();
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Starting incremental scan: ${rootDir.path}', 'GalleryScanService');

    try {
      // 获取数据库中所有文件的哈希映射
      final existingFiles = await _db.getAllFileHashes();
      final existingPaths = existingFiles.keys.toSet();

      AppLogger.d('Existing files in database: ${existingPaths.length}', 'GalleryScanService');

      // 扫描文件系统
      final currentFiles = <File>[];
      final currentPaths = <String>{};

      await for (final file in _scanDirectory(rootDir)) {
        currentFiles.add(file);
        currentPaths.add(file.path);
        result.filesScanned++;
      }

      AppLogger.d('Current files on disk: ${currentFiles.length}', 'GalleryScanService');

      // 检测新增和修改的文件
      final filesToProcess = <File>[];

      for (final file in currentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (!existingPaths.contains(path)) {
          // 新文件
          filesToProcess.add(file);
        } else if (existingHash != null) {
          // 检查文件是否被修改（通过哈希）
          final currentHash = await _computeFileHash(file);
          if (currentHash != existingHash) {
            filesToProcess.add(file);
          }
        }
      }

      AppLogger.d('Files to process: ${filesToProcess.length}', 'GalleryScanService');

      // 分批处理新增/修改的文件
      for (var i = 0; i < filesToProcess.length; i += _batchSize) {
        final batch = filesToProcess.skip(i).take(_batchSize).toList();
        await _processBatch(batch, result, isFullScan: false);
      }

      // 检测已删除的文件
      final deletedPaths = existingPaths.difference(currentPaths);
      if (deletedPaths.isNotEmpty) {
        AppLogger.d('Deleted files: ${deletedPaths.length}', 'GalleryScanService');
        await _db.batchMarkAsDeleted(deletedPaths.toList());
        result.filesDeleted = deletedPaths.length;
      }
    } catch (e, stack) {
      AppLogger.e('Incremental scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    // 记录扫描历史
    await _db.insertScanHistory(
      scanType: 'incremental',
      rootPath: rootDir.path,
      filesScanned: result.filesScanned,
      filesAdded: result.filesAdded,
      filesUpdated: result.filesUpdated,
      filesDeleted: result.filesDeleted,
      scanDurationMs: result.duration.inMilliseconds,
      startedAt: startTime,
      completedAt: DateTime.now(),
    );

    AppLogger.i('Incremental scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 收集目录下所有图片文件
  Future<List<File>> _collectImageFiles(Directory dir) async {
    final files = <File>[];

    await for (final file in _scanDirectory(dir)) {
      files.add(file);
    }

    return files;
  }

  /// 递归扫描目录
  Stream<File> _scanDirectory(Directory dir) async* {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          yield entity;
        }
      }
    }
  }

  /// 批量处理文件
  Future<void> _processBatch(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
  }) async {
    final imageMaps = <Map<String, dynamic>>[];
    final metadataList = <int, NaiImageMetadata>{};

    for (final file in files) {
      try {
        final stat = await file.stat();
        final fileName = p.basename(file.path);
        final fileHash = await _computeFileHash(file);

        // 解析图片尺寸和元数据
        NaiImageMetadata? metadata;
        int? width;
        int? height;

        // 只对PNG文件尝试提取NAI元数据
        if (p.extension(file.path).toLowerCase() == '.png') {
          final bytes = await file.readAsBytes();
          metadata = await compute(
            (Map<String, dynamic> data) async {
              return NaiMetadataParser.parseInIsolate(data);
            },
            {'bytes': bytes},
          );

          if (metadata != null) {
            width = metadata.width;
            height = metadata.height;
          }
        }

        // 如果没有从元数据获取尺寸，尝试从文件获取
        if (width == null || height == null) {
          final dimensions = await _getImageDimensions(file);
          width = dimensions.$1;
          height = dimensions.$2;
        }

        final aspectRatio = (width != null && height != null && height > 0)
            ? width / height
            : null;
        final resolutionKey = (width != null && height != null)
            ? '${width}x$height'
            : null;

        imageMaps.add({
          'file_path': file.path,
          'file_name': fileName,
          'file_size': stat.size,
          'file_hash': fileHash,
          'width': width,
          'height': height,
          'aspect_ratio': aspectRatio,
          'created_at': stat.modified.millisecondsSinceEpoch,
          'modified_at': stat.modified.millisecondsSinceEpoch,
          'indexed_at': DateTime.now().millisecondsSinceEpoch,
          'date_ymd': _formatDateYmd(stat.modified),
          'resolution_key': resolutionKey,
        });

        if (metadata != null && metadata.hasData) {
          metadataList[imageMaps.length - 1] = metadata;
        }

        if (isFullScan) {
          result.filesAdded++;
        } else {
          // 增量扫描时判断是新增还是更新
          final existingId = await _db.getImageIdByPath(file.path);
          if (existingId != null) {
            result.filesUpdated++;
          } else {
            result.filesAdded++;
          }
        }
      } catch (e) {
        AppLogger.w('Failed to process file: ${file.path}: $e', 'GalleryScanService');
        result.errors.add('${file.path}: $e');
      }
    }

    // 批量插入图片记录
    if (imageMaps.isNotEmpty) {
      await _db.batchInsertImages(imageMaps);

      // 插入元数据
      for (final entry in metadataList.entries) {
        final imageMap = imageMaps[entry.key];
        final imageId = await _db.getImageIdByPath(imageMap['file_path'] as String);
        if (imageId != null) {
          await _db.upsertMetadata(imageId, entry.value);
        }
      }
    }
  }

  /// 计算文件SHA256哈希
  Future<String> _computeFileHash(File file) async {
    try {
      // 只读取文件的前8KB和后8KB计算快速哈希
      // 这样可以大幅提升性能，同时仍能检测大部分文件变化
      final stat = await file.stat();
      final fileSize = stat.size;

      if (fileSize <= 16384) {
        // 小文件直接计算完整哈希
        final bytes = await file.readAsBytes();
        return sha256.convert(bytes).toString();
      }

      // 大文件只读取首尾部分
      final raf = await file.open(mode: FileMode.read);
      try {
        final headBytes = await raf.read(8192);
        await raf.setPosition(fileSize - 8192);
        final tailBytes = await raf.read(8192);

        final combined = Uint8List(headBytes.length + tailBytes.length + 8);
        combined.setAll(0, headBytes);
        combined.setAll(headBytes.length, tailBytes);

        // 加入文件大小作为额外校验
        final sizeBytes = ByteData(8);
        sizeBytes.setInt64(0, fileSize);
        combined.setAll(headBytes.length + tailBytes.length, sizeBytes.buffer.asUint8List());

        return sha256.convert(combined).toString();
      } finally {
        await raf.close();
      }
    } catch (e) {
      AppLogger.w('Failed to compute hash for ${file.path}: $e', 'GalleryScanService');
      return '';
    }
  }

  /// 获取图片尺寸
  Future<(int?, int?)> _getImageDimensions(File file) async {
    try {
      // 简化实现：直接返回null，让UI层按需加载
      // 完整实现需要使用image包解析图片头部
      return (null, null);
    } catch (e) {
      return (null, null);
    }
  }

  /// 格式化日期为YYYYMMDD整数
  int _formatDateYmd(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }
}
