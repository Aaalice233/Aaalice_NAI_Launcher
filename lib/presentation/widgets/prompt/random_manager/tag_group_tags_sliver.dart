import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../common/translated_tag_text.dart';

/// 词组编辑面板的标签页；内置词库的标签可达数千条，按需构建
class TagGroupTagsSliver extends ConsumerWidget {
  const TagGroupTagsSliver({
    super.key,
    required this.group,
    required this.tagCount,
  });

  final RandomTagGroup group;
  final int tagCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tags = _watchTags(ref);

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.randomManager_tagsTab(tagCount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          DecoratedSliver(
            decoration: BoxDecoration(
              color: controlSurfaceColor(colorScheme),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: tags.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          l10n.randomManager_noTags,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: tags.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TranslatedTagText(
                          tags[index],
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 内置词库来源的标签不存放在词组里，按来源分类从词库读取
  List<String> _watchTags(WidgetRef ref) {
    if (group.sourceType != TagGroupSourceType.builtin) {
      return group.tags.map((tag) => tag.tag).toList();
    }
    final library = ref.watch(tagLibraryNotifierProvider).library;
    final category = TagSubCategory.values
        .where((category) => category.name == group.sourceId)
        .firstOrNull;
    if (library == null || category == null) return const [];
    return library.getCategory(category).map((tag) => tag.tag).toList();
  }
}
