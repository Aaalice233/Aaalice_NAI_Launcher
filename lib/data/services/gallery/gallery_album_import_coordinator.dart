import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/database/datasources/gallery_data_source.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../models/gallery/gallery_album.dart';
import '../../models/gallery/image_collection.dart';
import '../../repositories/collection_repository.dart';
import '../../repositories/gallery_folder_repository.dart';
import 'gallery_album_sidecar_service.dart';

/// 图库相簿一次性导入协调器
///
/// 首次启用相簿时按优先级恢复数据：
/// 1. SQLite 已有相簿 → 什么都不做；
/// 2. 图片库根目录的 .gallery_albums.json（跨设备/重装恢复）；
/// 3. 旧版 Hive collections 集合（无 UI 创建入口，通常为空）。
///
/// 任一路径执行一次后写入标记，不再重复；旧 Hive 数据只读不删，
/// 保证旧版本应用打开同一数据目录时集合仍然可见。
class GalleryAlbumImportCoordinator {
  GalleryAlbumImportCoordinator({
    required GalleryDataSource dataSource,
    required LocalStorageService localStorage,
    GalleryAlbumSidecarService? sidecarService,
    List<ImageCollection> Function()? readLegacyCollections,
    Future<String?> Function()? rootPathProvider,
  }) : _dataSource = dataSource,
       _localStorage = localStorage,
       _sidecarService = sidecarService ?? GalleryAlbumSidecarService(),
       _readLegacyCollections =
           readLegacyCollections ?? _defaultLegacyCollections,
       _rootPathProvider =
           rootPathProvider ?? GalleryFolderRepository.instance.getRootPath;

  final GalleryDataSource _dataSource;
  final LocalStorageService _localStorage;
  final GalleryAlbumSidecarService _sidecarService;
  final List<ImageCollection> Function() _readLegacyCollections;

  static List<ImageCollection> _defaultLegacyCollections() {
    return CollectionRepository.instance.getAllCollections();
  }

  final Future<String?> Function() _rootPathProvider;

  /// 测试注入用：覆盖图库根目录解析
  @visibleForTesting
  set galleryRootPathOverride(String? path) {
    _rootPathOverride = path;
  }

  String? _rootPathOverride;

  Future<String?> _resolveRootPath() async {
    return _rootPathOverride ?? await _rootPathProvider();
  }

  /// 需要跳过的相对路径数量（sidecar 引用了图库中尚不存在的文件）
  int skippedImageCount = 0;

  Future<void> importIfNeeded() async {
    if (_localStorage.getSetting<bool>(StorageKeys.galleryAlbumImportDone) ==
        true) {
      return;
    }

    try {
      final existing = await _dataSource.albums.getAlbums();
      if (existing.isEmpty) {
        final rootPath = await _resolveRootPath();
        var imported = false;
        if (rootPath != null && rootPath.isNotEmpty) {
          imported = await _importFromSidecar(rootPath);
        }
        if (!imported) {
          await _importFromLegacyCollections();
        }
      }
      await _localStorage.setSetting(StorageKeys.galleryAlbumImportDone, true);
    } catch (e) {
      AppLogger.e('相簿初始导入失败（下次启动重试）', e, null, 'AlbumImport');
    }
  }

  Future<bool> _importFromSidecar(String rootPath) async {
    final sidecar = await _sidecarService.read(rootPath);
    if (sidecar == null || sidecar.albums.isEmpty) return false;

    final imageIdsByAlbumId = <String, List<int>>{};
    final pendingPathsByAlbumId = <String, List<String>>{};
    for (final entry in sidecar.imagePathsByAlbumId.entries) {
      final imageIds = <int>[];
      final pendingPaths = <String>[];
      for (final relativePath in entry.value) {
        // 拒绝越界/绝对路径，避免手改 sidecar 注入图库外的引用
        if (!GalleryAlbumSidecarService.isValidRelativeMemberPath(
          relativePath,
        )) {
          skippedImageCount++;
          continue;
        }
        final absolutePath = GalleryAlbumSidecarService.toAbsolutePath(
          rootPath,
          relativePath,
        );
        final imageId = await _dataSource.getImageIdByPath(absolutePath);
        if (imageId != null) {
          imageIds.add(imageId);
        } else if (await File(absolutePath).exists()) {
          // 文件在图库中但尚未索引：保留为 pending，扫描完成后补绑
          pendingPaths.add(relativePath);
        } else {
          skippedImageCount++;
        }
      }
      imageIdsByAlbumId[entry.key] = imageIds;
      if (pendingPaths.isNotEmpty) {
        pendingPathsByAlbumId[entry.key] = pendingPaths;
      }
    }

    await _dataSource.albums.importAlbums(
      sidecar.albums.map(_toRecord).toList(),
      imageIdsByAlbumId,
      pendingPathsByAlbumId: pendingPathsByAlbumId,
    );
    AppLogger.i(
      '从 sidecar 导入 ${sidecar.albums.length} 个相簿，'
          '待补绑 ${pendingPathsByAlbumId.values.map((e) => e.length).fold(0, (a, b) => a + b)} 个引用，'
          '跳过 $skippedImageCount 个无效引用',
      'AlbumImport',
    );
    return true;
  }

  Future<void> _importFromLegacyCollections() async {
    final collections = _readLegacyCollections();
    if (collections.isEmpty) return;

    final rootPath = await _resolveRootPath();
    final albums = <GalleryAlbum>[];
    final imageIdsByAlbumId = <String, List<int>>{};
    final pendingPathsByAlbumId = <String, List<String>>{};
    for (final collection in collections) {
      final imageIds = <int>[];
      final pendingPaths = <String>[];
      for (final imagePath in collection.imagePaths) {
        final imageId = await _dataSource.getImageIdByPath(imagePath);
        if (imageId != null) {
          imageIds.add(imageId);
        } else if (await File(imagePath).exists()) {
          // 旧集合记录的是绝对路径；转换失败（图库外文件）按跳过处理
          final relative = rootPath == null || rootPath.isEmpty
              ? null
              : GalleryAlbumSidecarService.toRelativePath(rootPath, imagePath);
          if (relative != null) {
            pendingPaths.add(relative);
          } else {
            skippedImageCount++;
          }
        } else {
          skippedImageCount++;
        }
      }
      albums.add(
        GalleryAlbum(
          id: collection.id,
          name: collection.name,
          description: collection.description,
          sortOrder: albums.length,
          createdAt: collection.createdAt,
          updatedAt: collection.createdAt,
        ),
      );
      imageIdsByAlbumId[collection.id] = imageIds;
      if (pendingPaths.isNotEmpty) {
        pendingPathsByAlbumId[collection.id] = pendingPaths;
      }
    }

    await _dataSource.albums.importAlbums(
      albums.map(_toRecord).toList(),
      imageIdsByAlbumId,
      pendingPathsByAlbumId: pendingPathsByAlbumId,
    );
    AppLogger.i(
      '从旧集合迁移 ${albums.length} 个相簿，跳过 $skippedImageCount 个无效引用',
      'AlbumImport',
    );
  }

  static GalleryAlbumRecord _toRecord(GalleryAlbum album) {
    return GalleryAlbumRecord(
      id: album.id,
      name: album.name,
      description: album.description,
      parentId: album.parentId,
      sortOrder: album.sortOrder,
      coverPath: album.coverPath,
      pendingPaths: album.pendingPaths,
      createdAt: album.createdAt,
      updatedAt: album.updatedAt,
      imageCount: album.imageCount,
    );
  }
}
