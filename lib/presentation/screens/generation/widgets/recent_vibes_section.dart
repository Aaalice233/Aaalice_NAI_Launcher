import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
// Import for VibeSourceTypeExtension (displayLabel)
import '../../../../data/models/vibe/vibe_reference.dart';

/// 最近使用的 Vibes 区域组件
///
/// 显示最近使用过的 Vibe 库条目，支持点击添加和折叠展开
class RecentVibesSection extends StatelessWidget {
  /// 最近使用的条目列表
  final List<VibeLibraryEntry> entries;

  /// 是否折叠
  final bool isCollapsed;

  /// 点击切换折叠状态的回调
  final VoidCallback onToggleCollapse;

  /// 点击条目时的回调
  final ValueChanged<VibeLibraryEntry> onEntryTap;

  const RecentVibesSection({
    super.key,
    required this.entries,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可点击的标题栏
        InkWell(
          onTap: onToggleCollapse,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  size: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.vibe_selector_recent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(width: 4),
                // 折叠/展开图标
                AnimatedRotation(
                  turns: isCollapsed ? 0.75 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_left,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 可折叠的内容区域
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: entries.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return RecentVibeItem(
                    entry: entry,
                    onTap: () => onEntryTap(entry),
                  );
                },
              ),
            ),
          ),
          crossFadeState: isCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// 最近使用的 Vibe 条目组件
class RecentVibeItem extends StatelessWidget {
  final VibeLibraryEntry entry;
  final VoidCallback onTap;

  const RecentVibeItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Column(
          children: [
            // 缩略图
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(7)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 主缩略图
                    entry.hasThumbnail || entry.hasVibeThumbnail
                        ? Image.memory(
                            entry.thumbnail ?? entry.vibeThumbnail!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.image, size: 24),
                            ),
                          ),
                    // Bundle 标识
                    if (entry.isBundle)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.layers,
                                size: 10,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${entry.bundledVibeCount}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // 名称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 源类型指示器
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 8,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    entry.sourceType.displayLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
