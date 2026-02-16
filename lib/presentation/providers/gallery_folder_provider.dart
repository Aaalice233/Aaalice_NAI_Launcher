import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/gallery_folder.dart';
import '../../data/repositories/gallery_folder_repository.dart';

part 'gallery_folder_provider.freezed.dart';
part 'gallery_folder_provider.g.dart';

/// 文件夹视图模式
enum FolderViewMode {
  /// 标签页视图（水平滚动标签）
  tabs,

  /// 树形视图（层级结构，支持嵌套）
  tree,
}

/// 文件夹状态
@freezed
class GalleryFolderState with _$GalleryFolderState {
  const factory GalleryFolderState({
    /// 所有文件夹
    @Default([]) List<GalleryFolder> folders,

    /// 当前选中的文件夹ID（null表示全部）
    String? selectedFolderId,

    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 是否正在同步
    @Default(false) bool isSyncing,

    /// 错误信息
    String? error,

    /// 根目录图片总数
    @Default(0) int totalImageCount,

    /// 文件夹视图模式
    @Default(FolderViewMode.tree) FolderViewMode viewMode,
  }) = _GalleryFolderState;

  const GalleryFolderState._();

  /// 获取当前选中的文件夹
  GalleryFolder? get selectedFolder {
    if (selectedFolderId == null) return null;
    return folders.findById(selectedFolderId!);
  }

  /// 是否选中"全部"
  bool get isAllSelected => selectedFolderId == null;

  /// 根级文件夹
  List<GalleryFolder> get rootFolders => folders.rootFolders;

  /// 获取文件夹树
  Map<String?, List<GalleryFolder>> get folderTree => folders.buildTree();

  /// 获取当前选中文件夹的路径
  String? get selectedFolderPath => selectedFolder?.path;
}

/// 文件夹状态管理
@riverpod
class GalleryFolderNotifier extends _$GalleryFolderNotifier {
  final _repository = GalleryFolderRepository.instance;

  @override
  GalleryFolderState build() {
    // 清理时停止监听
    ref.onDispose(() {
      _repository.stopWatching();
    });

    // 延迟初始化，避免阻塞 UI
    Future.microtask(() async {
      await _initAsync();
    });

    return const GalleryFolderState(isLoading: true);
  }

  /// 异步初始化
  Future<void> _initAsync() async {
    try {
      // 加载视图模式
      await _loadViewMode();
      // 启动文件夹监听
      await _repository.startWatching(onChanged: _onFoldersChanged);
      // 初始加载
      await _loadFolders();
    } catch (e) {
      AppLogger.e('初始化文件夹失败', e);
      state = state.copyWith(
        isLoading: false,
        error: '初始化失败: $e',
      );
    }
  }

  /// 文件夹变化回调
  void _onFoldersChanged() {
    _loadFolders();
  }

  /// 加载文件夹列表（递归扫描）
  Future<void> _loadFolders() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final folders = await _repository.scanFoldersRecursively();
      final totalCount = await _repository.getTotalImageCount();

