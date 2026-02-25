import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../image_metadata_batch_service.dart';
import '../image_metadata_service.dart';
import 'scan_config.dart' show ScanType, ScanPhase;
import 'scan_state_manager.dart';
import '../../models/gallery/local_image_record.dart' show MetadataStatus;

/// 扫描结果
///
/// 支持可变和不可变两种使用方式：
/// - 扫描过程中使用可变字段累积统计
/// - 返回最终结果时使用 const 构造创建不可变实例
class ScanResult {
  /// 扫描的文件总数（仅在可变模式下可修改）
  final int filesScanned;

  /// 新增的文件数
  final int filesAdded;

  /// 更新的文件数
  final int filesUpdated;

  /// 删除的文件数
  final int filesDeleted;

  /// 跳过的文件数
  final int filesSkipped;

  /// 扫描耗时
  final Duration duration;

  /// 错误信息列表
  final List<String> errors;

  /// 总文件数（用于结果展示）
  int get totalFiles => filesScanned;

  /// 失败的文件数（别名为 errors.length）
  int get failedFiles => errors.length;

  factory ScanResult({
    int filesScanned = 0,
    int filesAdded = 0,
    int filesUpdated = 0,
    int filesDeleted = 0,
    int filesSkipped = 0,
    Duration duration = Duration.zero,
    List<String> errors = const [],
    // 兼容旧版本的命名参数
    int? totalFiles,
    int? newFiles,
    int? updatedFiles,
    int? failedFiles,
  }) {
    // 优先使用旧版参数名（如果提供），否则使用新版
    final effectiveScanned = totalFiles ?? filesScanned;
    final effectiveAdded = newFiles ?? filesAdded;
    final effectiveUpdated = updatedFiles ?? filesUpdated;
    // 优先使用传入的 errors，如果为空且提供了 failedFiles，则创建占位列表
    final List<String> effectiveErrors;
    if (errors.isNotEmpty) {
      effectiveErrors = errors;
    } else if (failedFiles != null && failedFiles > 0) {
      effectiveErrors = List<String>.filled(failedFiles, '');
    } else {
      effectiveErrors = const <String>[];
    }

    return ScanResult._internal(
      filesScanned: effectiveScanned,
      filesAdded: effectiveAdded,
      filesUpdated: effectiveUpdated,
      filesDeleted: filesDeleted,
      filesSkipped: filesSkipped,
      duration: duration,
      errors: effectiveErrors,
    );
  }

  const ScanResult._internal({
    this.filesScanned = 0,
    this.filesAdded = 0,
    this.filesUpdated = 0,
    this.filesDeleted = 0,
    this.filesSkipped = 0,
    this.duration = Duration.zero,
    this.errors = const [],
  });

  /// 创建可变构建器（用于扫描过程中）
  ScanResultBuilder toBuilder() => ScanResultBuilder(this);

  @override
  String toString() =>
      'ScanResult(scanned: $filesScanned, added: $filesAdded, updated: $filesUpdated, '
      'skipped: $filesSkipped, deleted: $filesDeleted, duration: $duration, '
      'errors: ${errors.length})';
}

/// 扫描结果构建器（可变）
///
/// 用于扫描过程中累积统计信息
class ScanResultBuilder {
  int filesScanned = 0;
  int filesAdded = 0;
  int filesUpdated = 0;
  int filesDeleted = 0;
  int filesSkipped = 0;
  Duration duration = Duration.zero;
  List<String> errors = [];

  ScanResultBuilder([ScanResult? initial]) {
    if (initial != null) {
      filesScanned = initial.filesScanned;
      filesAdded = initial.filesAdded;
      filesUpdated = initial.filesUpdated;
      filesDeleted = initial.filesDeleted;
      filesSkipped = initial.filesSkipped;
      duration = initial.duration;
      errors = List.from(initial.errors);
    }
  }

  /// 构建最终的不可变 ScanResult
  ScanResult build() => ScanResult(
        filesScanned: filesScanned,
        filesAdded: filesAdded,
        filesUpdated: filesUpdated,
        filesDeleted: filesDeleted,
        filesSkipped: filesSkipped,
        duration: duration,
        errors: List.unmodifiable(List.from(errors)),
      );
}

typedef ScanProgressCallback = void Function({
  required int processed,
  required int total,
  String? currentFile,
  required String phase,
  int? filesSkipped, // 跳过的文件数
  int? confirmed, // 已确认（未变化）的文件数
});

class _ParseResult {
  final List<_ParseItem> results;
  final List<String> errors;

