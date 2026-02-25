import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/local_image_record.dart';
import '../../models/gallery/nai_image_metadata.dart';
import '../image_metadata_service.dart';
import 'scan_config.dart';
import 'scan_state_manager.dart';

/// 文件处理阶段
enum FileProcessingStage {
  discovered,      // 发现文件
  indexing,        // 索引中（检查是否需要处理）
  extracting,      // 提取元数据中
  caching,         // 缓存元数据
  completed,       // 完成
  skipped,         // 跳过（无需处理）
  error,           // 错误
}

/// 单文件处理结果
class FileProcessingResult {
  final String path;
  final FileProcessingStage stage;
  final NaiImageMetadata? metadata;
  final bool isNewFile;
  final bool metadataUpdated;
  final String? error;

  FileProcessingResult({
    required this.path,
    required this.stage,
    this.metadata,
    this.isNewFile = false,
    this.metadataUpdated = false,
    this.error,
  });
}

/// 流式扫描统计
class StreamScanStats {
  final int totalDiscovered;      // 发现的文件总数
  final int processed;            // 已处理数量
  final int skipped;              // 跳过数量
  final int withMetadata;         // 有元数据的数量
  final int failed;               // 失败的数量
  final String currentFile;       // 当前处理的文件
  final FileProcessingStage currentStage; // 当前阶段
  final double progress;          // 总体进度 (0.0 - 1.0)

  StreamScanStats({
    this.totalDiscovered = 0,
    this.processed = 0,
    this.skipped = 0,
    this.withMetadata = 0,
    this.failed = 0,
    this.currentFile = '',
    this.currentStage = FileProcessingStage.discovered,
    this.progress = 0.0,
  });

  StreamScanStats copyWith({
    int? totalDiscovered,
    int? processed,
    int? skipped,
    int? withMetadata,
    int? failed,
    String? currentFile,
    FileProcessingStage? currentStage,
    double? progress,
  }) {
    return StreamScanStats(
      totalDiscovered: totalDiscovered ?? this.totalDiscovered,
      processed: processed ?? this.processed,
      skipped: skipped ?? this.skipped,
      withMetadata: withMetadata ?? this.withMetadata,
      failed: failed ?? this.failed,
      currentFile: currentFile ?? this.currentFile,
      currentStage: currentStage ?? this.currentStage,
      progress: progress ?? this.progress,
    );
  }

  /// 计算剩余文件数
  int get remaining => totalDiscovered - processed - skipped;
  /// 计算覆盖率
  double get coverage => totalDiscovered > 0 ? withMetadata / totalDiscovered : 0.0;
}

/// 画廊流式扫描器
/// 
/// 真正的流式处理：发现文件 → 立即处理 → 实时更新
/// 每处理一张图就更新UI，而不是先收集所有文件
class GalleryStreamScanner {
  final GalleryDataSource _dataSource;
  final ScanStateManager _stateManager = ScanStateManager.instance;
  final _metadataService = ImageMetadataService();

  // 状态
  bool _isRunning = false;
  bool _shouldCancel = false;
  
  // 统计
  final _statsController = StreamController<StreamScanStats>.broadcast();
  final _resultController = StreamController<FileProcessingResult>.broadcast();
  
  // 缓存
  final _existingMap = <String, (int, int, int, MetadataStatus, DateTime?)>{};

  Stream<StreamScanStats> get statsStream => _statsController.stream;
  Stream<FileProcessingResult> get resultStream => _resultController.stream;

  GalleryStreamScanner({required GalleryDataSource dataSource})
      : _dataSource = dataSource;