      state = state.copyWith(
        folders: folders,
        totalImageCount: totalCount,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.e('加载文件夹失败', e);
      state = state.copyWith(
        isLoading: false,
        error: '加载文件夹失败: $e',
      );
    }
  }

  /// 刷新文件夹列表
  Future<void> refresh() async {
    await _loadFolders();
  }

  /// 与文件系统同步
  Future<void> syncWithFileSystem() async {
    state = state.copyWith(isSyncing: true, error: null);

    try {
      // 重新扫描获取最新文件夹结构
      final folders = await _repository.scanFoldersRecursively();
      final totalCount = await _repository.getTotalImageCount();

      state = state.copyWith(
        folders: folders,
        totalImageCount: totalCount,
        isSyncing: false,
      );
    } catch (e) {
      AppLogger.e('同步文件夹失败', e);
      state = state.copyWith(
        isSyncing: false,
        error: '同步文件夹失败: $e',
      );
    }
  }

  /// 选择文件夹
  ///
  /// [folderId] 文件夹ID，传 null 表示选择"全部"
  void selectFolder(String? folderId) {
    state = state.copyWith(selectedFolderId: folderId);
  }

  /// 创建新文件夹
  ///
  /// [name] 文件夹名称
  /// [parentId] 父文件夹ID（null表示创建根级文件夹）
  /// 返回创建的文件夹，如果失败返回 null
  Future<GalleryFolder?> createFolder(
    String name, {
    String? parentId,
  }) async {
    try {
      final folder = await _repository.createNestedFolder(
        name: name,
        parentId: parentId,
        existingFolders: state.folders,
      );

      if (folder != null) {
        final updatedFolders = [...state.folders, folder];
        state = state.copyWith(folders: updatedFolders);
        return folder;
      }

      return null;
    } catch (e) {
      AppLogger.e('创建文件夹失败', e);
      state = state.copyWith(error: '创建文件夹失败: $e');
      return null;
    }
  }

  /// 重命名文件夹
  Future<GalleryFolder?> renameFolder(
    String folderId,
    String newName,
  ) async {
    final folder = state.folders.findById(folderId);
    if (folder == null) {
      state = state.copyWith(error: '文件夹不存在');
      return null;
    }

    try {
      final rootPath = await _repository.getRootPath();
      if (rootPath == null) {
        state = state.copyWith(error: '根路径不存在');
        return null;
      }

      final oldAbsolutePath = '$rootPath/${folder.path}';
      final renamed = await _repository.renameFolder(oldAbsolutePath, newName);

      if (renamed != null) {
        // 更新文件夹列表
        var updatedFolders = state.folders
            .map((f) => f.id == folderId ? renamed : f)
            .toList();

        // 更新所有子文件夹的路径
        final oldPath = folder.path;
        final newPath = renamed.path;
        updatedFolders = _repository.updateDescendantPaths(
          oldPath,
          newPath,
          updatedFolders,
        );

        state = state.copyWith(folders: updatedFolders);
        return renamed;
      }

      return null;
    } catch (e) {
      AppLogger.e('重命名文件夹失败', e);
      state = state.copyWith(error: '重命名文件夹失败: $e');
      return null;
    }
  }

  /// 移动文件夹到新父级
  Future<GalleryFolder?> moveFolder(
    String folderId,
    String? newParentId,
  ) async {
    final folder = state.folders.findById(folderId);
    if (folder == null) {
      state = state.copyWith(error: '文件夹不存在');
      return null;
    }

    // 检查循环引用
    if (newParentId != null &&
        state.folders.wouldCreateCycle(folderId, newParentId)) {
      state = state.copyWith(error: '不能将文件夹移动到其子文件夹下');
      return null;
    }

    try {
      final moved = await _repository.moveFolder(
        folder,
        newParentId,
        state.folders,
      );

      if (moved != null) {
        // 更新文件夹列表
        var updatedFolders = state.folders
            .map((f) => f.id == folderId ? moved : f)
            .toList();

        // 更新所有子文件夹的路径
        final oldPath = folder.path;
        final newPath = moved.path;
        updatedFolders = _repository.updateDescendantPaths(
          oldPath,
          newPath,
          updatedFolders,
        );

        state = state.copyWith(folders: updatedFolders);
        return moved;
      }

      return null;
    } catch (e) {
      AppLogger.e('移动文件夹失败', e);
      state = state.copyWith(error: '移动文件夹失败: $e');
      return null;
    }
  }

  /// 删除文件夹
  ///
  /// [folderId] 文件夹ID
  /// [deleteFolder] 是否删除物理文件夹
  /// [recursive] 是否递归删除子文件夹
  Future<bool> deleteFolder(
    String folderId, {
    bool deleteFolder = true,
    bool recursive = false,
  }) async {
    final folder = state.folders.findById(folderId);
    if (folder == null) {
      state = state.copyWith(error: '文件夹不存在');
      return false;
    }

    // 检查是否有子文件夹
    final children = state.folders.getChildren(folderId);
    if (children.isNotEmpty && !recursive) {
      state = state.copyWith(error: '文件夹包含子文件夹，无法删除');
      return false;
    }

    try {
      if (deleteFolder) {
        final rootPath = await _repository.getRootPath();
        if (rootPath != null) {
          final absolutePath = '$rootPath/${folder.path}';
          final success = await _repository.deleteFolder(
            absolutePath,
            recursive: recursive,
          );
          if (!success) return false;
        }
      }

      // 获取要删除的所有文件夹ID（包括子文件夹）
      final folderIds = {
        folderId,
        if (recursive) ...state.folders.getDescendantIds(folderId),
      };

      // 从列表中移除
      final updatedFolders =
          state.folders.where((f) => !folderIds.contains(f.id)).toList();

      // 如果删除的是当前选中的文件夹，切换到"全部"
      final newSelectedId = state.selectedFolderId == folderId ||
              (state.selectedFolderId != null &&
                  folderIds.contains(state.selectedFolderId))
          ? null
          : state.selectedFolderId;

      state = state.copyWith(
        folders: updatedFolders,
        selectedFolderId: newSelectedId,
      );

      return true;
    } catch (e) {
      AppLogger.e('删除文件夹失败', e);
      state = state.copyWith(error: '删除文件夹失败: $e');
      return false;
    }
  }

  /// 移动图片到文件夹
  Future<String?> moveImageToFolder(
    String imagePath,
    String? folderId,
  ) async {
    if (folderId == null) {
      // 移动到根目录
      try {
        final rootPath = await _repository.getRootPath();
        if (rootPath == null) return null;

        final success = await _repository.moveImageToFolder(imagePath, rootPath);
        return success ? imagePath : null;
      } catch (e) {
        AppLogger.e('移动图片到根目录失败', e);
        return null;
      }
    }

    final folder = state.folders.findById(folderId);
    if (folder == null) {
      state = state.copyWith(error: '文件夹不存在');
      return null;
    }

    try {
      final rootPath = await _repository.getRootPath();
      if (rootPath == null) return null;

      final targetPath = '$rootPath/${folder.path}';
      final success = await _repository.moveImageToFolder(imagePath, targetPath);

      if (success) {
        // 刷新文件夹图片数量
        await _updateFolderImageCounts();
      }

      return success ? '$targetPath/${imagePath.split('/').last}' : null;
    } catch (e) {
      AppLogger.e('移动图片失败', e);
      state = state.copyWith(error: '移动图片失败: $e');
      return null;
    }
  }

  /// 批量移动图片到文件夹
  Future<int> moveImagesToFolder(
    List<String> imagePaths,
    String? folderId,
  ) async {
    if (folderId == null) {
      // 移动到根目录
      try {
        final rootPath = await _repository.getRootPath();
        if (rootPath == null) return 0;

        int count = 0;
        for (final imagePath in imagePaths) {
          if (await _repository.moveImageToFolder(imagePath, rootPath)) {
            count++;
          }
        }
        return count;
      } catch (e) {
        AppLogger.e('批量移动图片到根目录失败', e);
        return 0;
      }
    }

    final folder = state.folders.findById(folderId);
    if (folder == null) {
      state = state.copyWith(error: '文件夹不存在');
      return 0;
    }

    try {
      final rootPath = await _repository.getRootPath();
      if (rootPath == null) return 0;

      final targetPath = '$rootPath/${folder.path}';
      final count = await _repository.moveImagesToFolder(imagePaths, targetPath);

      if (count > 0) {
        // 刷新文件夹图片数量
        await _updateFolderImageCounts();
      }

      return count;
    } catch (e) {
      AppLogger.e('批量移动图片失败', e);
      state = state.copyWith(error: '批量移动图片失败: $e');
      return 0;
    }
  }

  /// 更新所有文件夹的图片数量
  Future<void> _updateFolderImageCounts() async {
    try {
      final updatedFolders = <GalleryFolder>[];

      for (final folder in state.folders) {
        final rootPath = await _repository.getRootPath();
        if (rootPath == null) continue;

        final absolutePath = '$rootPath/${folder.path}';
        final count = await _repository.countImagesRecursively(absolutePath);
        updatedFolders.add(folder.updateImageCount(count));
      }

      state = state.copyWith(folders: updatedFolders);
    } catch (e) {
      AppLogger.e('更新文件夹图片数量失败', e);
    }
  }

  /// 重新排序文件夹
  Future<void> reorderFolders(
    String? parentId,
    int oldIndex,
    int newIndex,
  ) async {
    try {
      // 获取同级文件夹
      final siblings = parentId == null
          ? state.folders.rootFolders.sortedByOrder()
          : state.folders.getChildren(parentId).sortedByOrder();

      if (oldIndex < 0 ||
          oldIndex >= siblings.length ||
          newIndex < 0 ||
          newIndex >= siblings.length) {
        return;
      }

      // 重新排序
      final reordered = [...siblings];
      final item = reordered.removeAt(oldIndex);
      reordered.insert(newIndex, item);

      // 更新排序顺序
      final updatedSiblings = reordered.asMap().entries.map((e) {
        return e.value.copyWith(
          sortOrder: e.key,
          updatedAt: DateTime.now(),
        );
      }).toList();

      // 更新完整文件夹列表
      final updatedFolders = state.folders.map((f) {
        final updated = updatedSiblings.where((s) => s.id == f.id).firstOrNull;
        return updated ?? f;
      }).toList();

      state = state.copyWith(folders: updatedFolders);
    } catch (e) {
      AppLogger.e('重新排序文件夹失败', e);
      state = state.copyWith(error: '重新排序失败: $e');
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取文件夹的完整路径
  String getFolderPath(String folderId) {
    return state.folders.getPathString(folderId);
  }

  /// 获取文件夹及其所有子文件夹的ID
  Set<String> getFolderWithDescendants(String folderId) {
    return {
      folderId,
      ...state.folders.getDescendantIds(folderId),
    };
  }

  /// 设置文件夹视图模式
  Future<void> setFolderViewMode(FolderViewMode mode) async {
    state = state.copyWith(viewMode: mode);

    // 持久化到 SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        StorageKeys.galleryFolderViewMode,
        mode == FolderViewMode.tabs ? 0 : 1,
      );
    } catch (e) {
      AppLogger.e('保存文件夹视图模式失败', e);
    }
  }

  /// 加载文件夹视图模式
  Future<void> _loadViewMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getInt(StorageKeys.galleryFolderViewMode);
      final mode = value == 0 ? FolderViewMode.tabs : FolderViewMode.tree;
      state = state.copyWith(viewMode: mode);
    } catch (e) {
      AppLogger.e('加载文件夹视图模式失败', e);
    }
  }
}

/// 获取当前文件夹视图模式
@riverpod
FolderViewMode folderViewMode(Ref ref) {
  final state = ref.watch(galleryFolderNotifierProvider);
  return state.viewMode;
}