  _ParseResult(this.results, this.errors);
}

class _ParseItem {
  final String path;
  final NaiImageMetadata? metadata;
  final int? width;
  final int? height;
  final int fileSize;
  final DateTime modifiedAt;

  _ParseItem({
    required this.path,
    this.metadata,
    this.width,
    this.height,
    required this.fileSize,
    required this.modifiedAt,
  });
}

/// 画廊扫描服务
class GalleryScanService {
  final GalleryDataSource _dataSource;
  final ScanStateManager _stateManager = ScanStateManager.instance;

  static const int _batchSize = 20; // 优化：增加批次大小，减少 isolate 启动开销
  static const int _batchYieldInterval = 100; // 每 100 个文件让出一次时间片

  /// 扫描状态标志，防止并发扫描
  bool _scanning = false;

  /// 开始扫描，如果已有扫描在进行中则返回false
  bool startScan() {
    if (_scanning) {
      AppLogger.w('Scan already in progress, skipping', 'GalleryScanService');
      return false;
    }
    _scanning = true;
    return true;
  }

  /// 结束扫描，释放扫描状态
  void _endScan() {
    _scanning = false;
  }

  GalleryScanService({required GalleryDataSource dataSource})
      : _dataSource = dataSource;

  static GalleryScanService? _instance;
  static GalleryScanService get instance {
    _instance ??= GalleryScanService(dataSource: GalleryDataSource());
    return _instance!;
  }

  /// 清除所有缓存
  ///
  /// 用于手动刷新或重置扫描状态
  void clearCache() {
    AppLogger.i('GalleryScanService cache cleared', 'GalleryScanService');
  }

  /// 处理指定文件列表（批量处理）
  Future<ScanResult> processFiles(
    List<File> files, {
    ScanProgressCallback? onProgress,
  }) async {
    if (files.isEmpty) {
      return ScanResult();
    }

    final result = ScanResultBuilder();
    await _processFilesWithIsolate(
      files,
      result,
      isFullScan: false,
      onProgress: onProgress,
    );

    AppLogger.d(
      'Processed ${files.length} files: ${result.filesAdded} added, ${result.filesUpdated} updated',
      'GalleryScanService',
    );

    // 通知完成
    onProgress?.call(
      processed: files.length,
      total: files.length,
      currentFile: '',
      phase: 'completed',
    );

    return result.build();
  }

