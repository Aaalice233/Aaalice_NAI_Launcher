import 'package:flutter/material.dart';

/// 空状态信息模型
///
/// 用于显示 Vibe 库空状态时的提示信息，包括标题、副标题和图标
class EmptyStateInfo {
  /// 标题文本
  final String title;

  /// 副标题文本（可选）
  final String? subtitle;

  /// 显示的图标
  final IconData icon;

  const EmptyStateInfo({
    required this.title,
    this.subtitle,
    required this.icon,
  });

  /// 创建搜索无结果的空状态信息
  factory EmptyStateInfo.searchNoResults() {
    return const EmptyStateInfo(
      title: '未找到匹配的 Vibe',
      subtitle: '尝试其他关键词',
      icon: Icons.search_off,
    );
  }

  /// 创建收藏无结果的空状态信息
  factory EmptyStateInfo.noFavorites() {
    return const EmptyStateInfo(
      title: '暂无收藏的 Vibe',
      subtitle: '点击心形图标收藏 Vibe',
      icon: Icons.favorite_border,
    );
  }

  /// 创建分类无结果的空状态信息
  factory EmptyStateInfo.noItemsInCategory() {
    return const EmptyStateInfo(
      title: '该分类下暂无 Vibe',
      subtitle: '尝试切换到"全部 Vibe"查看所有内容',
      icon: Icons.folder_outlined,
    );
  }

  /// 创建默认无结果的空状态信息
  factory EmptyStateInfo.defaultEmpty() {
    return const EmptyStateInfo(
      title: '无匹配结果',
      subtitle: null,
      icon: Icons.search_off,
    );
  }

  EmptyStateInfo copyWith({
    String? title,
    String? subtitle,
    IconData? icon,
  }) {
    return EmptyStateInfo(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
    );
  }

  @override
  String toString() {
    return 'EmptyStateInfo(title: $title, subtitle: $subtitle, icon: $icon)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmptyStateInfo &&
        other.title == title &&
        other.subtitle == subtitle &&
        other.icon == icon;
  }

  @override
  int get hashCode => Object.hash(title, subtitle, icon);
}
