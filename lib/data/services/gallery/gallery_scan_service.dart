import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:png_chunks_extract/png_chunks_extract.dart' as png_extract;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../image_metadata_batch_service.dart';
import '../image_metadata_service.dart';

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
    final effectiveErrors = failedFiles != null && failedFiles > 0
        ? List<String>.filled(failedFiles, '')
        : (errors.isEmpty ? const <String>[] : errors);

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
        errors: List.unmodifiable(errors),
      );
}

typedef ScanProgressCallback = void Function({
  required int processed,
  required int total,
  String? currentFile,
  required String phase,
});

enum ScanPriority { high, low }

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
  final String fileHash;
  final int fileSize;
  final DateTime modifiedAt;

  _ParseItem({
    required this.path,
    this.metadata,
    this.width,
    this.height,
    required this.fileHash,
    required this.fileSize,
    required this.modifiedAt,
  });
}

/// 画廊扫描服务
class GalleryScanService {
  final GalleryDataSource _dataSource;

  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
  static const int _batchSize = 20; // 优化：增加批次大小，减少 isolate 启动开销
  static const int _highPriorityDelayMs = 10;
  static const int _lowPriorityDelayMs = 100;

  GalleryScanService({required GalleryDataSource dataSource}) : _dataSource = dataSource;

  static GalleryScanService? _instance;
  static GalleryScanService get instance {
    _instance ??= GalleryScanService(dataSource: GalleryDataSource());
    return _instance!;
  }

  /// 预加载的哈希到ID映射缓存
  Map<String, int>? _hashToIdMap;
  Map<String, int>? _pathToIdMap;
  DateTime? _cacheValidUntil;
  static const _cacheValidityDuration = Duration(minutes: 5);

  /// 预加载所有哈希映射到内存
  ///
  /// 在扫描前调用，大幅减少数据库查询次数
  Future<void> _preloadHashMaps() async {
    try {
      final stopwatch = Stopwatch()..start();
      final allImages = await _dataSource.getAllImages();

      _hashToIdMap = {for (var img in allImages) if (img.fileHash != null && img.id != null) img.fileHash!: img.id!};
      _pathToIdMap = {for (var img in allImages) if (img.id != null) img.filePath: img.id!};
      _cacheValidUntil = DateTime.now().add(_cacheValidityDuration);

      stopwatch.stop();
      AppLogger.i(
        '[PERF] Preloaded ${allImages.length} images into hash maps '
        '(hash: ${_hashToIdMap!.length}, path: ${_pathToIdMap!.length}) in ${stopwatch.elapsedMilliseconds}ms',
        'GalleryScanService',
      );

      // 如果没有预加载到任何数据，记录警告
      if (_hashToIdMap!.isEmpty && _pathToIdMap!.isEmpty) {
        AppLogger.w(
          '[PERF] Hash maps are empty! This may be the first scan or database is empty.',
          'GalleryScanService',
        );
      }
    } catch (e, stack) {
      AppLogger.e('Failed to preload hash maps', e, stack, 'GalleryScanService');
      // 失败时继续，降级为实时查询
      _hashToIdMap = null;
      _pathToIdMap = null;
    }
  }

  /// 从缓存获取图片ID（通过哈希）
  int? _getImageIdFromCacheByHash(String fileHash) {
    if (_hashToIdMap == null || _cacheValidUntil == null || DateTime.now().isAfter(_cacheValidUntil!)) {
      return null;
    }
    return _hashToIdMap![fileHash];
  }

  /// 从缓存获取图片ID（通过路径）
  int? _getImageIdFromCacheByPath(String path) {
    if (_pathToIdMap == null || _cacheValidUntil == null || DateTime.now().isAfter(_cacheValidUntil!)) {
      return null;
    }
    return _pathToIdMap![path];
  }

  /// 更新缓存中的映射
  void _updateCache(String fileHash, String path, int id) {
    _hashToIdMap?[fileHash] = id;
    _pathToIdMap?[path] = id;
  }

