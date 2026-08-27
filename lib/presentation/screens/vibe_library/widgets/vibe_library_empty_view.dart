import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// Empty state view for Vibe library
/// Vibe库空状态视图
class VibeLibraryEmptyView extends StatelessWidget {
  /// Title text
  /// 标题文本
  final String? title;

  /// Subtitle text
  /// 副标题文本
  final String? subtitle;

  /// Icon name to display (mapped to actual IconData in build)
  /// 显示的图标名称（在build中映射为实际IconData）
  final String iconName;

  final VoidCallback? onImport;

  const VibeLibraryEmptyView({
    super.key,
    this.title,
    this.subtitle,
    this.iconName = 'auto_awesome_outlined',
    this.onImport,
  });

  /// 将图标名称映射为 IconData
  IconData _getIconData(String name) {
    assert(
      name == 'search_off' ||
          name == 'favorite_border' ||
          name == 'folder_outlined' ||
          name == 'auto_awesome_outlined',
      'Unknown icon name: $name. Use a valid icon name.',
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
    final l10n = context.l10n;
    final resolvedTitle = title ?? l10n.vibeLibrary_empty;
    final resolvedSubtitle =
        subtitle ?? l10n.vibeLibrary_emptySaveFromGenerationHint;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconData(iconName),
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            resolvedTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            resolvedSubtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
          if (onImport != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('vibe-library-empty-import'),
              onPressed: onImport,
              icon: const Icon(Icons.file_download_outlined),
              label: Text(l10n.common_import),
            ),
          ],
        ],
      ),
    );
  }
}
