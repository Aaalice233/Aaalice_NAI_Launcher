import 'package:flutter/material.dart';

/// Empty state view for Vibe library
/// Vibe库空状态视图
class VibeLibraryEmptyView extends StatelessWidget {
  /// Title text
  /// 标题文本
  final String title;

  /// Subtitle text
  /// 副标题文本
  final String subtitle;

  /// Icon name to display (mapped to actual IconData in build)
  /// 显示的图标名称（在build中映射为实际IconData）
  final String iconName;

  const VibeLibraryEmptyView({
    super.key,
    this.title = 'Vibe库为空',
    this.subtitle = '从生成页面保存Vibe到库中',
    this.iconName = 'auto_awesome_outlined',
  });

  /// 将图标名称映射为 IconData
  IconData _getIconData(String name) {
    assert(
      name == 'search_off' ||
          name == 'favorite_border' ||
          name == 'folder_outlined' ||
          name == 'auto_awesome_outlined',
      '未知的图标名称: $name。请使用有效的图标名称。',
    );
    return switch (name) {
      'search_off' => Icons.search_off,
      'favorite_border' => Icons.favorite_border,
      'folder_outlined' => Icons.folder_outlined,
      'auto_awesome_outlined' => Icons.auto_awesome_outlined,
      _ => Icons.auto_awesome_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconData(iconName),
            size: 64,
            color: theme.colorScheme.outline.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