  /// 清除所有缓存
  ///
  /// 用于手动刷新或重置扫描状态
  void clearCache() {
    _hashToIdMap = null;
    _pathToIdMap = null;
    _cacheValidUntil = null;
    AppLogger.i('GalleryScanService cache cleared', 'GalleryScanService');
  }

  /// 检测需要处理的文件数量
  Future<(int, int)> detectFilesNeedProcessing(Directory rootDir) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.i('[PERF] detectFilesNeedProcessing START', 'GalleryScanService');

    final existingFiles = await _getAllFileHashes();
    final existingPaths = existingFiles.keys.toSet();

    int totalFiles = 0;
    int needProcessing = 0;
    final filesToCheck = <File>[];

    final scanStopwatch = Stopwatch()..start();
    await for (final file in _scanDirectory(rootDir)) {
      totalFiles++;
      final path = file.path;
      final existingHash = existingFiles[path];

      if (!existingPaths.contains(path)) {
        needProcessing++;
      } else if (existingHash != null) {
        filesToCheck.add(file);
      }
    }
    scanStopwatch.stop();
    AppLogger.i('[PERF] Directory scan: ${scanStopwatch.elapsedMilliseconds}ms, files: $totalFiles', 'GalleryScanService');

    // 批量处理哈希计算
    if (filesToCheck.isNotEmpty) {
      final batchStopwatch = Stopwatch()..start();
      final changedCount = await _checkFilesChangedBatch(filesToCheck, existingFiles);
      needProcessing += changedCount;
      batchStopwatch.stop();
      AppLogger.i('[PERF] Hash check batch: ${batchStopwatch.elapsedMilliseconds}ms, changed: $changedCount', 'GalleryScanService');
    }

