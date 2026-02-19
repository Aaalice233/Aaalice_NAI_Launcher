import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../models/gallery/nai_image_metadata.dart';

/// 扫描结果
class ScanResult {
  int filesScanned = 0;
  int filesAdded = 0;
  int filesUpdated = 0;
  int filesDeleted = 0;
  int filesSkipped = 0;
  Duration duration = Duration.zero;
  List<String> errors = [];

  @override
  String toString() {
    return 'ScanResult(scanned: $filesScanned, added: $filesAdded, '
        'updated: $filesUpdated, skipped: $filesSkipped, deleted: $filesDeleted, duration: $duration)';
  }
}

/// 扫描进度回调
typedef ScanProgressCallback = void Function({
  required int processed,
  required int total,
  String? currentFile,
  required String phase,
});

/// 批量解析结果（从 isolate 返回）
class _ParseResult {
  final List<({String path, NaiImageMetadata? metadata, int? width, int? height})> results;
  final List<String> errors;

  _ParseResult(this.results, this.errors);
}

/// 画廊扫描服务（智能版）
///
/// 策略：
/// - 小批量（<=500张）：主线程直接处理，避免 isolate 开销
/// - 大批量（>500张）：使用 isolate 批量解析元数据
class GalleryScanService {
  final GalleryDataSource _dataSource;

  static const List<String> _supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
  static const int _batchSize = 50;
  
  /// 使用 isolate 的阈值
  static const int _isolateThreshold = 500;

  GalleryScanService({required GalleryDataSource dataSource}) : _dataSource = dataSource;

  static GalleryScanService? _instance;
  static GalleryScanService get instance {
    _instance ??= GalleryScanService(dataSource: GalleryDataSource());
    return _instance!;
  }

  // ============================================================
  // 公开API
  // ============================================================

  /// 检测需要处理的文件数量
  Future<(int, int)> detectFilesNeedProcessing(Directory rootDir) async {
    final existingFiles = await _getAllFileHashes();
    final existingPaths = existingFiles.keys.toSet();

    int totalFiles = 0;
    int needProcessing = 0;

    await for (final file in _scanDirectory(rootDir)) {
      totalFiles++;
      final path = file.path;
      final existingHash = existingFiles[path];

      if (!existingPaths.contains(path)) {
        needProcessing++;
      } else if (existingHash != null) {
        final currentHash = await _computeFileHash(file);
        if (currentHash != existingHash) {
          needProcessing++;
        }
      }
    }

    return (totalFiles, needProcessing);
  }

