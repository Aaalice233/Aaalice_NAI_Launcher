import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import 'recent_vibe_item.dart';

/// 最近使用的 Vibes 列表组件
class RecentVibesList extends ConsumerWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final List<VibeLibraryEntry> entries;

  const RecentVibesList({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.entries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transitionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.vibe_selector_recent,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                // 折叠/展开图标
                AnimatedRotation(
                  turns: isCollapsed ? 0.75 : 1.0,
                  duration: transitionDuration,
                  child: Icon(
                    Icons.chevron_left,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    onTap: () => _addRecentVibe(context, ref, entry),
                  );
                },
              ),
            ),
          ),
          crossFadeState: isCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: transitionDuration,
        ),
      ],
    );
  }

  Future<void> _addRecentVibe(
    BuildContext context,
    WidgetRef ref,
    VibeLibraryEntry entry,
  ) async {
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    final success = await panelNotifier.addRecentVibe(entry);

    if (context.mounted) {
      if (success) {
        AppToast.success(
          context,
          context.l10n.vibe_addedNamed(entry.displayName),
        );
      } else {
        AppToast.warning(context, context.l10n.vibe_maxReached);
      }
    }
  }
}
