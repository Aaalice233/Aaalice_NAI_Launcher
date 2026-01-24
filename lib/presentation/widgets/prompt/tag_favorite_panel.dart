import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/nai_prompt_parser.dart';
import '../../../data/models/prompt/prompt_tag.dart';
import '../../../data/models/prompt/tag_favorite.dart';
import '../../providers/tag_favorite_provider.dart';
import '../common/themed_container.dart';

/// 标签收藏面板
///
/// 显示用户收藏的常用标签，支持点击添加到提示词、长按移除收藏
class TagFavoritePanel extends ConsumerStatefulWidget {
  /// 当前标签列表
  final List<PromptTag> currentTags;

  /// 标签变化回调
  final ValueChanged<List<PromptTag>> onTagsChanged;

  /// 是否只读
  final bool readOnly;

  /// 是否紧凑模式
  final bool compact;

  const TagFavoritePanel({
    super.key,
    required this.currentTags,
    required this.onTagsChanged,
    this.readOnly = false,
    this.compact = false,
  });

  @override
  ConsumerState<TagFavoritePanel> createState() => _TagFavoritePanelState();
}

class _TagFavoritePanelState extends ConsumerState<TagFavoritePanel> {
  /// 检查标签是否已在当前提示词中
  bool _isTagInCurrentTags(PromptTag tag) {
    return widget.currentTags.any((t) => t.text == tag.text);
  }

  /// 添加收藏标签到当前提示词
  void _addToCurrentTags(TagFavorite favorite) {
    if (widget.readOnly) return;

    final tag = favorite.tag;

    // 检查是否已存在
    if (_isTagInCurrentTags(tag)) {
      // 已存在，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tag_alreadyAdded),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 添加到当前标签列表
    final newTags = NaiPromptParser.insertTag(
      widget.currentTags,
      widget.currentTags.length,
      tag.toSyntaxString(),
    );

    widget.onTagsChanged(newTags);

    // 触觉反馈
    HapticFeedback.lightImpact();
  }

  /// 从收藏中移除
  void _removeFromFavorites(TagFavorite favorite) {
    if (widget.readOnly) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tag_removeFavoriteTitle),
        content: Text(
          context.l10n.tag_removeFavoriteMessage(favorite.tag.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(tagFavoriteNotifierProvider.notifier)
                  .removeFavorite(favorite.id);
            },
            child: Text(
              context.l10n.common_delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesState = ref.watch(tagFavoriteNotifierProvider);
    final favorites = favoritesState.favorites;
    final isLoading = favoritesState.isLoading;

    return ThemedContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, favorites.length),

          const SizedBox(height: 16),

          // 收藏列表
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : favorites.isEmpty
                    ? _buildEmptyState(context)
                    : _buildFavoritesList(context, favorites),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader(BuildContext context, int count) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Icons.favorite_border,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.tag_favoritesTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              size: 48,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.tag_favoritesEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tag_favoritesEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建收藏列表
  Widget _buildFavoritesList(
    BuildContext context,
    List<TagFavorite> favorites,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: favorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        final isInCurrent = _isTagInCurrentTags(favorite.tag);

        return _buildFavoriteItem(context, favorite, isInCurrent);
      },
    );
  }

  /// 构建单个收藏项
  Widget _buildFavoriteItem(
    BuildContext context,
    TagFavorite favorite,
    bool isInCurrent,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addToCurrentTags(favorite),
        onLongPress: () => _removeFromFavorites(favorite),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isInCurrent
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
            ),
            color: isInCurrent
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
          child: Row(
            children: [
              // 收藏图标
              Icon(
                Icons.favorite,
                size: 16,
                color: isInCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error.withOpacity(0.7),
              ),
              const SizedBox(width: 12),

              // 标签信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 标签文本（显示权重）
                    Text(
                      favorite.tag.toSyntaxString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isInCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    // 如果有备注，显示备注
                    if (favorite.hasNotes) ...[
                      const SizedBox(height: 2),
                      Text(
                        favorite.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // 已添加标识
              if (isInCurrent) ...[
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],

              // 更多操作提示
              Icon(
                Icons.more_vert,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
