import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import 'gallery_scan_service.dart';

/// 文件变化事件
enum FileChangeType { created, modified, deleted }

class FileChangeEvent {
  final String path;
  final FileChangeType type;
  final DateTime timestamp;

  FileChangeEvent({
    required this.path,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 画廊文件监听服务
/// 
/// 自动监听文件夹变化，实时增量更新数据库
/// 支持 Windows/macOS/Linux 的文件系统事件
class GalleryFileWatcherService {
  final GalleryScanService _scanService;
  
  Directory? _watchedDir;
  StreamSubscription<FileSystemEvent>? _dirSubscription;
  Timer? _debounceTimer;
  
  // 批处理间隔，避免频繁扫描
  static const _debounceMs = 2000;
  
  // 待处理的文件变化
  final _pendingChanges = <String, FileChangeEvent>{};
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  
  /// 单例
  static GalleryFileWatcherService? _instance;
  static GalleryFileWatcherService get instance {
    _instance ??= GalleryFileWatcherService._internal(
      scanService: GalleryScanService.instance,
    );
    return _instance!;
  }
  
  GalleryFileWatcherService._internal({
    required GalleryScanService scanService,
  }) : _scanService = scanService;
  
  /// 开始监听指定目录
  /// 
  /// 自动处理文件创建、修改、删除事件
  Future<void> watch(Directory directory) async {
    // 停止之前的监听
    await stop();
    
    if (!await directory.exists()) {
      AppLogger.w('Directory does not exist: ${directory.path}', 'GalleryFileWatcher');
      return;
    }
    
    _watchedDir = directory;
    _isInitialized = true;
    
    AppLogger.i('Starting file watcher for: ${directory.path}', 'GalleryFileWatcher');
    
    // 监听目录下的文件事件
    _dirSubscription = directory.watch(recursive: true).listen(
      _handleFileEvent,
      onError: (e) => AppLogger.w('Watch error: $e', 'GalleryFileWatcher'),
      onDone: () => AppLogger.d('Watch stream closed', 'GalleryFileWatcher'),
    );
  }
  
  /// 处理文件系统事件
  void _handleFileEvent(FileSystemEvent event) {
    // 只处理图片文件
    final ext = p.extension(event.path).toLowerCase();
    if (!['.png', '.jpg', '.jpeg', '.webp'].contains(ext)) {
      return;
    }
    
    FileChangeType? changeType;
    
    if (event is FileSystemCreateEvent) {
      changeType = FileChangeType.created;
    } else if (event is FileSystemModifyEvent) {
      changeType = FileChangeType.modified;
    } else if (event is FileSystemDeleteEvent) {
      changeType = FileChangeType.deleted;
    }
    
    if (changeType != null) {
      _pendingChanges[event.path] = FileChangeEvent(
        path: event.path,
        type: changeType,
      );
      
      // 防抖处理，避免频繁扫描
      _debounceTimer?.cancel();
      _debounceTimer = Timer(
        const Duration(milliseconds: _debounceMs),
        _processPendingChanges,
      );
    }
  }
  
  /// 处理待处理的文件变化
  Future<void> _processPendingChanges() async {
    if (_pendingChanges.isEmpty) return;
    
    final changes = Map<String, FileChangeEvent>.from(_pendingChanges);
    _pendingChanges.clear();
    
    AppLogger.i(
      'Processing ${changes.length} file changes',
      'GalleryFileWatcher',
    );
    
    final created = <File>[];
    final modified = <File>[];
    final deleted = <String>[];
    
    for (final event in changes.values) {
      switch (event.type) {
        case FileChangeType.created:
          final file = File(event.path);
          if (await file.exists()) {
            created.add(file);
          }
          break;
        case FileChangeType.modified:
          final file = File(event.path);
          if (await file.exists()) {
            modified.add(file);
          }
          break;
        case FileChangeType.deleted:
          deleted.add(event.path);
          break;
      }
    }
    
    // 执行增量更新
    try {
      if (created.isNotEmpty || modified.isNotEmpty) {
        await _scanService.processFiles([...created, ...modified]);
      }
      if (deleted.isNotEmpty) {
        await _scanService.markAsDeleted(deleted);
      }
      AppLogger.i(
        'Processed: ${created.length} created, ${modified.length} modified, ${deleted.length} deleted',
        'GalleryFileWatcher',
      );
    } catch (e) {
      AppLogger.e('Failed to process changes', e, null, 'GalleryFileWatcher');
    }
  }
  
  /// 停止监听
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    
    await _dirSubscription?.cancel();
    _dirSubscription = null;
    
    _watchedDir = null;
    _isInitialized = false;
    
    _pendingChanges.clear();
    
    AppLogger.d('File watcher stopped', 'GalleryFileWatcher');
  }
  
  /// 手动触发扫描（用于首次启动或用户手动刷新）
  Future<void> performFullScan() async {
    if (_watchedDir == null) {
      throw StateError('Watcher not started. Call watch() first.');
    }
    
    AppLogger.i('Performing full scan...', 'GalleryFileWatcher');
    await _scanService.fullScan(_watchedDir!);
  }
  
  /// 手动触发增量扫描
  Future<void> performIncrementalScan() async {
    if (_watchedDir == null) {
      throw StateError('Watcher not started. Call watch() first.');
    }
    
    AppLogger.i('Performing incremental scan...', 'GalleryFileWatcher');
    await _scanService.incrementalScan(_watchedDir!);
  }
}
