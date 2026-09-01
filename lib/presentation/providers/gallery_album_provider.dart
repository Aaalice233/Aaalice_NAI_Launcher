import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/datasources/gallery_data_source.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/gallery_album.dart';
import '../../data/models/gallery/gallery_tree_drop_slot.dart';
import '../../data/repositories/gallery_folder_repository.dart';
import '../../data/services/gallery/gallery_album_sidecar_service.dart';
import 'gallery_category_provider.dart';
import 'local_gallery_provider.dart';

part 'gallery_album_provider.g.dart';

/// 相簿状态
class GalleryAlbumState {
  /// 全部相簿（树形展示顺序）
  final List<GalleryAlbum> albums;

  /// 当前选中的相簿（null=全部，'favorites'=收藏相簿）
  final String? selectedAlbumId;

  final bool isLoading;

  final String? error;

  const GalleryAlbumState({
    this.albums = const [],
    this.selectedAlbumId,
    this.isLoading = false,
    this.error,
  });

  GalleryAlbumState copyWith({
    List<GalleryAlbum>? albums,
    String? selectedAlbumId,
    bool clearSelectedAlbumId = false,
    bool? isLoading,
    bool clearError = false,
    String? error,
  }) {
    return GalleryAlbumState(
      albums: albums ?? this.albums,
      selectedAlbumId: clearSelectedAlbumId
          ? null
          : (selectedAlbumId ?? this.selectedAlbumId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 相簿状态管理
///
/// 相簿是逻辑引用集合：加入/移出不移动物理文件；
/// 变更后节流导出 sidecar（.gallery_albums.json）跟随图库目录。
@Riverpod(keepAlive: true)
class GalleryAlbumNotifier extends _$GalleryAlbumNotifier {
  final GalleryDataSource _dataSource = GalleryDataSource();
  final GalleryAlbumSidecarService _sidecarService =
      GalleryAlbumSidecarService();

  Timer? _sidecarExportTimer;
  late Future<void> _initialLoad;

  @override
  GalleryAlbumState build() {
    ref.onDispose(() => _sidecarExportTimer?.cancel());
    _initialLoad = Future<void>.microtask(_load);
    return const GalleryAlbumState(isLoading: true);
  }

  Future<void> whenLoaded() => _initialLoad;

  GalleryAlbumRepository get _albums => _dataSource.albums;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final records = await _albums.getAlbums();
      state = state.copyWith(
        albums: [
          for (final record in records)
            GalleryAlbum(
              id: record.id,
              name: record.name,
              description: record.description,
              parentId: record.parentId,
              sortOrder: record.sortOrder,
              coverPath: record.coverPath,
              pendingPaths: record.pendingPaths,
              imageCount: record.imageCount,
              createdAt: record.createdAt,
              updatedAt: record.updatedAt,
            ),
        ],
        isLoading: false,
      );
    } catch (e) {
      AppLogger.e('加载相簿失败', e, null, 'GalleryAlbum');
      state = state.copyWith(isLoading: false, error: '加载相簿失败: $e');
    }
  }

  Future<void> refresh() => _load();

  /// 仅清空选中状态（不联动图库过滤；由分类选择等互斥场景使用）
  void clearSelection() {
    if (state.selectedAlbumId == null) return;
    state = state.copyWith(clearSelectedAlbumId: true);
  }

  /// 选择相簿并联动图库过滤（null=全部，'favorites'=收藏相簿）
  Future<void> selectAlbum(String? albumId) async {
    state = state.copyWith(
      selectedAlbumId: albumId,
      clearSelectedAlbumId: albumId == null,
    );
    // 相簿与分类互斥：选相簿时退出分类选中状态
    if (albumId != null) {
      ref.read(galleryCategoryNotifierProvider.notifier).selectCategory(null);
    }
    final gallery = ref.read(localGalleryNotifierProvider.notifier);
    if (albumId == 'favorites') {
      await gallery.setSelectedCategory(null, null);
      await gallery.setShowFavoritesOnly(true);
    } else if (albumId != null) {
      await gallery.setShowFavoritesOnly(false);
      await gallery.setSelectedCategory(null, null);
      await gallery.setSelectedAlbum(albumId);
    } else {
      await gallery.setShowFavoritesOnly(false);
      await gallery.setSelectedAlbum(null);
    }
  }

  /// 创建相簿
  Future<bool> createAlbum(String name, {String? parentId}) async {
    try {
      await _albums.createAlbum(name: name.trim(), parentId: parentId);
      await _load();
      _scheduleSidecarExport();
      return true;
    } catch (e) {
      AppLogger.e('创建相簿失败', e, null, 'GalleryAlbum');
      return false;
    }
  }

  /// 重命名相簿
  Future<bool> renameAlbum(String albumId, String newName) async {
    final success = await _albums.renameAlbum(albumId, newName.trim());
    if (success) {
      await _load();
      _scheduleSidecarExport();
    }
    return success;
  }

  /// 按拖放槽位移动相簿（child=移入目标；before/after=同级或跨层排序，
  /// 跨层时即“上移一级”），成功后刷新并导出 sidecar
  Future<bool> moveAlbumToSlot(
    String albumId,
    String targetId,
    GalleryTreeDropSlot slot,
  ) async {
    final changed = await _albums.moveAlbumToSlot(
      albumId: albumId,
      targetId: targetId,
      slot: slot,
    );
    if (changed) {
      await _load();
      _scheduleSidecarExport();
    }
    return changed;
  }

  /// 移动相簿到新父级（含防环校验）
  Future<bool> moveAlbum(String albumId, String? newParentId) async {
    if (newParentId != null &&
        state.albums.wouldCreateCycle(albumId, newParentId)) {
      return false;
    }
    final success = await _albums.moveAlbum(albumId, newParentId);
    if (success) {
      await _load();
      _scheduleSidecarExport();
    }
    return success;
  }

  /// 删除相簿（子相簿提升为根级；成员文件不受影响）
  Future<bool> deleteAlbum(String albumId) async {
    final success = await _albums.deleteAlbum(albumId);
    if (success) {
      if (state.selectedAlbumId == albumId) {
        await selectAlbum(null);
      }
      await _load();
      _scheduleSidecarExport();
    }
    return success;
  }

  /// 设置封面
  Future<bool> setAlbumCover(String albumId, String? coverPath) async {
    final success = await _albums.updateAlbumCover(albumId, coverPath);
    if (success) {
      await _load();
      _scheduleSidecarExport();
    }
    return success;
  }

  /// 按文件路径把图片加入相簿，返回新增成员数
  Future<int> addImagesByPaths(String albumId, List<String> paths) async {
    if (paths.isEmpty) return 0;
    final added = await _addPathsToAlbums({albumId: paths});
    if (added > 0) {
      await _load();
      _scheduleSidecarExport();
    }
    return added;
  }

  /// 按文件路径把图片移出相簿，返回移除数
  Future<int> removeImagesByPaths(String albumId, List<String> paths) async {
    if (paths.isEmpty) return 0;
    final idMap = await _dataSource.getImageIdsByPaths(paths);
    final imageIds = idMap.values.whereType<int>().toList();
    final removed = await _albums.removeImagesFromAlbum(albumId, imageIds);
    if (removed > 0) {
      await _load();
      _scheduleSidecarExport();
      // 当前浏览的正是该相簿时，过滤视图需立即反映成员变化
      await ref
          .read(localGalleryNotifierProvider.notifier)
          .refresh(scan: false);
    }
    return removed;
  }

  Future<int> _addPathsToAlbums(
    Map<String, List<String>> pathsByAlbumId,
  ) async {
    var total = 0;
    for (final entry in pathsByAlbumId.entries) {
      final idMap = await _dataSource.getImageIdsByPaths(entry.value);
      final imageIds = idMap.values.whereType<int>().toList();
      total += await _albums.addImagesToAlbum(entry.key, imageIds);
    }
    return total;
  }

  /// 节流导出 sidecar：短时间内的多次变更合并为一次写盘
  void _scheduleSidecarExport() {
    _sidecarExportTimer?.cancel();
    _sidecarExportTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(exportSidecar());
    });
  }

