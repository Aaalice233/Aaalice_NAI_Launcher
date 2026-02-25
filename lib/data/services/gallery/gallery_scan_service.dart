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

  static const List<String> _supportedExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
  ];
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

  /// 检测需要处理的文件数量
  Future<(int, int)> detectFilesNeedProcessing(Directory rootDir) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.i('[PERF] detectFilesNeedProcessing START', 'GalleryScanService');

    final existingRecords = await _dataSource.getAllImages();
    final existingMap = {
      for (var img in existingRecords)
        if (!img.isDeleted && img.id != null)
          img.filePath: (
            img.fileSize,
            img.modifiedAt.millisecondsSinceEpoch,
            img.id!,
          ),
    };

    int totalFiles = 0;
    int needProcessing = 0;

    final scanStopwatch = Stopwatch()..start();
    await for (final file in _scanDirectory(rootDir)) {
      totalFiles++;
      final path = file.path;
      final existing = existingMap[path];

      if (existing == null) {
        needProcessing++;
      } else {
        final stat = await file.stat();
        final (existingSize, existingMtime, _) = existing;

        if (stat.size != existingSize ||
            stat.modified.millisecondsSinceEpoch != existingMtime) {
          needProcessing++;
        }
      }
    }
    scanStopwatch.stop();
    AppLogger.i(
      '[PERF] Directory scan: ${scanStopwatch.elapsedMilliseconds}ms, files: $totalFiles',
      'GalleryScanService',
    );

    stopwatch.stop();
    AppLogger.i(
      '[PERF] detectFilesNeedProcessing END: ${stopwatch.elapsedMilliseconds}ms',
      'GalleryScanService',
    );
    return (totalFiles, needProcessing);
  }

  /// 全量扫描
  Future<ScanResult> fullScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
  }) async {
    if (!startScan()) {
      return ScanResult(errors: ['Another scan is already in progress']);
    }

    // 启动 ScanStateManager 扫描
    _stateManager.startScan(
      type: ScanType.full,
      rootPath: rootDir.path,
      total: 0, // 将在收集文件后更新
    );

    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('Full scan started', 'GalleryScanService');

    try {
      final files = await _collectImageFiles(rootDir);
      result.filesScanned = files.length;

      // 更新总数
      _stateManager.updateProgress(
        processed: 0,
        total: files.length,
        phase: ScanPhase.scanning,
      );

      await _processFilesWithIsolate(
        files,
        result,
        isFullScan: true,
        onProgress: onProgress,
      );

      _stateManager.completeScan();
    } catch (e, stack) {
      AppLogger.e('Full scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
      _stateManager.errorScan(e.toString());
    } finally {
      _endScan();
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(
      processed: result.filesScanned,
      total: result.filesScanned,
      phase: 'completed',
    );
    AppLogger.i('Full scan completed: $result', 'GalleryScanService');
    return result.build();
  }

  /// 查漏补缺：为缺少元数据的图片重新解析
  Future<ScanResult> fillMissingMetadata({
    ScanProgressCallback? onProgress,
    int batchSize = 100,
  }) async {
    if (!startScan()) {
      return ScanResult(errors: ['Another scan is already in progress']);
    }

    // 启动 ScanStateManager 扫描
    _stateManager.startScan(
      type: ScanType.fillMetadata,
      rootPath: '',
      total: 0,
    );

    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('开始查漏补缺：查找缺少元数据的图片', 'GalleryScanService');

    try {
      final allImages = await _dataSource.getAllImages();
      result.filesScanned = allImages.length;

      final filesNeedMetadata = <File>[];
      final imageIdMap = <String, int>{};

      for (final image in allImages) {
        if (image.isDeleted) continue;
        if (p.extension(image.filePath).toLowerCase() != '.png') continue;
        if (image.id == null) continue;

        final metadata = await _dataSource.getMetadataByImageId(image.id!);
        if (metadata == null || metadata.prompt.isEmpty) {
          final file = File(image.filePath);
          if (await file.exists()) {
            filesNeedMetadata.add(file);
            imageIdMap[image.filePath] = image.id!;
          }
        }
      }

      AppLogger.i(
        '发现 ${filesNeedMetadata.length} 张图片需要补充元数据（共 ${allImages.length} 张）',
        'GalleryScanService',
      );

      if (filesNeedMetadata.isEmpty) {
        AppLogger.i('所有图片已有元数据，无需补充', 'GalleryScanService');
        _stateManager.completeScan();
        return result.build();
      }

      // 更新总数
      _stateManager.updateProgress(
        processed: 0,
        total: filesNeedMetadata.length,
        phase: ScanPhase.scanning,
      );

      await _processMetadataBatchesWithIsolate(
        filesNeedMetadata,
        imageIdMap,
        result,
        batchSize: batchSize,
        onProgress: onProgress,
      );

      _stateManager.completeScan();

      AppLogger.i(
        '查漏补缺完成: ${result.filesUpdated} 张图片已更新元数据',
        'GalleryScanService',
      );
    } catch (e, stack) {
      AppLogger.e('查漏补缺失败', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
      _stateManager.errorScan(e.toString());
    } finally {
      _endScan();
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    return result.build();
  }

  Future<void> _processMetadataBatchesWithIsolate(
    List<File> files,
    Map<String, int> imageIdMap,
    ScanResultBuilder result, {
    required int batchSize,
    ScanProgressCallback? onProgress,
  }) async {
    int processedCount = 0;
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize).toList();
      final batchNum = (i ~/ batchSize) + 1;
      final totalBatches = ((files.length - 1) ~/ batchSize) + 1;

      AppLogger.d(
        '处理批次 $batchNum/$totalBatches: ${batch.length} 张图片',
        'GalleryScanService',
      );
      onProgress?.call(
        processed: i,
        total: totalFiles,
        phase: 'filling_metadata_batch_$batchNum',
      );

      final paths = <String>[];
      final bytesList = <Uint8List>[];

      for (final file in batch) {
        try {
          final bytes = await file.readAsBytes();
          paths.add(file.path);
          bytesList.add(bytes);
        } catch (e) {
          result.errors.add('${file.path}: $e');
        }
      }

      if (paths.isEmpty) continue;

      final parseResult = await _parseInIsolate(paths, bytesList);

      for (final res in parseResult.results) {
        final imageId = imageIdMap[res.path];

        if (imageId != null && res.metadata != null && res.metadata!.hasData) {
          try {
            await _dataSource.upsertMetadata(imageId, res.metadata!);
            result.filesUpdated++;
            ImageMetadataService().cacheMetadata(res.path, res.metadata!);
          } catch (e) {
            result.errors.add('${res.path}: $e');
          }
        }
      }

      result.errors.addAll(parseResult.errors);
      processedCount += batch.length;

      onProgress?.call(
        processed: processedCount,
        total: totalFiles,
        currentFile: batch.last.path,
        phase: 'filling_metadata',
      );

      // 每批次让出时间片
      if (i % _batchYieldInterval == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    onProgress?.call(
      processed: totalFiles,
      total: totalFiles,
      phase: 'completed',
    );
  }

  /// 处理指定文件
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

  /// 批量解析文件元数据
  ///
  /// 优化：使用 ImageMetadataBatchService 进行流式解析
  Future<_ParseResult> _parseInIsolate(
    List<String> paths,
    List<Uint8List> bytesList,
  ) async {
    final totalStopwatch = Stopwatch()..start();

    try {
      // 分离 PNG 文件和非 PNG 文件
      final pngPaths = <String>[];
      final nonPngItems = <_ParseItem>[];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        // bytes = bytesList[i]; // 保留引用用于未来扩展

        if (p.extension(path).toLowerCase() == '.png') {
          pngPaths.add(path);
        } else {
          // 非 PNG 文件：没有元数据，获取文件信息
          final file = File(path);
          final stat = await file.stat();
          nonPngItems.add(
            _ParseItem(
              path: path,
              metadata: null,
              width: null,
              height: null,
              fileSize: stat.size,
              modifiedAt: stat.modified,
            ),
          );
        }
      }

      // 使用批量服务解析 PNG 元数据（流式读取，不占用主线程）
      final metadataResults = <String, NaiImageMetadata?>{};
      if (pngPaths.isNotEmpty) {
        final batchStopwatch = Stopwatch()..start();
        final results = await ImageMetadataBatchService.instance.parseBatch(
          pngPaths,
          maxBytesPerFile: 100 * 1024, // 只读前 100KB
        );
        batchStopwatch.stop();

        for (final (path, metadata, error) in results) {
          if (error != null) {
            AppLogger.w(
              '[PERF-ISOLATE] Metadata parse error for $path: $error',
              'GalleryScanService',
            );
          }
          metadataResults[path] = metadata;
        }

        AppLogger.d(
          '[PERF-ISOLATE] Batch metadata parsed: ${results.length} files in ${batchStopwatch.elapsedMilliseconds}ms',
          'GalleryScanService',
        );
      }

      // 组合结果
      final items = <_ParseItem>[];
      items.addAll(nonPngItems);

      for (final path in pngPaths) {
        final metadata = metadataResults[path];
        // bytes = bytesList[paths.indexOf(path)]; // 保留引用用于未来扩展
        final file = File(path);
        final stat = await file.stat();

        items.add(
          _ParseItem(
            path: path,
            metadata: metadata,
            width: metadata?.width,
            height: metadata?.height,
            fileSize: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      }

      totalStopwatch.stop();
      if (totalStopwatch.elapsedMilliseconds > 500) {
        AppLogger.w(
          '[PERF-ISOLATE] Slow batch: ${totalStopwatch.elapsedMilliseconds}ms for ${paths.length} files',
          'GalleryScanService',
        );
      }

      return _ParseResult(items, []);
    } catch (e, stack) {
      AppLogger.e(
        '[PERF-ISOLATE] Batch parse error',
        e,
        stack,
        'GalleryScanService',
      );
      return _ParseResult([], [e.toString()]);
    }
  }

  Future<List<File>> _collectImageFiles(Directory dir) async {
    final files = <File>[];
    await for (final file in _scanDirectory(dir)) {
      files.add(file);
    }
    return files;
  }

  Stream<File> _scanDirectory(Directory dir) async* {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        // 【修复】排除.thumbs目录中的文件，防止缩略图递归生成
        if (entity.path.contains(
              '${Platform.pathSeparator}.thumbs${Platform.pathSeparator}',
            ) ||
            entity.path.contains('.thumb.')) {
          continue;
        }

        final ext = p.extension(entity.path).toLowerCase();
        if (_supportedExtensions.contains(ext)) {
          yield entity;
        }
      }
    }
  }

  /// 提取元数据（在 isolate 中执行）
  /// 优化：只读取文件前部（元数据通常在前面）
  Future<NaiImageMetadata?> _extractMetadataInIsolate(File file) async {
    try {
      final ext = p.extension(file.path).toLowerCase();
      if (ext != '.png') return null;

      // 只读取前200KB（元数据通常在文件前部）
      final bytes = await _readFileHead(file, 200 * 1024);
      // 然后在 isolate 中解析元数据
      return await Isolate.run(() => _extractMetadataSync(bytes));
    } catch (e) {
      AppLogger.w(
        '[SCAN] Failed to extract metadata for ${file.path}: $e',
        'GalleryScanService',
      );
      return null;
    }
  }

  /// 真正的流式增量扫描管道
  ///
  /// 特点：
  /// - 使用 mtime + size 快速对比文件变化
  /// - 批量让出时间片（每 100 个文件）
  /// - 支持取消（通过 startScan/endScan 机制）
  Future<ScanResult> incrementalScanPipeline(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
  }) async {
    if (!startScan()) {
      AppLogger.w(
        '[SCAN] startScan failed, another scan in progress',
        'GalleryScanService',
      );
      return ScanResult(errors: ['Another scan is already in progress']);
    }

    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i(
      '[SCAN] === Incremental scan pipeline started ===',
      'GalleryScanService',
    );

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'initializing');
      AppLogger.d('[SCAN] Phase: initializing', 'GalleryScanService');

      // 预加载现有文件记录（使用 path -> (size, mtime, id, metadataStatus, lastScannedAt) 映射）
      final existingRecords = await _dataSource.getAllImages();
      final existingMap = {
        for (var img in existingRecords)
          if (!img.isDeleted && img.id != null)
            img.filePath: (
              img.fileSize,
              img.modifiedAt.millisecondsSinceEpoch,
              img.id!,
              img.metadataStatus,
              img.lastScannedAt,
            ),
      };
      AppLogger.d(
        '[SCAN] Loaded ${existingRecords.length} existing records from database',
        'GalleryScanService',
      );

      // 扫描目录收集文件并计算需要处理的文件数
      final files = <File>[];
      var filesNeedProcessing = 0;
      await for (final file in _scanDirectory(rootDir)) {
        files.add(file);
        
        // 快速检查是否需要处理
        final path = file.path;
        final existing = existingMap[path];
        if (existing == null) {
          filesNeedProcessing++;
        } else {
          final (existingSize, existingMtime, _, metadataStatus, lastScannedAt) = existing;
          final stat = await file.stat();
          if (stat.size != existingSize ||
              stat.modified.millisecondsSinceEpoch != existingMtime ||
              metadataStatus == MetadataStatus.none ||
              lastScannedAt == null) {
            filesNeedProcessing++;
          }
        }
      }
      result.filesScanned = files.length;
      AppLogger.i(
        '[SCAN] Found ${files.length} files, $filesNeedProcessing need processing',
        'GalleryScanService',
      );
      // 启动 ScanStateManager 扫描
      final stateManagerStarted = _stateManager.startScan(
        type: ScanType.incremental,
        rootPath: rootDir.path,
        total: filesNeedProcessing,
      );
      if (!stateManagerStarted) {
        AppLogger.w(
          '[SCAN] _stateManager.startScan failed, another scan may be in progress',
          'GalleryScanService',
        );
        _endScan();
        return ScanResult(errors: ['Another scan is already in progress']);
      }
      AppLogger.i(
        '[SCAN] _stateManager.startScan success, total: ${files.length}',
        'GalleryScanService',
      );

      onProgress?.call(processed: 0, total: filesNeedProcessing, phase: 'scanning');

      // 检查点计时器
      var lastCheckpoint = DateTime.now();
      var processedCount = 0;
      var updateCount = 0;
      var confirmedCount = 0; // 已确认（未变化）的文件数

      AppLogger.i(
        '[SCAN] Starting file processing loop, files: ${files.length}',
        'GalleryScanService',
      );

      // 逐文件处理管道
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final path = file.path;

        // 每50个文件记录一次日志
        if (i % 50 == 0) {
          AppLogger.d(
            '[SCAN] Processing file $i/${files.length}: ${p.basename(path)}',
            'GalleryScanService',
          );
        }

        try {
          // 获取文件信息
          final stat = await file.stat();
          final existing = existingMap[path];

          // 检查文件是否需要处理（使用 mtime + size + metadataStatus + lastScannedAt）
          final bool needsUpdate;
          if (existing == null) {
            // 新文件
            needsUpdate = true;
          } else {
            final (existingSize, existingMtime, _, metadataStatus, lastScannedAt) = existing;
            if (stat.size != existingSize ||
                stat.modified.millisecondsSinceEpoch != existingMtime) {
              // 文件已变化
              needsUpdate = true;
            } else if (metadataStatus == MetadataStatus.none) {
              // 文件未变化，但缺少元数据
              needsUpdate = true;
              AppLogger.d('[SCAN] File unchanged but missing metadata: $path', 'GalleryScanService');
            } else if (lastScannedAt == null) {
              // 文件从未被扫描过
              needsUpdate = true;
              AppLogger.d('[SCAN] File never scanned: $path', 'GalleryScanService');
            } else {
              // 文件未变化、有元数据、且已扫描过
              needsUpdate = false;
              result.filesSkipped++;
              confirmedCount++;
            }
          }

          if (!needsUpdate) {
            processedCount++;
            continue;
          }

          // 需要处理：提取元数据并写入数据库
          final metadata = await _extractMetadataInIsolate(file);
          final isNewFile = existing == null;

          await _writeSingleFileToDatabase(
            file,
            metadata,
            result,
            isNewFile: isNewFile,
          );

          processedCount++;
          updateCount++;

          // 更新进度（包含 confirmed 计数）
          onProgress?.call(
            processed: processedCount,
            total: filesNeedProcessing,
            currentFile: path,
            phase: 'processing',
            filesSkipped: result.filesSkipped,
            confirmed: confirmedCount,
          );

          // 更新 ScanStateManager 状态（供 UI 监听）
          _stateManager.updateProgress(
            processed: processedCount,
            total: filesNeedProcessing,
            currentFile: p.basename(path),
            phase: ScanPhase.indexing,
          );

          // 每10秒保存检查点
          if (DateTime.now().difference(lastCheckpoint).inSeconds >= 10) {
            AppLogger.i(
            '[SCAN] Checkpoint: $processedCount/$filesNeedProcessing processed, '
                  '$updateCount updated, $confirmedCount confirmed',
              'GalleryScanService',
            );
            lastCheckpoint = DateTime.now();
          }

          // 每 100 个文件让出一次时间片
          if (processedCount % _batchYieldInterval == 0) {
            await Future.delayed(Duration.zero);
          }
        } catch (e) {
          result.errors.add('$path: $e');
          processedCount++; // 错误时也要递增计数器，确保进度准确
          AppLogger.w(
            '[SCAN] Error processing file $path: $e',
            'GalleryScanService',
          );
        }
      }

      AppLogger.i(
        '[SCAN] Processing loop completed. Total: $processedCount, '
            'Updated: $updateCount, Confirmed: $confirmedCount, '
            'Skipped: ${result.filesSkipped}',
        'GalleryScanService',
      );

      // 处理已删除的文件
      final currentPaths = files.map((f) => f.path).toSet();
      final existingPaths = existingMap.keys.toSet();
      final deletedPaths = existingPaths.difference(currentPaths);
      if (deletedPaths.isNotEmpty) {
        await _dataSource.batchMarkAsDeleted(deletedPaths.toList());
        result.filesDeleted = deletedPaths.length;
        AppLogger.i(
          '[SCAN] Marked ${deletedPaths.length} files as deleted',
          'GalleryScanService',
        );
      }

      onProgress?.call(
        processed: files.length,
        total: files.length,
        phase: 'completed',
        filesSkipped: result.filesSkipped,
        confirmed: confirmedCount,
      );
      _stateManager.completeScan();
      AppLogger.i(
        '[SCAN] === Scan completed: $result ===',
        'GalleryScanService',
      );
    } catch (e, stack) {
      AppLogger.e('[SCAN] Pipeline failed', e, stack, 'GalleryScanService');
      _stateManager.errorScan(e.toString());
      result.errors.add(e.toString());
    } finally {
      stopwatch.stop();
      result.duration = stopwatch.elapsed;
      _endScan();
    }

    return result.build();
  }

  /// 写入单个文件到数据库
  Future<void> _writeSingleFileToDatabase(
    File file,
    NaiImageMetadata? metadata,
    ScanResultBuilder result, {
    required bool isNewFile,
  }) async {
    try {
      final path = file.path;
      final stat = await file.stat();
      final fileName = p.basename(path);

      final width = metadata?.width;
      final height = metadata?.height;
      final aspectRatio = (width != null && height != null && height > 0)
          ? width / height
          : null;

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
        lastScannedAt: DateTime.now(),
      );

      if (metadata != null && metadata.hasData) {
        await _dataSource.upsertMetadata(imageId, metadata);
      }

      // 缓存元数据
      if (metadata != null && metadata.hasData) {
        ImageMetadataService().cacheMetadata(path, metadata);
      }

      // 更新统计
      if (isNewFile) {
        result.filesAdded++;
      } else {
        result.filesUpdated++;
      }
    } catch (e) {
      result.errors.add('${file.path}: $e');
      rethrow;
    }
  }
}