  /// 快速启动扫描
  Future<ScanResult> quickStartupScan(
    Directory rootDir, {
    int maxFiles = 100,
    ScanProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Quick startup scan started (max $maxFiles files)', 'GalleryScanService');

    try {
      onProgress?.call(processed: 0, total: 0, phase: 'checking');
      final existingFiles = await _getAllFileHashes();

      // 收集最近的文件
      final recentFiles = await _collectRecentFiles(rootDir, maxFiles: maxFiles);
      result.filesScanned = recentFiles.length;

      // 筛选出需要处理的文件
      final filesToProcess = <File>[];
      for (final file in recentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (existingHash == null) {
          filesToProcess.add(file);
        } else {
          final currentHash = await _computeFileHash(file);
          if (currentHash != existingHash) {
            filesToProcess.add(file);
          } else {
            result.filesSkipped++;
          }
        }
      }

      AppLogger.i(
        'Quick scan: ${recentFiles.length} files, ${filesToProcess.length} need processing',
        'GalleryScanService',
      );

      // 处理文件
      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
        );
      }

    } catch (e, stack) {
      AppLogger.e('Quick startup scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    AppLogger.i('Quick startup scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 完整增量扫描
  Future<ScanResult> incrementalScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

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

      // 检测需要处理的文件
      final filesToProcess = <File>[];
      for (final file in currentFiles) {
        final path = file.path;
        final existingHash = existingFiles[path];

        if (!existingPaths.contains(path)) {
          filesToProcess.add(file);
        } else if (existingHash != null) {
          final currentHash = await _computeFileHash(file);
          if (currentHash != existingHash) {
            filesToProcess.add(file);
          } else {
            result.filesSkipped++;
          }
        }
      }

      // 处理文件
      if (filesToProcess.isNotEmpty) {
        await _processFilesSmart(
          filesToProcess,
          result,
          isFullScan: false,
          onProgress: onProgress,
        );
      }

      // 标记已删除的文件
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
    return result;
  }

  /// 全量扫描
  Future<ScanResult> fullScan(
    Directory rootDir, {
    ScanProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = ScanResult();

    AppLogger.i('Full scan started', 'GalleryScanService');

    try {
      final files = await _collectImageFiles(rootDir);
      result.filesScanned = files.length;

      await _processFilesSmart(
        files,
        result,
        isFullScan: true,
        onProgress: onProgress,
      );

    } catch (e, stack) {
      AppLogger.e('Full scan failed', e, stack, 'GalleryScanService');
      result.errors.add(e.toString());
    }

    stopwatch.stop();
    result.duration = stopwatch.elapsed;

    onProgress?.call(processed: result.filesScanned, total: result.filesScanned, phase: 'completed');
    AppLogger.i('Full scan completed: $result', 'GalleryScanService');
    return result;
  }

  /// 处理指定文件
  Future<void> processFiles(List<File> files) async {
    if (files.isEmpty) return;

    final result = ScanResult();
    await _processFilesSmart(files, result, isFullScan: false);

    AppLogger.d(
      'Processed ${files.length} files: ${result.filesAdded} added, ${result.filesUpdated} updated',
      'GalleryScanService',
    );
  }

  /// 标记文件为已删除
  Future<void> markAsDeleted(List<String> paths) async {
    if (paths.isEmpty) return;
    await _dataSource.batchMarkAsDeleted(paths);
  }

  // ============================================================
  // 私有方法
  // ============================================================

  /// 获取所有文件哈希
  Future<Map<String, String>> _getAllFileHashes() async {
    try {
      final images = await _dataSource.getAllImages();
      return {for (var img in images) img.filePath: img.fileHash ?? ''};
    } catch (e, stack) {
      AppLogger.e('Failed to get all file hashes', e, stack, 'GalleryScanService');
      return {};
    }
  }

  /// 智能处理文件（根据数量选择策略）
  Future<void> _processFilesSmart(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
  }) async {
    // 小批量：主线程直接处理
    if (files.length <= _isolateThreshold) {
      AppLogger.d('Processing ${files.length} files in main thread', 'GalleryScanService');
      await _processInMainThread(files, result, isFullScan: isFullScan, onProgress: onProgress);
    } else {
      // 大批量：使用 isolate
      AppLogger.d('Processing ${files.length} files with isolate', 'GalleryScanService');
      await _processWithIsolate(files, result, isFullScan: isFullScan, onProgress: onProgress);
    }
  }

  /// 在主线程处理（小批量）
  Future<void> _processInMainThread(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
  }) async {
    int processedCount = 0;

    for (var i = 0; i < files.length; i += _batchSize) {
      final batch = files.skip(i).take(_batchSize).toList();

      for (final file in batch) {
        await _processSingleFile(file, result, isFullScan: isFullScan);
        processedCount++;
      }

      onProgress?.call(
        processed: processedCount,
        total: files.length,
        currentFile: batch.last.path,
        phase: 'indexing',
      );

      // 让出时间片，避免阻塞UI
      // 对于大批量文件，增加延迟以降低CPU占用
      if (files.length > _isolateThreshold) {
        await Future.delayed(const Duration(milliseconds: 10));
      } else {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// 使用 Isolate 处理（大批量）
  Future<void> _processWithIsolate(
    List<File> files,
    ScanResult result, {
    required bool isFullScan,
    ScanProgressCallback? onProgress,
  }) async {
    int processedCount = 0;

    for (var i = 0; i < files.length; i += _batchSize) {
      final batch = files.skip(i).take(_batchSize).toList();

      // 读取文件字节
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

      // 在 isolate 中批量解析
      final parseResult = await _parseInIsolate(paths, bytesList);

      // 写入数据库
      for (var j = 0; j < parseResult.results.length; j++) {
        final res = parseResult.results[j];
        await _writeToDatabase(
          res.path,
          res.metadata,
          res.width,
          res.height,
          result,
          isFullScan: isFullScan,
        );
      }

      result.errors.addAll(parseResult.errors);
      processedCount += batch.length;

      onProgress?.call(
        processed: processedCount,
        total: files.length,
        currentFile: batch.last.path,
        phase: 'indexing',
      );

      // 让出时间片，避免阻塞UI
      // 对于大批量文件，增加延迟以降低CPU占用
      if (files.length > _isolateThreshold) {
        await Future.delayed(const Duration(milliseconds: 10));
      } else {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// 在 isolate 中批量解析元数据
  Future<_ParseResult> _parseInIsolate(List<String> paths, List<Uint8List> bytesList) async {
    return await Isolate.run(() async {
      final results = <({String path, NaiImageMetadata? metadata, int? width, int? height})>[];
      final errors = <String>[];

      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        final bytes = bytesList[i];

        try {
          NaiImageMetadata? metadata;
          int? width;
          int? height;

          if (p.extension(path).toLowerCase() == '.png') {
            metadata = await NaiMetadataParser.extractFromBytes(bytes);
            if (metadata != null) {
              width = metadata.width;
              height = metadata.height;
            }
          }

          results.add((path: path, metadata: metadata, width: width, height: height));
        } catch (e) {
          errors.add('$path: $e');
        }
      }

      return _ParseResult(results, errors);
    });
  }

  /// 写入数据库
  Future<void> _writeToDatabase(
    String path,
    NaiImageMetadata? metadata,
    int? width,
    int? height,
    ScanResult result, {
    required bool isFullScan,
  }) async {
    try {
      final file = File(path);
      final stat = await file.stat();
      final fileName = p.basename(path);
      final fileHash = await _computeFileHash(file);

      final aspectRatio = (width != null && height != null && height > 0)
          ? width / height
          : null;

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

      if (metadata != null && metadata.hasData) {
        await _dataSource.upsertMetadata(imageId, metadata);
      }

      if (isFullScan) {
        result.filesAdded++;
      } else {
        final existingId = await _dataSource.getImageIdByPath(path);
        if (existingId != null) {
          result.filesUpdated++;
        } else {
          result.filesAdded++;
        }
      }
    } catch (e) {
      result.errors.add('$path: $e');
    }
  }

  /// 处理单个文件（主线程）
  Future<void> _processSingleFile(
    File file,
    ScanResult result, {
    required bool isFullScan,
  }) async {
    NaiImageMetadata? metadata;
    int? width;
    int? height;

    // 提取 PNG 元数据
    if (p.extension(file.path).toLowerCase() == '.png') {
      try {
        final bytes = await file.readAsBytes();
        metadata = await NaiMetadataParser.extractFromBytes(bytes);
        width = metadata?.width;
        height = metadata?.height;
      } catch (e) {
        result.errors.add('${file.path}: $e');
        return;
      }
    }

    // 复用数据库写入逻辑
    await _writeToDatabase(
      file.path,
      metadata,
      width,
      height,
      result,
      isFullScan: isFullScan,
    );
  }

  /// 收集目录下所有图片文件
  Future<List<File>> _collectImageFiles(Directory dir) async {
    final files = <File>[];
    await for (final file in _scanDirectory(dir)) {
      files.add(file);
    }
    return files;
  }

  /// 收集最近的N个图片文件
  Future<List<File>> _collectRecentFiles(Directory dir, {required int maxFiles}) async {
    final filesWithTime = <File, DateTime>{};

    await for (final file in _scanDirectory(dir)) {
      try {
        final stat = await file.stat();
        filesWithTime[file] = stat.modified;
      } catch (_) {}
    }

    final sortedEntries = filesWithTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.take(maxFiles).map((e) => e.key).toList();
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

  /// 计算文件快速哈希
  Future<String> _computeFileHash(File file) async {
    try {
      final stat = await file.stat();
      final fileSize = stat.size;

      if (fileSize <= 16384) {
        final bytes = await file.readAsBytes();
        return sha256.convert(bytes).toString();
      }

      final raf = await file.open(mode: FileMode.read);
      try {
        final headBytes = await raf.read(8192);
        await raf.setPosition(fileSize - 8192);
        final tailBytes = await raf.read(8192);

        final combined = Uint8List(headBytes.length + tailBytes.length + 8);
        combined.setAll(0, headBytes);
        combined.setAll(headBytes.length, tailBytes);

        final sizeBytes = ByteData(8);
        sizeBytes.setInt64(0, fileSize);
        combined.setAll(headBytes.length + tailBytes.length, sizeBytes.buffer.asUint8List());

        return sha256.convert(combined).toString();
      } finally {
        await raf.close();
      }
    } catch (e) {
      return '';
    }
  }
}
