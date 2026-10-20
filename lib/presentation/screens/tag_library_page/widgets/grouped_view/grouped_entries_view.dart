import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../providers/tag_library_page_provider.dart';
import 'category_header.dart';

/// 分组视图 - 按类别分组显示条目
class GroupedEntriesView extends ConsumerWidget {
  final ScrollController? scrollController;
  final Widget Function(TagLibraryEntry) entryBuilder;

  const GroupedEntriesView({
    super.key,
    this.scrollController,
    required this.entryBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagLibraryPageNotifierProvider);

    final groups = state.entryGroups;
    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        for (final group in groups) ...[
          // 吸顶分类标题
          SliverPersistentHeader(
            pinned: true,
            delegate: CategoryHeaderDelegate(
              title:
                  group.category?.displayName ??
                  context.l10n.tagLibrary_uncategorized,
              count: group.entries.length,
            ),
          ),
          // 该分类的条目网格
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 80,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => entryBuilder(group.entries[index]),
                childCount: group.entries.length,
              ),
            ),
          ),
        ],
        // 底部留白
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.tagLibrary_empty,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