    stopwatch.stop();
    AppLogger.i('[PERF] detectFilesNeedProcessing END: ${stopwatch.elapsedMilliseconds}ms', 'GalleryScanService');
    return (totalFiles, needProcessing);
  }

  /// 批量检查文件是否已更改（在 isolate 中计算哈希）
  Future<int> _checkFilesChangedBatch(
    List<File> files,
    Map<String, String> existingFiles,
  ) async {
    var changedCount = 0;
    final totalStopwatch = Stopwatch()..start();

    for (var i = 0; i < files.length; i += _batchSize) {
      final batchStopwatch = Stopwatch()..start();
      final batch = files.skip(i).take(_batchSize).toList();
      AppLogger.d('[PERF] _checkFilesChangedBatch batch ${i ~/ _batchSize + 1}/${(files.length / _batchSize).ceil()}, size: ${batch.length}', 'GalleryScanService');

      // 收集文件数据
      final readStopwatch = Stopwatch()..start();
      final pathBytesList = await Future.wait(
        batch.map((file) async {
          try {
            final bytes = await file.readAsBytes();
            return (file.path, bytes);
          } catch (e) {
            return (file.path, null);
          }
        }),
      );
      readStopwatch.stop();

      // 在 isolate 中批量计算哈希
      final isolateStopwatch = Stopwatch()..start();
      final hashes = await Isolate.run(() {
        final result = <String, String>{};
        for (final (path, bytes) in pathBytesList) {
          if (bytes != null) {
            result[path] = _computeFileHashSync(bytes);
          }
        }
        return result;
      });
      isolateStopwatch.stop();

      // 对比哈希
      for (final entry in hashes.entries) {
        final existingHash = existingFiles[entry.key];
        if (existingHash == null || existingHash != entry.value) {
          changedCount++;
        }
      }

      batchStopwatch.stop();
      if (batchStopwatch.elapsedMilliseconds > 100) {
        AppLogger.w('[PERF] Slow batch: ${batchStopwatch.elapsedMilliseconds}ms (read: ${readStopwatch.elapsedMilliseconds}ms, isolate: ${isolateStopwatch.elapsedMilliseconds}ms)', 'GalleryScanService');
      }

      // 让出时间片
      await Future.delayed(Duration.zero);
    }

    totalStopwatch.stop();
    AppLogger.i('[PERF] _checkFilesChangedBatch total: ${totalStopwatch.elapsedMilliseconds}ms for ${files.length} files', 'GalleryScanService');
    return changedCount;
  }

  /// 快速启动扫描
  Future<ScanResult> quickStartupScan(
    Directory rootDir, {
    int maxFiles = 100,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.high,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('Quick startup scan started (max $maxFiles files)', 'GalleryScanService');

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'checking');
      final existingFiles = await _getAllFileHashes();

      final recentFiles = await _collectRecentFiles(rootDir, maxFiles: maxFiles);
      result.filesScanned = recentFiles.length;

      // 使用批量处理检查文件变化
      final filesToProcess = <File>[];
      final filesToCheck = <File>[];

      for (final file in recentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (existingHash == null) {
          filesToProcess.add(file);
        } else {
          filesToCheck.add(file);
        }
      }

      // 批量检查哈希
      if (filesToCheck.isNotEmpty) {
        final changedFiles = await _getChangedFilesBatch(filesToCheck, existingFiles);
        filesToProcess.addAll(changedFiles);
        result.filesSkipped = filesToCheck.length - changedFiles.length;
      }

      AppLogger.i(
        'Quick scan: ${recentFiles.length} files, ${filesToProcess.length} need processing',
        'GalleryScanService',
      );

      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
          priority: priority,
        );
      }
    } catch (e, stack) {
      AppLogger.e('Quick startup scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    AppLogger.i('Quick startup scan completed: $result', 'GalleryScanService');
    return result.build();
  }

  /// 批量获取已更改的文件列表
  Future<List<File>> _getChangedFilesBatch(
    List<File> files,
    Map<String, String> existingFiles,
  ) async {
    final changedFiles = <File>[];

    for (var i = 0; i < files.length; i += _batchSize) {
      final batch = files.skip(i).take(_batchSize).toList();

      // 收集文件数据
      final pathBytesList = await Future.wait(
        batch.map((file) async {
          try {
            final bytes = await file.readAsBytes();
            return (file, bytes);
          } catch (e) {
            return (file, null);
          }
        }),
      );

      // 在 isolate 中批量计算哈希
      final hashes = await Isolate.run(() {
        final result = <String, String>{};
        for (final (file, bytes) in pathBytesList) {
          if (bytes != null) {
            result[file.path] = _computeFileHashSync(bytes);
          }
        }
        return result;
      });

      // 对比哈希
      for (final (file, _) in pathBytesList) {
        final currentHash = hashes[file.path];
        final existingHash = existingFiles[file.path];
        if (currentHash != null && currentHash != existingHash) {
          changedFiles.add(file);
        }
      }

      // 让出时间片
      await Future.delayed(Duration.zero);
    }

    return changedFiles;
  }

  /// 完整增量扫描
  Future<ScanResult> incrementalScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('Incremental scan started', 'GalleryScanService');

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'checking');

      final existingFiles = await _getAllFileHashes();
      final existingPaths = existingFiles.keys.toSet();

      final currentFiles = <File>[];
      await for (final file in _scanDirectory(rootDir)) {
        currentFiles.add(file);
      }
      result.filesScanned = currentFiles.length;

      // 使用批量处理检查文件变化
      final filesToProcess = <File>[];
      final filesToCheck = <File>[];

      for (final file in currentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (!existingPaths.contains(path)) {
          filesToProcess.add(file);
        } else if (existingHash != null) {
          filesToCheck.add(file);
        }
      }

      // 批量检查哈希
      if (filesToCheck.isNotEmpty) {
        final changedFiles = await _getChangedFilesBatch(filesToCheck, existingFiles);
        filesToProcess.addAll(changedFiles);
        result.filesSkipped = filesToCheck.length - changedFiles.length;
      }

      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
          priority: priority,
        );
      }

      final currentPaths = currentFiles.map((f) => f.path).toSet();
      final deletedPaths = existingPaths.difference(currentPaths);
      if (deletedPaths.isNotEmpty) {
        await _dataSource.batchMarkAsDeleted(deletedPaths.toList());
        result.filesDeleted = deletedPaths.length;
      }
    } catch (e, stack) {
      AppLogger.e('Incremental scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
    AppLogger.i('Incremental scan completed: $result', 'GalleryScanService');
    return result.build();
  }

  /// 全量扫描
  Future<ScanResult> fullScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResultBuilder();

    AppLogger.i('Full scan started', 'GalleryScanService');

    try {
      final files = await _collectImageFiles(rootDir);
      result.filesScanned = files.length;

      await _processFilesSmart(
        files,
        result,
        isFullScan: true,
        onProgress: onProgress,
        priority: priority,
      );
    } catch (e, stack) {
      AppLogger.e('Full scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
    AppLogger.i('Full scan completed: $result', 'GalleryScanService');
    return result.build();
  }

  /// 查漏补缺：为缺少元数据的图片重新解析
  Future<ScanResult> fillMissingMetadata({
    ScanProgressCallback? onProgress,
    int batchSize = 100,
    ScanPriority priority = ScanPriority.low,
  }) async {
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
        return result.build();
      }

      await _processMetadataBatchesWithIsolate(
        filesNeedMetadata,
        imageIdMap,
        result,
        batchSize: batchSize,
        onProgress: onProgress,
        priority: priority,
      );

      AppLogger.i(
        '查漏补缺完成: ${result.filesUpdated} 张图片已更新元数据',
        'GalleryScanService',
      );
    } catch (e, stack) {
      AppLogger.e('查漏补缺失败', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
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
    ScanPriority priority = ScanPriority.low,
  }) async {
    int processedCount = 0;
    final totalFiles = files.length;

    for (var i = 0; i < files.length; i += batchSize) {
      final batch = files.skip(i).take(batchSize).toList();
      final batchNum = (i ~/ batchSize) + 1;
      final totalBatches = ((files.length - 1) ~/ batchSize) + 1;

      AppLogger.d('处理批次 $batchNum/$totalBatches: ${batch.length} 张图片', 'GalleryScanService');
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

      final delayMs = priority == ScanPriority.low ? _lowPriorityDelayMs : _highPriorityDelayMs;
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    onProgress?.call(processed: totalFiles, total: totalFiles, phase: 'completed');
  }

  /// 处理指定文件
  Future<void> processFiles(
    List<File> files, {
    ScanPriority priority = ScanPriority.low,
    ScanProgressCallback? onProgress,
  }) async {
    if (files.isEmpty) return;

    final result = ScanResultBuilder();
    await _processFilesSmart(
      files,
      result,
      isFullScan: false,
      priority: priority,
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
  }

  /// 标记文件为已删除
  Future<void> markAsDeleted(List<String> paths) async {
    if (paths.isEmpty) return;
    await _dataSource.batchMarkAsDeleted(paths);
  }

  Future<Map<String, String>> _getAllFileHashes() async {
    try {
      final images = await _dataSource.getAllImages();
      return {for (var img in images) img.filePath: img.fileHash ?? ''};
    } catch (e, stack) {
      AppLogger.e('Failed to get all file hashes', e, stack, 'GalleryScanService');
      return {};
    }
  }

  Future<void> _processFilesSmart(
    List<File> files,
    ScanResultBuilder result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    // 统一使用 isolate 处理，避免小批量在主线程处理时阻塞 UI
    // 即使是小批量，文件读取和元数据解析也可能是 IO 密集型操作
    AppLogger.d('Processing ${files.length} files with isolate', 'GalleryScanService');
    await _processWithIsolate(
      files,
      result,
      isFullScan: isFullScan,
      onProgress: onProgress,
      priority: priority,
    );
  }

  Future<void> _processWithIsolate(
    List<File> files,
    ScanResultBuilder result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
    ScanPriority priority = ScanPriority.low,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    int processedCount = 0;

    // 预加载哈希映射到内存，大幅减少数据库查询
    await _preloadHashMaps();

    // 初始化批量元数据服务（只初始化一次）
    await ImageMetadataBatchService.instance.initialize();

    for (var i = 0; i < files.length; i += _batchSize) {
      final batchStopwatch = Stopwatch()..start();
      final batch = files.skip(i).take(_batchSize).toList();

      // 关键优化：文件读取+元数据解析+哈希计算 全部在 isolate 中进行
      final isolateStopwatch = Stopwatch()..start();
      final parseResult = await _processBatchInIsolate(batch);
      isolateStopwatch.stop();

      if (parseResult.results.isEmpty) {
        result.errors.addAll(parseResult.errors);
        continue;
      }

      // 数据库写入仍然在主线程，但使用批量事务
      final writeStopwatch = Stopwatch()..start();
      await _writeBatchToDatabase(parseResult.results, result, isFullScan: isFullScan);
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

      // 让出时间片，避免阻塞UI
      await Future.delayed(Duration.zero);

      final delay = priority == ScanPriority.low
          ? const Duration(milliseconds: _lowPriorityDelayMs)
          : Duration.zero;
      await Future.delayed(delay);
    }

    totalStopwatch.stop();
    AppLogger.i('[PERF] _processWithIsolate total: ${totalStopwatch.elapsedMilliseconds}ms for ${files.length} files', 'GalleryScanService');
  }

  /// 在 isolate 中处理整个批次（流式读取+解析+哈希）
  Future<_ParseResult> _processBatchInIsolate(List<File> batch) async {
    return await Isolate.run(() async {
      final results = <_ParseItem>[];
      final errors = <String>[];

      for (final file in batch) {
        try {
          final path = file.path;

          // 流式读取：只读前 200KB（元数据通常在前面）
          final bytes = await _readFileHead(file, 200 * 1024);
          if (bytes.isEmpty) {
            errors.add('$path: Failed to read file');
            continue;
          }

          NaiImageMetadata? metadata;
          int? width;
          int? height;

          // 只解析 PNG 的元数据
          if (p.extension(path).toLowerCase() == '.png') {
            metadata = _extractMetadataSync(bytes);
            if (metadata != null) {
              width = metadata.width;
              height = metadata.height;
            }
          }

          // 计算哈希（使用流式读取的数据）
          final fileHash = _computeFileHashSync(bytes);

          results.add(_ParseItem(
            path: path,
            metadata: metadata,
            width: width,
            height: height,
            fileHash: fileHash,
            fileSize: bytes.length,
            modifiedAt: DateTime.now(),
          ),);
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
        if (!textData.contains('prompt') && !textData.contains('sampler')) continue;

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
                if (commentJson.containsKey('prompt') || commentJson.containsKey('uc')) {
                  return NaiImageMetadata.fromNaiComment(commentJson, rawJson: textData);
                }
              } catch (_) {
                // Comment不是有效的JSON，忽略
              }
            } else if (comment is Map<String, dynamic>) {
              if (comment.containsKey('prompt') || comment.containsKey('uc')) {
                return NaiImageMetadata.fromNaiComment(comment, rawJson: textData);
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

  /// 批量写入数据库（优化：使用内存缓存减少数据库查询次数）
  Future<void> _writeBatchToDatabase(
    List<_ParseItem> items,
    ScanResultBuilder result, {
    required bool isFullScan,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 使用预加载的缓存，如果不可用则创建空缓存
    final hashToIdCache = <String, int?>{};
    final pathToIdCache = <String, int?>{};

    for (final item in items) {
      try {
        final path = item.path;
        final file = File(path);
        final stat = await file.stat();
        final fileName = p.basename(path);
        final fileHash = item.fileHash;
        final width = item.width;
        final height = item.height;
        final metadata = item.metadata;

        final aspectRatio = (width != null && height != null && height > 0)
            ? width / height
            : null;

        // 优先使用预加载的全局缓存，然后使用批次内缓存，最后才查询数据库
        final cachedId = _getImageIdFromCacheByHash(fileHash);
        int? existingIdByHash = cachedId ?? hashToIdCache[fileHash];

        // 调试日志：追踪缓存命中率
        if (existingIdByHash != null) {
          AppLogger.d('[CACHE-HIT] Hash cache hit for $fileName (id=$existingIdByHash)', 'GalleryScanService');
        } else if (cachedId == null && _hashToIdMap != null && _hashToIdMap!.isNotEmpty) {
          // 全局缓存存在但没有这个哈希，说明是新文件
          AppLogger.d('[CACHE-MISS] Hash not in global cache: $fileName', 'GalleryScanService');
        }

        if (existingIdByHash == null && !hashToIdCache.containsKey(fileHash)) {
          existingIdByHash = await _dataSource.getImageIdByHash(fileHash);
          hashToIdCache[fileHash] = existingIdByHash;
          if (existingIdByHash != null) {
            AppLogger.d('[DB-HIT] Found in DB by hash: $fileName (id=$existingIdByHash)', 'GalleryScanService');
          }
        }

        if (existingIdByHash != null) {
          final existingRecord = await _dataSource.getImageById(existingIdByHash);
          if (existingRecord != null && existingRecord.filePath != path) {
            AppLogger.i(
              'Detected renamed file: ${existingRecord.filePath} -> $path',
              'GalleryScanService',
            );
            await _handleRenamedFile(existingIdByHash, path, fileName, stat, result);
            ImageMetadataService().notifyPathChanged(existingRecord.filePath, path);
            continue;
          }
        }

        final imageId = await _dataSource.upsertImage(
          filePath: path,
          fileName: fileName,
          fileSize: stat.size,
          fileHash: fileHash,
          width: width,
          height: height,
          aspectRatio: aspectRatio,
          createdAt: stat.modified,
          modifiedAt: stat.modified,
          resolutionKey: width != null && height != null ? '${width}x$height' : null,
        );

        // 更新全局缓存和批次内缓存
        _updateCache(fileHash, path, imageId);

        if (metadata != null && metadata.hasData) {
          await _dataSource.upsertMetadata(imageId, metadata);
        }

        // 缓存元数据
        if (metadata != null && metadata.hasData) {
          ImageMetadataService().cacheMetadata(path, metadata);
        }

        // 更新统计 - 优先使用预加载的缓存
        if (isFullScan) {
          result.filesAdded++;
        } else {
          int? existingId = _getImageIdFromCacheByPath(path) ?? pathToIdCache[path];
          if (existingId == null && !pathToIdCache.containsKey(path)) {
            existingId = await _dataSource.getImageIdByPath(path);
            pathToIdCache[path] = existingId;
          }
          if (existingId != null && existingId != imageId) {
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
  Future<_ParseResult> _parseInIsolate(List<String> paths, List<Uint8List> bytesList) async {
    final totalStopwatch = Stopwatch()..start();

    try {
      // 分离 PNG 文件和非 PNG 文件
      final pngPaths = <String>[];
      final nonPngItems = <_ParseItem>[];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final bytes = bytesList[i];

        if (p.extension(path).toLowerCase() == '.png') {
          pngPaths.add(path);
        } else {
          // 非 PNG 文件：直接计算哈希，没有元数据
          final fileHash = await Isolate.run(() => _computeFileHashSync(bytes));
          nonPngItems.add(_ParseItem(
            path: path,
            metadata: null,
            width: null,
            height: null,
            fileHash: fileHash,
            fileSize: bytes.length,
            modifiedAt: DateTime.now(),
          ),);
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
            AppLogger.w('[PERF-ISOLATE] Metadata parse error for $path: $error', 'GalleryScanService');
          }
          metadataResults[path] = metadata;
        }

        AppLogger.d(
          '[PERF-ISOLATE] Batch metadata parsed: ${results.length} files in ${batchStopwatch.elapsedMilliseconds}ms',
          'GalleryScanService',
        );
      }

      // 在 isolate 中计算所有文件的哈希
      final hashStopwatch = Stopwatch()..start();
      final hashResults = await Isolate.run(() {
        final results = <String, String>{};
        for (var i = 0; i < paths.length; i++) {
          results[paths[i]] = _computeFileHashSync(bytesList[i]);
        }
        return results;
      });
      hashStopwatch.stop();

      // 组合结果
      final items = <_ParseItem>[];
      items.addAll(nonPngItems);

      for (final path in pngPaths) {
        final metadata = metadataResults[path];
        final bytes = bytesList[paths.indexOf(path)];

        items.add(_ParseItem(
          path: path,
          metadata: metadata,
          width: metadata?.width,
          height: metadata?.height,
          fileHash: hashResults[path]!,
          fileSize: bytes.length,
          modifiedAt: DateTime.now(),
        ),);
      }

      totalStopwatch.stop();
      if (totalStopwatch.elapsedMilliseconds > 500) {
        AppLogger.w(
          '[PERF-ISOLATE] Slow batch: ${totalStopwatch.elapsedMilliseconds}ms for ${paths.length} files '
          '(hash: ${hashStopwatch.elapsedMilliseconds}ms)',
          'GalleryScanService',
        );
      }

      return _ParseResult(items, []);
    } catch (e, stack) {
      AppLogger.e('[PERF-ISOLATE] Batch parse error', e, stack, 'GalleryScanService');
      return _ParseResult([], [e.toString()]);
    }
  }

  /// 同步计算文件哈希（用于 isolate 中）
  String _computeFileHashSync(Uint8List bytes) {
    if (bytes.length <= 16384) {
      return sha256.convert(bytes).toString();
    }

    final headBytes = bytes.sublist(0, 8192);
    final tailBytes = bytes.sublist(bytes.length - 8192);
    final combined = Uint8List(headBytes.length + tailBytes.length + 8);
    combined.setAll(0, headBytes);
    combined.setAll(headBytes.length, tailBytes);

    final sizeBytes = ByteData(8);
    sizeBytes.setInt64(0, bytes.length);
    combined.setAll(headBytes.length + tailBytes.length, sizeBytes.buffer.asUint8List());

    return sha256.convert(combined).toString();
  }

  Future<void> _handleRenamedFile(
    int imageId,
    String newPath,
    String newFileName,
    FileStat stat,
    ScanResultBuilder result,
  ) async {
    try {
      await _dataSource.updateFilePath(imageId, newPath, newFileName: newFileName);
      result.filesUpdated++;
      AppLogger.d('Updated path for image $imageId: $newPath', 'GalleryScanService');
    } catch (e, stack) {
      AppLogger.e('Failed to handle renamed file: $newPath', e, stack, 'GalleryScanService');
      result.errors.add('$newPath: $e');
    }
  }

  Future<List<File>> _collectImageFiles(Directory dir) async {
    final files = <File>[];
    await for (final file in _scanDirectory(dir)) {
      files.add(file);
    }
    return files;
  }

  Future<List<File>> _collectRecentFiles(Directory dir, {required int maxFiles}) async {
    final filesWithTime = <File, DateTime>{};

    await for (final file in _scanDirectory(dir)) {
      try {
        final stat = await file.stat();
        filesWithTime[file] = stat.modified;
      } catch (e) {
        // 文件可能已被删除或无法访问，跳过
      }
    }

    final sortedEntries = filesWithTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(maxFiles).map((e) => e.key).toList();
  }

  Stream<File> _scanDirectory(Directory dir) async* {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        // 【修复】排除.thumbs目录中的文件，防止缩略图递归生成
        if (entity.path.contains('${Platform.pathSeparator}.thumbs${Platform.pathSeparator}') ||
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
}
