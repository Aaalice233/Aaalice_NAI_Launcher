import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'tag_library_category.freezed.dart';
part 'tag_library_category.g.dart';

/// 词库分类数据模型
///
/// 用于组织词库条目，支持无限层级嵌套
@freezed
class TagLibraryCategory with _$TagLibraryCategory {
  const TagLibraryCategory._();

  const factory TagLibraryCategory({
    /// 唯一标识
    required String id,

    /// 分类名称
    required String name,

    /// 父分类ID (null 表示根级分类)
    String? parentId,

    /// 排序顺序
    @Default(0) int sortOrder,

    /// 创建时间
    required DateTime createdAt,
  }) = _TagLibraryCategory;

  factory TagLibraryCategory.fromJson(Map<String, dynamic> json) =>
      _$TagLibraryCategoryFromJson(json);

  /// 创建新分类
  factory TagLibraryCategory.create({
    required String name,
    String? parentId,
    int sortOrder = 0,
  }) {
    return TagLibraryCategory(
      id: const Uuid().v4(),
      name: name.trim(),
      parentId: parentId,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
    );
  }

  /// 是否为根级分类
  bool get isRoot => parentId == null;

  /// 显示名称
  String get displayName => name.isNotEmpty ? name : '未命名分类';

  /// 更新名称
  TagLibraryCategory updateName(String newName) {
    return copyWith(name: newName.trim());
  }

  /// 移动到新父分类
  TagLibraryCategory moveTo(String? newParentId) {
    return copyWith(parentId: newParentId);
  }
}

/// 词库分类列表扩展
extension TagLibraryCategoryListExtension on List<TagLibraryCategory> {
  /// 获取根级分类
  List<TagLibraryCategory> get rootCategories =>
      where((c) => c.parentId == null).toList();

  /// 获取指定父分类的子分类
  List<TagLibraryCategory> getChildren(String parentId) =>
      where((c) => c.parentId == parentId).toList();

  /// 按排序顺序排列
  List<TagLibraryCategory> sortedByOrder() {
    final sorted = [...this];
    sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return sorted;
  }

  /// 按名称排序
  List<TagLibraryCategory> sortedByName() {
    final sorted = [...this];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  /// 构建分类树
  Map<String?, List<TagLibraryCategory>> buildTree() {
    final tree = <String?, List<TagLibraryCategory>>{};
    for (final category in this) {
      final parentId = category.parentId;
      tree.putIfAbsent(parentId, () => []).add(category);
    }
    for (final children in tree.values) {
      children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    return tree;
  }

  /// 获取分类路径
  List<TagLibraryCategory> getPath(String categoryId) {
    final path = <TagLibraryCategory>[];
    String? currentId = categoryId;

    while (currentId != null) {
      final category = firstWhere(
        (c) => c.id == currentId,
        orElse: () => throw ArgumentError('分类不存在: $currentId'),
      );
      path.insert(0, category);
      currentId = category.parentId;
    }

    return path;
  }

  /// 获取分类路径字符串
  String getPathString(String categoryId, {String separator = ' / '}) {
    try {
      return getPath(categoryId).map((c) => c.displayName).join(separator);
    } catch (_) {
      return '';
    }
  }

  /// 检查是否存在循环引用
  bool wouldCreateCycle(String categoryId, String? newParentId) {
    if (newParentId == null) return false;
    if (categoryId == newParentId) return true;

    String? currentId = newParentId;
    while (currentId != null) {
      if (currentId == categoryId) return true;
      final category = cast<TagLibraryCategory?>().firstWhere(
        (c) => c?.id == currentId,
        orElse: () => null,
      );
      currentId = category?.parentId;
    }

    return false;
  }

  /// 获取所有后代分类ID
  Set<String> getDescendantIds(String categoryId) {
    final descendants = <String>{};
    final queue = getChildren(categoryId).map((c) => c.id).toList();

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      if (descendants.add(id)) {
        queue.addAll(getChildren(id).map((c) => c.id));
      }
    }

    return descendants;
  }

  /// 更新排序顺序
  List<TagLibraryCategory> reindex() {
    return asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();
  }

  /// 搜索分类
  List<TagLibraryCategory> search(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where((c) => c.name.toLowerCase().contains(lowerQuery)).toList();
  }
}
