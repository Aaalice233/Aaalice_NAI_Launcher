import 'dart:async';
import 'dart:io';

import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/utils/app_logger.dart';
import '../../repositories/gallery_folder_repository.dart';
import 'gallery_album_sidecar_service.dart';
import 'gallery_stream_scanner.dart';
import 'local_gallery_repository.dart';
import 'scan_state_manager.dart';

enum GalleryStartupIndexAction { none, fullScan }

GalleryStartupIndexAction chooseStartupIndexAction({
  required int databaseImageCount,
  required int fileSystemImageCount,
  int? unparsedImageCount = 0,
}) {
  if (databaseImageCount > 0 &&
      databaseImageCount == fileSystemImageCount &&
      unparsedImageCount == 0) {
    return GalleryStartupIndexAction.none;
  }
  return GalleryStartupIndexAction.fullScan;
}

bool shouldRunRefreshIndexScan({
  required bool scanRequested,
  required bool isBackgroundScanning,
}) => scanRequested && !isBackgroundScanning;

/// Serializes initialization and refresh while delegating indexing to the
/// existing stream scanner and its global scan state.
class GalleryScanCoordinator {
  GalleryScanCoordinator({
    required GalleryDataSource dataSource,
    required LocalGalleryRepository repository,
  }) : _dataSource = dataSource,
       _repository = repository;

  final GalleryDataSource _dataSource;
  final LocalGalleryRepository _repository;
  Future<List<File>>? _initializing;
  Future<void>? _refreshing;
  bool _isBackgroundScanning = false;

