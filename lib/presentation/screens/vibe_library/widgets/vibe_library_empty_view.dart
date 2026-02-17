import 'package:flutter/material.dart';

/// Vibe库空视图
/// Vibe Library Empty State View
///
/// 当Vibe库中没有任何条目时显示的占位视图
/// Displayed when the Vibe library has no entries
class VibeLibraryEmptyView extends StatelessWidget {
  /// Creates a [VibeLibraryEmptyView] widget.
  const VibeLibraryEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Vibe库为空',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '从生成页面保存Vibe到库中',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
