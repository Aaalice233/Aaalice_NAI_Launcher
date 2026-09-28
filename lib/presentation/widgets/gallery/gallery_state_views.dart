import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/local_gallery_provider.dart';
import '../common/app_state_view.dart';

/// Error state view for gallery
/// 画廊错误状态视图
class GalleryErrorView extends StatelessWidget {
  /// Error message to display
  /// 显示的错误信息
  final String? error;

  /// Callback when retry button is pressed
  /// 重试按钮回调
  final VoidCallback? onRetry;

  const GalleryErrorView({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppStateView.error(
      title: context.l10n.localGallery_loadFailed(
        error ?? context.l10n.localGallery_unknownError,
      ),
      actionLabel: context.l10n.common_retry,
      onAction: onRetry,
    );
  }
}

/// Loading/indexing state view for gallery
/// 画廊加载/索引状态视图
class GalleryLoadingView extends StatelessWidget {
  /// Loading message to display
  /// 显示的加载信息
  final String? message;

  const GalleryLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return AppStateView.loading(
      title: message ?? context.l10n.localGallery_indexingLocalImages,
    );
  }
}

/// Empty state view for gallery
/// 画廊空状态视图
class GalleryEmptyView extends StatelessWidget {
  /// Title text
  /// 标题文本
  final String? title;

  /// Subtitle text
  /// 副标题文本
  final String? subtitle;

  /// Icon to display
  /// 显示的图标
  final IconData icon;

  const GalleryEmptyView({
    super.key,
    this.title,
    this.subtitle,
    this.icon = Icons.image_not_supported,
  });

  @override
  Widget build(BuildContext context) {
    return AppStateView.empty(
      title: title ?? context.l10n.localGallery_emptyTitle,
      message: subtitle ?? context.l10n.localGallery_emptySubtitle,
      icon: icon,
    );
  }
}

/// No results view for gallery (when filters applied)
/// 画廊无结果视图（应用过滤器后）
class GalleryNoResultsView extends ConsumerWidget {
  /// Callback when clear filters button is pressed
  /// 清除过滤按钮回调
  final VoidCallback? onClearFilters;

  /// Custom title text
  /// 自定义标题文本
  final String? title;

  /// Custom subtitle text
  /// 自定义副标题文本
  final String? subtitle;

  /// Custom icon
  /// 自定义图标
  final IconData? icon;

  const GalleryNoResultsView({
    super.key,
    this.onClearFilters,
    this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppStateView.empty(
      title: title ?? context.l10n.localGallery_noMatchingResults,
      message: subtitle,
      icon: icon ?? Icons.search_off,
      actionLabel: context.l10n.localGallery_clearFilters,
      actionIcon: Icons.filter_alt_off,
      onAction:
          onClearFilters ??
          () {
            ref.read(localGalleryNotifierProvider.notifier).clearAllFilters();
          },
    );
  }
}

/// Grouped loading view for gallery
/// 画廊分组加载视图
class GalleryGroupedLoadingView extends StatelessWidget {
  const GalleryGroupedLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateView.loading(
      title: context.l10n.localGallery_loadingGroupedImages,
    );
  }
}
