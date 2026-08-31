import 'package:freezed_annotation/freezed_annotation.dart';

part 'gallery_album.freezed.dart';
part 'gallery_album.g.dart';

/// 图库逻辑相簿
///
/// 相簿是图片的引用集合（一图可属多个相簿），不改变物理文件位置；
/// 与「收藏」不同，收藏是单张图片的布尔标记并作为系统相簿展示。
/// 支持无限层级嵌套（parentId），树算法与 GalleryCategory 的扩展保持一致。
@freezed
class GalleryAlbum with _$GalleryAlbum {
  const factory GalleryAlbum({
    /// 唯一标识
    required String id,

    /// 相簿名称
    required String name,

    /// 描述
    String? description,

    /// 父相簿ID（null 表示根级相簿）
    String? parentId,

    /// 排序顺序
    @Default(0) int sortOrder,

    /// 封面图片路径（相对图库根目录）
    String? coverPath,

    /// 图片数量（含子相簿去重）
    @Default(0) int imageCount,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,
  }) = _GalleryAlbum;

  factory GalleryAlbum.fromJson(Map<String, dynamic> json) =>
      _$GalleryAlbumFromJson(json);
}

/// 相簿列表树工具
///
/// 算法与 GalleryCategoryListExtension 保持一致语义。
extension GalleryAlbumListExtension on List<GalleryAlbum> {
  /// 按 id 查找
  GalleryAlbum? findById(String id) {
    for (final album in this) {
      if (album.id == id) return album;
    }
    return null;
  }

  /// 根级相簿
  List<GalleryAlbum> get rootAlbums =>
      where((album) => album.parentId == null).toList();

  /// 指定父级的子相簿（已按 sortOrder 排序）
  List<GalleryAlbum> getChildren(String parentId) =>
      where((album) => album.parentId == parentId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// 构建父级 -> 子级列表的树映射
  Map<String?, List<GalleryAlbum>> buildTree() {
    final tree = <String?, List<GalleryAlbum>>{};
    for (final album in this) {
      tree.putIfAbsent(album.parentId, () => []).add(album);
    }
    for (final children in tree.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return tree;
  }

  /// 移动 albumId 到 newParentId 是否会形成循环引用
  bool wouldCreateCycle(String albumId, String? newParentId) {
    if (newParentId == null) return false;
    if (albumId == newParentId) return true;

    String? currentId = newParentId;
    while (currentId != null) {
      if (currentId == albumId) return true;
      currentId = findById(currentId)?.parentId;
    }
    return false;
  }

  /// 所有后代相簿 id
  Set<String> getDescendantIds(String albumId) {
    final descendants = <String>{};
    final queue = getChildren(albumId).map((album) => album.id).toList();

    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (descendants.add(id)) {
        queue.addAll(getChildren(id).map((album) => album.id));
      }
    }

    return descendants;
  }

  /// 相簿及全部后代的 id 集合（含自身）
  Set<String> getWithDescendantIds(String albumId) => {
    albumId,
    ...getDescendantIds(albumId),
  };

  /// 相簿的层级路径名称，如「角色 / 猫娘」
  String getPathString(String albumId, {String separator = ' / '}) {
    final names = <String>[];
    String? currentId = albumId;
    while (currentId != null) {
      final album = findById(currentId);
      if (album == null) break;
      names.insert(0, album.name);
      currentId = album.parentId;
    }
    return names.join(separator);
  }
}
