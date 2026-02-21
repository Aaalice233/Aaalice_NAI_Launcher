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

  /// Icon to display
  /// 显示的图标
  final IconData icon;

  const VibeLibraryEmptyView({
    super.key,
    this.title = 'Vibe库为空',
    this.subtitle = '从生成页面保存Vibe到库中',
    this.icon = Icons.auto_awesome_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
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