  /// 修复数据一致性
  ///
  /// 检查数据库中所有未删除的记录，如果文件不存在则标记为已删除
  Future<ScanResult> fixDataConsistency({
    ScanProgressCallback? onProgress,
  }) async {
    if (!startScan()) {
      return ScanResult(errors: ['Another scan is already in progress']);
    }

    // 启动 ScanStateManager 扫描
    _stateManager.startScan(
      type: ScanType.consistencyFix,
      rootPath: '',
      total: 0,
    );

    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('开始修复数据一致性', 'GalleryScanService');

    try {
      final allImages = await _dataSource.getAllImages();
      result.filesScanned = allImages.length;

      // 更新总数
      _stateManager.updateProgress(
        processed: 0,
        total: allImages.length,
        phase: ScanPhase.scanning,
      );

      final orphanedPaths = <String>[];
      var processedCount = 0;

      for (final image in allImages) {
        if (image.isDeleted) {
          processedCount++;
          continue;
        }

        final file = File(image.filePath);
        final exists = await file.exists();
        if (!exists) {
          orphanedPaths.add(image.filePath);
        }

        processedCount++;
        if (processedCount % 100 == 0) {
          onProgress?.call(
            processed: processedCount,
            total: allImages.length,
            phase: 'checking',
          );
          _stateManager.updateProgress(
            processed: processedCount,
            total: allImages.length,
            phase: ScanPhase.scanning,
          );
        }
      }

      if (orphanedPaths.isNotEmpty) {
        await _dataSource.batchMarkAsDeleted(orphanedPaths);
        result.filesDeleted = orphanedPaths.length;
        AppLogger.i(
          '标记 ${orphanedPaths.length} 个失效记录为已删除',
          'GalleryScanService',
        );
      } else {
        AppLogger.i('数据一致性良好，无需修复', 'GalleryScanService');
      }

      onProgress?.call(
        processed: allImages.length,
        total: allImages.length,
        phase: 'completed',
      );
      _stateManager.completeScan();
    } catch (e, stack) {
      AppLogger.e('修复数据一致性失败', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
      _stateManager.errorScan(e.toString());
    } finally {
      _endScan();
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    AppLogger.i('数据一致性修复完成: $result', 'GalleryScanService');
    return result.build();
  }

  /// 标记文件为已删除
  Future<void> markAsDeleted(List<String> paths) async {
    if (paths.isEmpty) return;
    await _dataSource.batchMarkAsDeleted(paths);
  }

  Future<void> _processFilesWithIsolate(
    List<File> files,
    ScanResultBuilder result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    int processedCount = 0;

    // 初始化批量元数据服务（只初始化一次）
    await ImageMetadataBatchService.instance.initialize();

    for (var i = 0; i < files.length; i += _batchSize) {
      final batchStopwatch = Stopwatch()..start();
      final batch = files.skip(i).take(_batchSize).toList();

      // 关键优化：文件读取+元数据解析 全部在 isolate 中进行
      final isolateStopwatch = Stopwatch()..start();
      final parseResult = await _processBatchInIsolate(batch);
      isolateStopwatch.stop();

      if (parseResult.results.isEmpty) {
        result.errors.addAll(parseResult.errors);
        continue;
      }

      // 数据库写入仍然在主线程，但使用批量事务
      final writeStopwatch = Stopwatch()..start();
      await _writeBatchToDatabase(
        parseResult.results,
        result,
        isFullScan: isFullScan,
      );
      writeStopwatch.stop();

      result.errors.addAll(parseResult.errors);
      processedCount += batch.length;

      // 优化：每5个批次或最后一批才更新进度，减少UI刷新
      if (i % (_batchSize * 5) == 0 || i + _batchSize >= files.length) {
        onProgress?.call(
          processed: processedCount,
          total: files.length,
          currentFile: batch.last.path,
          phase: 'indexing',
        );
      }

      batchStopwatch.stop();
      if (batchStopwatch.elapsedMilliseconds > 1000) {
        AppLogger.w(
          '[PERF] Slow batch: ${batchStopwatch.elapsedMilliseconds}ms '
              '(isolate: ${isolateStopwatch.elapsedMilliseconds}ms, write: ${writeStopwatch.elapsedMilliseconds}ms) '
              'for ${batch.length} files',
          'GalleryScanService',
        );
      }

      // 每 _batchYieldInterval 个文件让出时间片
      if (processedCount % _batchYieldInterval == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    totalStopwatch.stop();
    AppLogger.i(
      '[PERF] _processFilesWithIsolate total: ${totalStopwatch.elapsedMilliseconds}ms for ${files.length} files',
      'GalleryScanService',
    );
  }

  /// 在 isolate 中处理整个批次（流式读取+解析）
  Future<_ParseResult> _processBatchInIsolate(List<File> batch) async {
    return await Isolate.run(() async {
      final results = <_ParseItem>[];
      final errors = <String>[];

      for (final file in batch) {
        try {
          final path = file.path;

          // 流式读取：只读前 200KB（元数据通常在前面）
          final bytes =
              await GalleryScanService._readFileHead(file, 200 * 1024);
          if (bytes.isEmpty) {
            errors.add('$path: Failed to read file');
            continue;
          }

          NaiImageMetadata? metadata;
          int? width;
          int? height;

          // 只解析 PNG 的元数据
          if (p.extension(path).toLowerCase() == '.png') {
            metadata = GalleryScanService._extractMetadataSync(bytes);
            if (metadata != null) {
              width = metadata.width;
              height = metadata.height;
            }
          }

          // 获取文件大小和修改时间
          final stat = await file.stat();

          results.add(
            _ParseItem(
              path: path,
              metadata: metadata,
              width: width,
              height: height,
              fileSize: stat.size,
              modifiedAt: stat.modified,
            ),
          );
        } catch (e) {
          errors.add('${file.path}: $e');
        }
      }

      return _ParseResult(results, errors);
    });
  }

  /// 流式读取文件头部
  static Future<Uint8List> _readFileHead(File file, int maxBytes) async {
    final raf = await file.open();
    try {
      final length = await raf.length();
      final toRead = length < maxBytes ? length : maxBytes;
      return await raf.read(toRead);
    } finally {
      await raf.close();
    }
  }

  /// 同步提取元数据（用于 isolate 中）
  static NaiImageMetadata? _extractMetadataSync(Uint8List bytes) {
    try {
      // 快速检查 PNG 文件头
      if (bytes.length < 8 ||
          bytes[0] != 0x89 ||
          bytes[1] != 0x50 || // 'P'
          bytes[2] != 0x4E || // 'N'
          bytes[3] != 0x47 || // 'G'
          bytes[4] != 0x0D ||
          bytes[5] != 0x0A ||
          bytes[6] != 0x1A ||
          bytes[7] != 0x0A) {
        return null;
      }

      // 解析 chunks
      final chunks = png_extract.extractChunks(bytes);

      // 只检查前 10 个 chunks
      final maxChunks = chunks.length > 10 ? 10 : chunks.length;
      for (var i = 0; i < maxChunks; i++) {
        final chunk = chunks[i];
        final name = chunk['name'] as String?;
        if (name != 'tEXt') continue;

        final data = chunk['data'] as Uint8List?;
        if (data == null) continue;

        // 解析 tEXt chunk
        final nullIndex = data.indexOf(0);
        if (nullIndex < 0 || nullIndex + 1 >= data.length) continue;

        final keyword = latin1.decode(data.sublist(0, nullIndex));
        if (!{'Comment', 'parameters'}.contains(keyword)) continue;

        final textData = latin1.decode(data.sublist(nullIndex + 1));

        // 快速检查 NAI 特征
        if (!textData.contains('prompt') && !textData.contains('sampler')) {
          continue;
        }

        // 解析 JSON
        try {
          final json = jsonDecode(textData) as Map<String, dynamic>;

          // 格式1: 直接格式 - prompt在顶层
          if (json.containsKey('prompt') || json.containsKey('comment')) {
            return NaiImageMetadata.fromNaiComment(json, rawJson: textData);
          }

          // 格式2: PNG标准格式 - Description/Software/Source/Comment
          // Comment字段包含实际元数据（JSON字符串）
          if (json.containsKey('Comment')) {
            final comment = json['Comment'];
            if (comment is String) {
              try {
                final commentJson = jsonDecode(comment) as Map<String, dynamic>;
                if (commentJson.containsKey('prompt') ||
                    commentJson.containsKey('uc')) {
                  return NaiImageMetadata.fromNaiComment(
                    commentJson,
                    rawJson: textData,
                  );
                }
              } catch (_) {
                // Comment不是有效的JSON，忽略
              }
            } else if (comment is Map<String, dynamic>) {
              if (comment.containsKey('prompt') || comment.containsKey('uc')) {
                return NaiImageMetadata.fromNaiComment(
                  comment,
                  rawJson: textData,
                );
              }
            }
          }
        } catch (_) {
          continue;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 批量写入数据库
  Future<void> _writeBatchToDatabase(
    List<_ParseItem> items,
    ScanResultBuilder result, {
    required bool isFullScan,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 使用路径到ID的缓存
    final pathToIdCache = <String, int?>{};

    for (final item in items) {
      try {
        final path = item.path;
        final file = File(path);
        final stat = await file.stat();
        final fileName = p.basename(path);
        final width = item.width;
        final height = item.height;
        final metadata = item.metadata;

        final aspectRatio = (width != null && height != null && height > 0)
            ? width / height
            : null;

        // 查询现有记录
        int? existingId = pathToIdCache[path];
        if (existingId == null && !pathToIdCache.containsKey(path)) {
          existingId = await _dataSource.getImageIdByPath(path);
          pathToIdCache[path] = existingId;
        }

        // 确定元数据状态
        final metadataStatus = metadata != null && metadata.hasData
            ? MetadataStatus.success
            : MetadataStatus.none;

        final imageId = await _dataSource.upsertImage(
          filePath: path,
          fileName: fileName,
          fileSize: stat.size,
          width: width,
          height: height,
          aspectRatio: aspectRatio,
          createdAt: stat.modified,
          modifiedAt: stat.modified,
          resolutionKey:
              width != null && height != null ? '${width}x$height' : null,
          metadataStatus: metadataStatus,
        );

        if (metadata != null && metadata.hasData) {
          await _dataSource.upsertMetadata(imageId, metadata);
        }

        // 缓存元数据
        if (metadata != null && metadata.hasData) {
          ImageMetadataService().cacheMetadata(path, metadata);
        }

        // 更新统计
        if (isFullScan) {
          result.filesAdded++;
        } else {
          if (existingId != null) {
            result.filesUpdated++;
          } else {
            result.filesAdded++;
          }
        }
      } catch (e) {
        result.errors.add('${item.path}: $e');
      }
    }

    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 500) {
      AppLogger.w(
        '[PERF] Slow batch database write: ${stopwatch.elapsedMilliseconds}ms for ${items.length} files',
        'GalleryScanService',
      );
    }
  }

}
