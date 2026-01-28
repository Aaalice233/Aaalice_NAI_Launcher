import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/sync_config.dart' show SyncProgress;
import '../../../../data/models/prompt/tag_group.dart'
    show TagGroupSyncProgress;

/// 同步进度指示器组件
/// 支持 TagLibrary 同步和 TagGroup 同步两种进度显示
class SyncProgressIndicator extends StatelessWidget {
  final SyncProgress? tagLibrarySyncProgress;
  final TagGroupSyncProgress? tagGroupSyncProgress;

  const SyncProgressIndicator({
    super.key,
    this.tagLibrarySyncProgress,
    this.tagGroupSyncProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tagLibrarySyncProgress != null) ...[
          _buildTagLibrarySyncProgress(context, theme, tagLibrarySyncProgress!),
          if (tagGroupSyncProgress != null) const SizedBox(height: 16),
        ],
        if (tagGroupSyncProgress != null)
          _buildTagGroupSyncProgress(context, theme, tagGroupSyncProgress!),
      ],
    );
  }

  Widget _buildTagLibrarySyncProgress(
    BuildContext context,
    ThemeData theme,
    SyncProgress progress,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress.localizedMessage(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (progress.totalEstimate > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTagGroupSyncProgress(
    BuildContext context,
    ThemeData theme,
    TagGroupSyncProgress progress,
  ) {
    final message = progress.currentGroup != null
        ? context.l10n.tagGroup_syncFetching(
            progress.currentGroup!,
            progress.completedGroups.toString(),
            progress.totalGroups.toString(),
          )
        : progress.localizedMessage(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (progress.totalGroups > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }
}
