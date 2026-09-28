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

  /// 旧集合迁移时靠「重挂到当前图库根目录」才救回来的成员数量
  ///
  /// 【偏离上游】上游 v4.2.1 没有这个概念：旧集合成员只按记录里的绝对路径
  /// 查一次 `getImageIdByPath`、再 `File(绝对路径).exists()`，两者都失败就
  /// `skippedImageCount++` 并静默丢弃。iOS 每次覆盖安装都会换掉应用容器 UUID
  /// （/var/mobile/Containers/Data/Application/「UUID」/...），旧集合里记的
  /// 绝对路径必然全部失效，用户已有的集合会在迁移那一刻整体丢成员且只打一行
  /// 日志。这里加一层「按路径后缀重挂到当前图库根目录」的回退匹配来兜住它。
  int rebasedImageCount = 0;

  /// 旧根目录相对当前根目录多出来的前缀段数（探测一次后复用）
  int? _legacyRootSegmentCount;

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
        final match = await _resolveLegacyMember(imagePath, rootPath);
        if (match.rebased) rebasedImageCount++;
        if (match.imageId != null) {
          imageIds.add(match.imageId!);
        } else if (match.pendingRelativePath != null) {
          pendingPaths.add(match.pendingRelativePath!);
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
      '从旧集合迁移 ${albums.length} 个相簿，'
          '重挂 $rebasedImageCount 个换过容器路径的成员，'
          '跳过 $skippedImageCount 个无效引用',
      'AlbumImport',
    );
  }

  /// 解析一条旧集合成员（绝对路径）在当前设备上的归属。
  ///
  /// 【偏离上游】上游只做前两步（原样查库 / 原样查文件）。第三步的后缀重挂是
  /// 我们为 iOS 加的：覆盖安装后容器 UUID 变化，旧绝对路径的前缀失效，但
  /// 「图库根目录以下的那段相对路径」不变，所以把旧路径的最长可用后缀重新
  /// 挂到当前根目录上即可还原成员。从最长后缀开始试，命中即止，把同名文件
  /// 误选的概率压到最低（纯 basename 匹配是最后一档）。
  Future<({int? imageId, String? pendingRelativePath, bool rebased})>
  _resolveLegacyMember(String legacyPath, String? rootPath) async {
    // 1) 原样匹配：同机升级与桌面端走这条，行为与上游一致
    final directId = await _dataSource.getImageIdByPath(legacyPath);
    if (directId != null) {
      return (imageId: directId, pendingRelativePath: null, rebased: false);
    }

    final root = rootPath == null || rootPath.isEmpty ? null : rootPath;

    // 2) 文件还在原处但尚未索引：保留为 pending，扫描完成后补绑
    if (await File(legacyPath).exists()) {
      final relative = root == null
          ? null
          : GalleryAlbumSidecarService.toRelativePath(root, legacyPath);
      // 转换失败说明文件在图库外，上游同样按跳过处理
      return (imageId: null, pendingRelativePath: relative, rebased: false);
    }

    if (root == null) {
      return (imageId: null, pendingRelativePath: null, rebased: false);
    }

    // 3) 回退：把旧绝对路径的尾段重挂到当前图库根目录
    final rebased = await _rebaseOntoRoot(legacyPath, root);
    if (rebased == null) {
      return (imageId: null, pendingRelativePath: null, rebased: false);
    }
    final rebasedId = await _dataSource.getImageIdByPath(rebased.absolutePath);
    return (
      imageId: rebasedId,
      pendingRelativePath: rebasedId == null ? rebased.relativePath : null,
      rebased: true,
    );
  }

  /// 按「最长后缀优先」把旧绝对路径重挂到当前图库根目录；都对不上返回 null
  Future<({String relativePath, String absolutePath})?> _rebaseOntoRoot(
    String legacyPath,
    String rootPath,
  ) async {
    final segments = _splitPathSegments(legacyPath);
    if (segments.isEmpty) return null;

    // 同一次迁移里旧根目录只有一个，探测出来之后直接复用
    final cached = _legacyRootSegmentCount;
    if (cached != null && cached < segments.length) {
      final candidate = _candidateFor(rootPath, segments, cached);
      if (candidate != null && await File(candidate.absolutePath).exists()) {
        return candidate;
      }
    }

    for (var skip = 0; skip < segments.length; skip++) {
      if (skip == cached) continue;
      final candidate = _candidateFor(rootPath, segments, skip);
      if (candidate == null) continue;
      if (await File(candidate.absolutePath).exists()) {
        _legacyRootSegmentCount = skip;
        return candidate;
      }
    }
    return null;
  }

  static ({String relativePath, String absolutePath})? _candidateFor(
    String rootPath,
    List<String> segments,
    int skip,
  ) {
    final relative = segments.sublist(skip).join('/');
    if (!GalleryAlbumSidecarService.isValidRelativeMemberPath(relative)) {
      return null;
    }
    return (
      relativePath: relative,
      absolutePath: GalleryAlbumSidecarService.toAbsolutePath(
        rootPath,
        relative,
      ),
    );
  }

  /// 同时吃 '/' 与 '\\'：旧集合可能是在另一个平台上写下的
  static List<String> _splitPathSegments(String path) => path
      .split(RegExp(r'[\\/]+'))
      .where((segment) => segment.isNotEmpty && segment != '.')
      .toList();

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
