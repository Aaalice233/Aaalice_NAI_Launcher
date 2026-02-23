import 'package:flutter/material.dart';

import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';

/// 最近 Vibe 条目组件
///
/// 用于显示最近使用的 Vibe 库条目，包含缩略图、名称和源类型指示器。
/// 支持点击回调用于添加到当前生成参数。
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
                child: entry.hasThumbnail || entry.hasVibeThumbnail
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
                color: entry.isPreEncoded
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    entry.isPreEncoded ? Icons.check_circle : Icons.warning,
                    size: 8,
                    color: entry.isPreEncoded ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    entry.sourceType.displayLabel,
                    style: TextStyle(
                      fontSize: 8,
                      color: entry.isPreEncoded ? Colors.green : Colors.orange,
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