  Future<void> exportSidecar() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath == null || rootPath.isEmpty) return;

      final memberPaths = await _albums.getAllAlbumMemberPaths();
      final albums = [
        for (final album in state.albums)
          album.copyWith(
            imageCount: 0, // sidecar 不持久化派生计数
            // 封面同样以相对路径存储；不在图库内则清除，避免泄露设备路径
            coverPath: album.coverPath == null
                ? null
                : GalleryAlbumSidecarService.toRelativePath(
                    rootPath,
                    album.coverPath!,
                  ),
          ),
      ];
      final imagePathsByAlbumId = <String, List<String>>{};
      for (final album in albums) {
        final exported = <String>[
          // 已解析成员转为相对路径；不在图库根目录内的路径跳过并记录，
          // 绝不原样回写设备绝对路径
          for (final path in memberPaths[album.id] ?? const <String>[])
            if (GalleryAlbumSidecarService.toRelativePath(rootPath, path)
                case final relative?)
              relative,
          // 尚未绑定的成员路径原样保留，等待图库索引就绪后补绑
          ...album.pendingPaths,
        ];
        imagePathsByAlbumId[album.id] = exported;
      }
      await _sidecarService.write(
        rootPath,
        GalleryAlbumSidecar(
          albums: albums,
          imagePathsByAlbumId: imagePathsByAlbumId,
        ),
      );
    } catch (e) {
      AppLogger.e('导出相簿 sidecar 失败', e, null, 'GalleryAlbum');
    }
  }

  /// 立即导出 sidecar（取消节流），供图片物理移动等改变成员路径的
  /// 流程在完成后调用，保证跨设备恢复时引用仍然有效。
  Future<void> exportSidecarNow() async {
    _sidecarExportTimer?.cancel();
    await exportSidecar();
  }
}
