import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'gallery_folder.freezed.dart';
part 'gallery_folder.g.dart';

/// 画廊文件夹模型
///
/// 用于组织画廊图片，支持无限层级嵌套
@freezed
class GalleryFolder with _$GalleryFolder {
  const GalleryFolder._();

  const factory GalleryFolder({
    /// 唯一标识
    required String id,

    /// 文件夹名称
    required String name,

    /// 文件夹完整路径
    required String path,

    /// 父文件夹ID (null 表示根级文件夹)
    String? parentId,

    /// 排序顺序
    @Default(0) int sortOrder,

    /// 图片数量 (包含子文件夹)
    @Default(0) int imageCount,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,
  }) = _GalleryFolder;

  factory GalleryFolder.fromJson(Map<String, dynamic> json) =>
      _$GalleryFolderFromJson(json);

  /// 创建新文件夹
  factory GalleryFolder.create({
    required String name,
    required String path,
    String? parentId,
    int sortOrder = 0,
  }) {
    final now = DateTime.now();
    return GalleryFolder(
      id: const Uuid().v4(),
      name: name.trim(),
      path: path,
      parentId: parentId,
      sortOrder: sortOrder,
      imageCount: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 是否为根级文件夹
  bool get isRoot => parentId == null;

  /// 文件夹是否为空
  bool get isEmpty => imageCount == 0;

  /// 文件夹是否非空
  bool get isNotEmpty => imageCount > 0;

  /// 显示名称
  String get displayName => name.isNotEmpty ? name : '未命名文件夹';

  /// 更新名称
  GalleryFolder updateName(String newName) {
    return copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now(),
    );
  }

  /// 移动到新父文件夹
  GalleryFolder moveTo(String? newParentId, String newPath) {
    return copyWith(
      parentId: newParentId,
      path: newPath,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新文件夹路径
  GalleryFolder updatePath(String newPath) {
    return copyWith(
      path: newPath,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新图片数量
  GalleryFolder updateImageCount(int count) {
    return copyWith(
      imageCount: count,
      updatedAt: DateTime.now(),
    );
  }
}

/// 画廊文件夹列表扩展
extension GalleryFolderListExtension on List<GalleryFolder> {
  /// 获取根级文件夹
  List<GalleryFolder> get rootFolders =>
      where((f) => f.parentId == null).toList();

  /// 获取指定父文件夹的子文件夹
  List<GalleryFolder> getChildren(String parentId) =>
      where((f) => f.parentId == parentId).toList();

  /// 按排序顺序排列
  List<GalleryFolder> sortedByOrder() {
    final sorted = [...this];
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// 按名称排序
  List<GalleryFolder> sortedByName() {
    final sorted = [...this];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  /// 构建文件夹树
  Map<String?, List<GalleryFolder>> buildTree() {
    final tree = <String?, List<GalleryFolder>>{};
    for (final folder in this) {
      final parentId = folder.parentId;
      tree.putIfAbsent(parentId, () => []).add(folder);
    }
    for (final children in tree.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return tree;
  }

  /// 获取文件夹路径
  List<GalleryFolder> getPath(String folderId) {
    final path = <GalleryFolder>[];
    String? currentId = folderId;

    while (currentId != null) {
      final folder = cast<GalleryFolder?>().firstWhere(
        (f) => f?.id == currentId,
        orElse: () => null,
      );
      if (folder == null) break;
      path.insert(0, folder);
      currentId = folder.parentId;
    }

    return path;
  }

  /// 获取文件夹路径字符串
  String getPathString(String folderId, {String separator = ' / '}) {
    try {
      return getPath(folderId).map((f) => f.displayName).join(separator);
    } catch (_) {
      return '';
    }
  }

  /// 检查是否存在循环引用
  bool wouldCreateCycle(String folderId, String? newParentId) {
    if (newParentId == null) return false;
    if (folderId == newParentId) return true;

    String? currentId = newParentId;
    while (currentId != null) {
      if (currentId == folderId) return true;
      final folder = cast<GalleryFolder?>().firstWhere(
        (f) => f?.id == currentId,
        orElse: () => null,
      );
      currentId = folder?.parentId;
    }

    return false;
  }

  /// 获取所有后代文件夹ID
  Set<String> getDescendantIds(String folderId) {
    final descendants = <String>{};
    final queue = getChildren(folderId).map((f) => f.id).toList();

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (descendants.add(id)) {
        queue.addAll(getChildren(id).map((f) => f.id));
      }
    }

    return descendants;
  }

  /// 获取所有后代文件夹
  List<GalleryFolder> getDescendants(String folderId) {
    final descendantIds = getDescendantIds(folderId);
    return where((f) => descendantIds.contains(f.id)).toList();
  }

  /// 更新排序顺序
  List<GalleryFolder> reindex() {
    return asMap()
        .entries
        .map(
          (e) => e.value.copyWith(
            sortOrder: e.key,
            updatedAt: DateTime.now(),
          ),
        )
        .toList();
  }

  /// 搜索文件夹
  List<GalleryFolder> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where((f) => f.name.toLowerCase().contains(lowerQuery)).toList();
  }

  /// 根据ID查找文件夹
  GalleryFolder? findById(String id) {
    try {
      return firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取文件夹的完整路径
  String? getFullPath(String folderId, String rootPath) {
    final folder = findById(folderId);
    if (folder == null) return null;
    return '$rootPath/${folder.path}';
  }
}
