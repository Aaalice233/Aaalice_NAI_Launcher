/// 空状态信息模型
///
/// 用于显示 Vibe 库空状态时的提示信息，包括标题、副标题和图标名称
/// 注意：使用 String 图标名称而非 IconData，避免数据层依赖 UI 框架
class EmptyStateInfo {
  /// 标题文本
  final String title;

  /// 副标题文本（可选）
  final String? subtitle;

  /// 图标名称（由展示层映射为实际的 IconData）
  final String iconName;

  const EmptyStateInfo({
    required this.title,
    this.subtitle,
    required this.iconName,
  });

  /// 创建搜索无结果的空状态信息
  factory EmptyStateInfo.searchNoResults() {
    return const EmptyStateInfo(
      title: '未找到匹配的 Vibe',
      subtitle: '尝试其他关键词',
      iconName: 'search_off',
    );
  }

  /// 创建收藏无结果的空状态信息
  factory EmptyStateInfo.noFavorites() {
    return const EmptyStateInfo(
      title: '暂无收藏的 Vibe',
      subtitle: '点击心形图标收藏 Vibe',
      iconName: 'favorite_border',
    );
  }

  /// 创建分类无结果的空状态信息
  factory EmptyStateInfo.noItemsInCategory() {
    return const EmptyStateInfo(
      title: '该分类下暂无 Vibe',
      subtitle: '尝试切换到"全部 Vibe"查看所有内容',
      iconName: 'folder_outlined',
    );
  }

  /// 创建默认无结果的空状态信息
  factory EmptyStateInfo.defaultEmpty() {
    return const EmptyStateInfo(
      title: '无匹配结果',
      subtitle: null,
      iconName: 'search_off',
    );
  }

  EmptyStateInfo copyWith({
    String? title,
    String? subtitle,
    String? iconName,
  }) {
    return EmptyStateInfo(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
    );
  }

  @override
  String toString() {
    return 'EmptyStateInfo(title: $title, subtitle: $subtitle, iconName: $iconName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmptyStateInfo &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.iconName == iconName;
  }

  @override
  int get hashCode => Object.hash(title, subtitle, iconName);
}
