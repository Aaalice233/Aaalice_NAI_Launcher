import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/danbooru_preview_provider.dart';
import '../../../widgets/common/hover_preview_card.dart';

/// Tag Group 预览内容组件
class TagGroupPreviewContent extends ConsumerWidget {
  final String groupTitle;

  const TagGroupPreviewContent({
    super.key,
    required this.groupTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(tagGroupPreviewProvider(groupTitle));

    return previewAsync.when(
      data: (preview) => _buildContent(context, preview),
      loading: () => const PreviewCardSkeleton(),
      error: (_, __) => const PreviewCardError(),
    );
  }

  Widget _buildContent(BuildContext context, TagGroupPreview preview) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (preview.tagCount == 0) {
      return const PreviewCardError(message: '暂无标签数据');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和数量
          Row(
            children: [
              Icon(
                Icons.label_outline,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  preview.title
                      .replaceFirst('tag_group:', '')
                      .replaceAll('_', ' '),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${preview.tagCount} 个标签',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // 热门标签
          Text(
            '热门标签',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: preview.topTags.map((tag) => _TagChip(tag: tag)).toList(),
          ),
        ],
      ),
    );
  }
}

/// Pool 预览内容组件
class PoolPreviewContent extends ConsumerWidget {
  final int poolId;

  const PoolPreviewContent({
    super.key,
    required this.poolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(poolPreviewProvider(poolId));

    return previewAsync.when(
      data: (preview) => _buildContent(context, preview),
      loading: () => const PreviewCardSkeleton(),
      error: (_, __) => const PreviewCardError(),
    );
  }

  Widget _buildContent(BuildContext context, PoolPreview preview) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (preview.postCount == 0 && preview.name.isEmpty) {
      return const PreviewCardError(message: '暂无 Pool 数据');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和数量
          Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  preview.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatNumber(preview.postCount)} 个帖子',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (preview.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              preview.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

/// 标签 Chip
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}
