import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/gallery/gallery_folder.dart';
import '../../data/repositories/gallery_folder_repository.dart';

part 'gallery_folder_provider.g.dart';

/// 文件夹状态
class GalleryFolderState {
  /// 文件夹列表
  final List<GalleryFolder> folders;

  /// 当前选中的文件夹ID（null 表示"全部"）
  final String? selectedFolderId;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 根目录图片总数
  final int totalImageCount;

  const GalleryFolderState({
    this.folders = const [],
    this.selectedFolderId,
    this.isLoading = false,
    this.error,
    this.totalImageCount = 0,
  });

  GalleryFolderState copyWith({
    List<GalleryFolder>? folders,
    String? selectedFolderId,
    bool? isLoading,
    String? error,
    int? totalImageCount,
    bool clearSelectedFolderId = false,
    bool clearError = false,
  }) {
    return GalleryFolderState(
      folders: folders ?? this.folders,
      selectedFolderId: clearSelectedFolderId
          ? null
          : (selectedFolderId ?? this.selectedFolderId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      totalImageCount: totalImageCount ?? this.totalImageCount,
    );
  }

  /// 获取当前选中的文件夹
  GalleryFolder? get selectedFolder {
    if (selectedFolderId == null) return null;
    try {
      return folders.firstWhere((f) => f.id == selectedFolderId);
    } catch (_) {
      return null;
    }
  }

  /// 是否选中"全部"
  bool get isAllSelected => selectedFolderId == null;
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
      // 启动文件夹监听
      await _repository.startWatching(onChanged: _onFoldersChanged);
      // 初始加载
      await _loadFolders();
    } catch (e) {
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

  /// 加载文件夹列表
  Future<void> _loadFolders() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final folders = await _repository.scanFolders();
      final totalCount = await _repository.getTotalImageCount();

      state = state.copyWith(
        folders: folders,
        totalImageCount: totalCount,
        isLoading: false,
      );
    } catch (e) {
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

  /// 选择文件夹
  ///
  /// [folderId] 文件夹ID，传 null 表示选择"全部"
  void selectFolder(String? folderId) {
    if (folderId == null) {
      state = state.copyWith(clearSelectedFolderId: true);
    } else {
      state = state.copyWith(selectedFolderId: folderId);
    }
  }

  /// 创建新文件夹
  ///
  /// [name] 文件夹名称
  /// 返回创建的文件夹，如果失败返回 null
  Future<GalleryFolder?> createFolder(String name) async {
    final folder = await _repository.createFolder(name);
    if (folder != null) {
      // 刷新列表
      await _loadFolders();
    }
    return folder;
  }

  /// 删除文件夹
  ///
  /// [folderPath] 文件夹路径
  /// [recursive] 是否递归删除
  Future<bool> deleteFolder(String folderPath, {bool recursive = false}) async {
    final success =
        await _repository.deleteFolder(folderPath, recursive: recursive);
    if (success) {
      // 如果删除的是当前选中的文件夹，切换到"全部"
      final currentFolder = state.selectedFolder;
      if (currentFolder?.path == folderPath) {
        state = state.copyWith(clearSelectedFolderId: true);
      }
      // 刷新列表
      await _loadFolders();
    }
    return success;
  }

  /// 重命名文件夹
  Future<GalleryFolder?> renameFolder(String oldPath, String newName) async {
    final folder = await _repository.renameFolder(oldPath, newName);
    if (folder != null) {
      await _loadFolders();
    }
    return folder;
  }

  /// 移动图片到文件夹
  Future<bool> moveImageToFolder(
      String imagePath, String targetFolderPath,) async {
    final success =
        await _repository.moveImageToFolder(imagePath, targetFolderPath);
    if (success) {
      await _loadFolders();
    }
    return success;
  }

  /// 批量移动图片到文件夹
  Future<int> moveImagesToFolder(
      List<String> imagePaths, String targetFolderPath,) async {
    final count =
        await _repository.moveImagesToFolder(imagePaths, targetFolderPath);
    if (count > 0) {
      await _loadFolders();
    }
    return count;
  }

  /// 获取当前选中的文件夹路径
  ///
  /// 返回文件夹路径，如果选中"全部"则返回 null
  String? get selectedFolderPath => state.selectedFolder?.path;
}