  Future<List<File>> initialize() {
    final active = _initializing;
    if (active != null) return active;
    final operation = _initialize();
    _initializing = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_initializing, operation)) _initializing = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_initializing, operation)) _initializing = null;
        },
      ),
    );
    return operation;
  }

  Future<List<File>> _initialize() async {
    final files = await _repository.findGalleryFiles();
    AppLogger.i(
      'Found ${files.length} image files in file system',
      'LocalGalleryService',
    );
    unawaited(_initializeIndexInBackground(List<File>.unmodifiable(files)));
    return files;
  }

  Future<void> refresh({
    required bool scan,
    required int previousCount,
    required Future<void> Function(List<File> files) onFilesLoaded,
  }) {
    final active = _refreshing;
    if (active != null) return active;
    final operation = _refresh(
      scan: scan,
      previousCount: previousCount,
      onFilesLoaded: onFilesLoaded,
    );
    _refreshing = operation;
    unawaited(
      operation.then<void>(
        (_) {
          if (identical(_refreshing, operation)) _refreshing = null;
        },
        onError: (Object _, StackTrace __) {
          if (identical(_refreshing, operation)) _refreshing = null;
        },
      ),
    );
    return operation;
  }

  Future<void> _refresh({
    required bool scan,
    required int previousCount,
    required Future<void> Function(List<File> files) onFilesLoaded,
  }) async {
    final files = await _repository.findGalleryFiles();
    await onFilesLoaded(files);
    if (shouldRunRefreshIndexScan(
      scanRequested: scan,
      isBackgroundScanning: _isBackgroundScanning,
    )) {
      final countChanged = files.length != previousCount;
      if (countChanged && (files.length - previousCount).abs() > 100) {
        AppLogger.i(
          'File count changed significantly '
              '($previousCount -> ${files.length}), performing full scan',
          'LocalGalleryService',
        );
        await _performScan(files, full: true);
      } else {
        await _performScan(files, full: false);
      }
    } else {
      AppLogger.d(
        'Refresh updated file list without starting index scan: '
            'scanRequested=$scan, backgroundScanning=$_isBackgroundScanning',
        'LocalGalleryService',
      );
    }

    // 云恢复可能发生在启动扫描之后；每次刷新都重试已可解析的成员。
    await _rebindAlbumPendingPaths();
  }

  Future<void> _initializeIndexInBackground(List<File> files) async {
    if (_isBackgroundScanning) {
      AppLogger.d(
        'Background scan already in progress, skipping',
        'LocalGalleryService',
      );
      return;
    }
    _isBackgroundScanning = true;
    AppLogger.i(
      'Starting background index initialization',
      'LocalGalleryService',
    );
    try {
      final existingCount = await _dataSource.countImages();
      AppLogger.i(
        'Database has $existingCount images, file system has ${files.length} images',
        'LocalGalleryService',
      );
      int? unparsedImageCount;
      try {
        final metadataCounts = await _dataSource.countImagesByMetadataStatus();
        unparsedImageCount = metadataCounts['none'];
      } catch (error) {
        AppLogger.w(
          'Metadata status count unavailable; running startup scan: $error',
          'LocalGalleryService',
        );
      }
      final action = chooseStartupIndexAction(
        databaseImageCount: existingCount,
        fileSystemImageCount: files.length,
        unparsedImageCount: unparsedImageCount,
      );
      if (action == GalleryStartupIndexAction.none) {
        AppLogger.i(
          'Skipping startup metadata scan: database and file system counts match',
          'LocalGalleryService',
        );
      } else {
        AppLogger.i(
          'Performing startup file index scan (${files.length} files)',
          'LocalGalleryService',
        );
        await _performScan(files, full: true);
      }
      AppLogger.i(
        'Background index initialization completed',
        'LocalGalleryService',
      );
      await _rebindAlbumPendingPaths();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Background index initialization failed',
        error,
        stackTrace,
        'LocalGalleryService',
      );
      AppLogger.e('Error details: $error', null, null, 'LocalGalleryService');
      AppLogger.e(
        'Stack trace: $stackTrace',
        null,
        null,
        'LocalGalleryService',
      );
    } finally {
      _isBackgroundScanning = false;
    }
  }

  /// 索引就绪后补绑相簿 pending 成员（sidecar / 云同步导入时图库
  /// 尚未完成扫描的相对路径引用）。失败不影响扫描主流程。
  Future<void> _rebindAlbumPendingPaths() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) return;

      final remaining = await _dataSource.albums.rebindPendingPaths(
        resolve: (relativePaths) async {
          final absolutePaths = [
            for (final relativePath in relativePaths)
              GalleryAlbumSidecarService.toAbsolutePath(rootPath, relativePath),
          ];
          final idMap = await _dataSource.getImageIdsByPaths(absolutePaths);
          return {
            for (var i = 0; i < relativePaths.length; i++)
              relativePaths[i]: idMap[absolutePaths[i]],
          };
        },
      );
      if (remaining > 0) {
        AppLogger.i(
          'Album pending rebind finished with  unresolved paths',
          'LocalGalleryService',
        );
      }
    } catch (error, stackTrace) {
      AppLogger.e(
        'Album pending rebind failed',
        error,
        stackTrace,
        'LocalGalleryService',
      );
    }
  }

  Future<void> _performScan(List<File> files, {required bool full}) async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null) {
      AppLogger.w(
        '[UGS] ${full ? '_performFullScan' : '_performIncrementalScan'}: '
            'rootPath is null',
        'LocalGalleryService',
      );
      return;
    }
    final scanManager = ScanStateManager.instance;
    if (scanManager.isScanning) {
      AppLogger.w(
        '[UGS] ${full ? '全量' : '增量'}扫描请求被忽略：已有扫描在进行中',
        'LocalGalleryService',
      );
      return;
    }

    AppLogger.i('[UGS] 开始执行${full ? '全量' : ''}流式扫描', 'LocalGalleryService');
    await GalleryStreamScanner.instance(dataSource: _dataSource).startScanning(
      Directory(rootPath),
      retryMissingMetadata: true,
      fileSnapshot: files,
    );
    AppLogger.i('[UGS] ${full ? '全量' : ''}流式扫描完成', 'LocalGalleryService');
  }
}