  /// 开始流式扫描
  /// 
  /// [onFileProcessed] - 每个文件处理完成时的回调
  Future<void> startScanning(
    Directory rootDir, {
    void Function(FileProcessingResult result, StreamScanStats stats)? onFileProcessed,
  }) async {
    if (_isRunning) {
      AppLogger.w('[StreamScan] Scanner already running', 'GalleryStreamScanner');
      return;
    }

    _isRunning = true;
    _shouldCancel = false;
    
    AppLogger.i('[StreamScan] Starting stream scan: ${rootDir.path}', 'GalleryStreamScanner');

    try {
      // 1. 预加载数据库记录（只加载一次）
      await _preloadExistingRecords();
      
      // 2. 启动扫描状态管理器（总文件数未知，边扫描边更新）
      _stateManager.startScan(
        type: ScanType.incremental,
        rootPath: rootDir.path,
        total: 0, // 流式扫描，总数动态更新
        existingInDatabase: _existingMap.length,
        metadataCacheCount: _existingMap.values.where((e) => e.$4 == MetadataStatus.success).length,
      );

      // 3. 流式处理：发现文件 → 立即处理
      var stats = StreamScanStats();
      
      await for (final file in _scanDirectory(rootDir)) {
        if (_shouldCancel) break;

        // 更新发现计数
        stats = stats.copyWith(
          totalDiscovered: stats.totalDiscovered + 1,
          currentFile: p.basename(file.path),
          currentStage: FileProcessingStage.discovered,
        );
        _statsController.add(stats);

        // 立即处理这个文件
        final result = await _processSingleFile(file, stats);
        
        // 更新统计
        stats = stats.copyWith(
          processed: result.stage == FileProcessingStage.completed || result.stage == FileProcessingStage.error
              ? stats.processed + 1
              : stats.processed,
          skipped: result.stage == FileProcessingStage.skipped
              ? stats.skipped + 1
              : stats.skipped,
          withMetadata: result.metadata != null && result.metadata!.hasData
              ? stats.withMetadata + 1
              : stats.withMetadata,
          failed: result.stage == FileProcessingStage.error
              ? stats.failed + 1
              : stats.failed,
          progress: stats.totalDiscovered > 0
              ? (stats.processed + stats.skipped) / stats.totalDiscovered
              : 0.0,
        );

        // 发送结果
        _resultController.add(result);
        _statsController.add(stats);
        
        // 回调
        onFileProcessed?.call(result, stats);

        // 更新 ScanStateManager
        _stateManager.updateProgress(
          processed: stats.processed + stats.skipped,
          total: stats.totalDiscovered,
          currentFile: p.basename(file.path),
          phase: _stageToPhase(result.stage),
        );

        // 让出时间片，避免阻塞UI
        if (stats.totalDiscovered % 10 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      // 扫描完成
      _stateManager.completeScan();
      AppLogger.i(
        '[StreamScan] Scan completed: ${stats.totalDiscovered} discovered, '
        '${stats.processed} processed, ${stats.withMetadata} with metadata',
        'GalleryStreamScanner',
      );

    } catch (e, stack) {
      AppLogger.e('[StreamScan] Scan failed', e, stack, 'GalleryStreamScanner');
      _stateManager.errorScan(e.toString());
    } finally {
      _isRunning = false;
      await _statsController.close();
      await _resultController.close();
    }
  }

  /// 取消扫描
  void cancel() {
    _shouldCancel = true;
    AppLogger.i('[StreamScan] Scan cancelled by user', 'GalleryStreamScanner');
  }

  /// 预加载现有记录
  Future<void> _preloadExistingRecords() async {
    final existingRecords = await _dataSource.getAllImages();
    _existingMap.clear();
    for (final img in existingRecords) {
      if (!img.isDeleted && img.id != null) {
        _existingMap[img.filePath] = (
          img.fileSize,
          img.modifiedAt.millisecondsSinceEpoch,
          img.id!,
          img.metadataStatus,
          img.lastScannedAt,
        );
      }
    }
    AppLogger.i(
      '[StreamScan] Preloaded ${_existingMap.length} existing records',
      'GalleryStreamScanner',
    );
  }

  /// 处理单个文件
  Future<FileProcessingResult> _processSingleFile(
    File file,
    StreamScanStats stats,
  ) async {
    final path = file.path;
    final fileName = p.basename(path);

    try {
      // 阶段1: 索引检查
      _updateStage(stats, FileProcessingStage.indexing, fileName);
      
      final stat = await file.stat();
      final existing = _existingMap[path];
      
      final bool needsUpdate;
      if (existing == null) {
        needsUpdate = true; // 新文件
      } else {
        final (existingSize, existingMtime, _, metadataStatus, lastScannedAt) = existing;
        if (stat.size != existingSize ||
            stat.modified.millisecondsSinceEpoch != existingMtime) {
          needsUpdate = true; // 文件已变化
        } else if (metadataStatus == MetadataStatus.none) {
          needsUpdate = true; // 缺少元数据
        } else if (lastScannedAt == null) {
          needsUpdate = true; // 从未扫描
        } else {
          needsUpdate = false; // 无需处理
        }
      }

      if (!needsUpdate) {
        return FileProcessingResult(
          path: path,
          stage: FileProcessingStage.skipped,
        );
      }

      // 阶段2: 提取元数据
      _updateStage(stats, FileProcessingStage.extracting, fileName);
      final metadata = await _metadataService.getMetadataImmediate(file.path);

      // 阶段3: 写入数据库
      _updateStage(stats, FileProcessingStage.caching, fileName);
      
      final isNewFile = existing == null;
      final metadataStatus = metadata != null && metadata.hasData
          ? MetadataStatus.success
          : MetadataStatus.none;

      final imageId = await _dataSource.upsertImage(
        filePath: path,
        fileName: fileName,
        fileSize: stat.size,
        width: metadata?.width,
        height: metadata?.height,
        aspectRatio: _calculateAspectRatio(metadata?.width, metadata?.height),
        createdAt: stat.modified,
        modifiedAt: stat.modified,
        resolutionKey: metadata?.width != null && metadata?.height != null
            ? '${metadata!.width}x${metadata.height}'
            : null,
        lastScannedAt: DateTime.now(),
        metadataStatus: metadataStatus,
      );

      if (metadata != null && metadata.hasData) {
        await _dataSource.upsertMetadata(imageId, metadata);
        _metadataService.cacheMetadata(path, metadata);
        
        // 更新本地缓存
        _existingMap[path] = (
          stat.size,
          stat.modified.millisecondsSinceEpoch,
          imageId,
          MetadataStatus.success,
          DateTime.now(),
        );
      }

      // 阶段4: 完成
      return FileProcessingResult(
        path: path,
        stage: FileProcessingStage.completed,
        metadata: metadata,
        isNewFile: isNewFile,
        metadataUpdated: metadata != null && metadata.hasData,
      );

    } catch (e) {
      AppLogger.w('[StreamScan] Error processing $fileName: $e', 'GalleryStreamScanner');
      return FileProcessingResult(
        path: path,
        stage: FileProcessingStage.error,
        error: e.toString(),
      );
    }
  }

  /// 更新当前阶段
  void _updateStage(StreamScanStats stats, FileProcessingStage stage, String fileName) {
    _statsController.add(
      stats.copyWith(
        currentStage: stage,
        currentFile: fileName,
      ),
    );
  }

  /// 计算宽高比
  double? _calculateAspectRatio(int? width, int? height) {
    if (width != null && height != null && height > 0) {
      return width / height;
    }
    return null;
  }

  /// 扫描目录
  Stream<File> _scanDirectory(Directory rootDir) async* {
    const supportedExtensions = ['.png', '.jpg', '.jpeg', '.webp'];
    
    await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
      if (_shouldCancel) break;
      
      if (entity is File) {
        // 跳过缩略图
        if (entity.path.contains('${Platform.pathSeparator}.thumbs${Platform.pathSeparator}') ||
            entity.path.contains('.thumb.')) {
          continue;
        }
        
        final ext = p.extension(entity.path).toLowerCase();
        if (supportedExtensions.contains(ext)) {
          yield entity;
        }
      }
    }
  }

  /// 转换阶段到 ScanPhase
  ScanPhase _stageToPhase(FileProcessingStage stage) {
    switch (stage) {
      case FileProcessingStage.discovered:
      case FileProcessingStage.indexing:
        return ScanPhase.scanning;
      case FileProcessingStage.extracting:
        return ScanPhase.parsing;
      case FileProcessingStage.caching:
        return ScanPhase.indexing;
      case FileProcessingStage.completed:
      case FileProcessingStage.skipped:
        return ScanPhase.completed;
      case FileProcessingStage.error:
        return ScanPhase.idle;
    }
  }
}
