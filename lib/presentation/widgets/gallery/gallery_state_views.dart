import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/local_gallery_provider.dart';

/// Error state view for gallery
/// 画廊错误状态视图
class GalleryErrorView extends StatelessWidget {
  /// Error message to display
  /// 显示的错误信息
  final String? error;

  /// Callback when retry button is pressed
  /// 重试按钮回调
  final VoidCallback? onRetry;

  const GalleryErrorView({
    super.key,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败: ${error ?? '未知错误'}',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(
              '重试',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading/indexing state view for gallery
/// 画廊加载/索引状态视图
class GalleryLoadingView extends StatelessWidget {
  /// Loading message to display
  /// 显示的加载信息
  final String message;

  const GalleryLoadingView({
    super.key,
    this.message = '索引本地图片中...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state view for gallery
/// 画廊空状态视图
class GalleryEmptyView extends StatelessWidget {
  /// Title text
  /// 标题文本
  final String title;

  /// Subtitle text
  /// 副标题文本
  final String subtitle;

  /// Icon to display
  /// 显示的图标
  final IconData icon;

  const GalleryEmptyView({
    super.key,
    this.title = '暂无本地图片',
    this.subtitle = '生成的图片将保存在此处',
    this.icon = Icons.image_not_supported,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.6 : 1.0),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant
                  .withOpacity(isDark ? 0.7 : 1.0),
            ),
          ),
        ],
      ),
    );
  }
}

/// No results view for gallery (when filters applied)
/// 画廊无结果视图（应用过滤器后）
class GalleryNoResultsView extends ConsumerWidget {
  /// Callback when clear filters button is pressed
  /// 清除过滤按钮回调
  final VoidCallback? onClearFilters;

  const GalleryNoResultsView({
    super.key,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant
                .withOpacity(isDark ? 0.6 : 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '无匹配结果',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onClearFilters ??
                () {
                  ref
                      .read(localGalleryNotifierProvider.notifier)
                      .clearAllFilters();
                },
            icon: const Icon(Icons.filter_alt_off, size: 16),
            label: const Text('清除过滤'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped loading view for gallery
/// 画廊分组加载视图
class GalleryGroupedLoadingView extends StatelessWidget {
  const GalleryGroupedLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '加载分组图片中...',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
