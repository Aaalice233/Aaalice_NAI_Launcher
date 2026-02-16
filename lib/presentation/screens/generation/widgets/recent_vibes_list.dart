import 'package:flutter/material.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';
import 'recent_vibe_item.dart';

/// 最近使用的 Vibes 列表组件
class RecentVibesList extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final List<VibeLibraryEntry> entries;
  final Function(VibeLibraryEntry) onAddEntry;

  const RecentVibesList({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.entries,
    required this.onAddEntry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 可点击的标题栏
        InkWell(
          onTap: onToggleCollapsed,
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
                  '最近使用',
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
                    onTap: () => onAddEntry(entry),
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
