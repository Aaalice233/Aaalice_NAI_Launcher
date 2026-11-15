import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../../adaptive/interaction_policy.dart';
import '../../../../widgets/common/image_card_action.dart';
import '../../../../widgets/common/image_card_action_dispatch.dart';
import '../../../../widgets/common/image_card_batch_scope.dart';

class HistoryPanelBottomActions extends StatelessWidget {
  const HistoryPanelBottomActions({super.key});

  // 历史栏最窄时一行两个按钮仍放得下完整文字，再多就换行。
  static const _batchButtonsPerRow = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final batch = ImageCardBatchScope.maybeOf(context)!;
    final extent = context.interactionPolicy.minimumControlExtent;
    final height = extent < 44 ? 44.0 : extent;
    final count = batch.targetIds.length;
    final rows = [
      ...batch.actions
          .where((action) => !action.isDanger)
          .toList()
          .slices(_batchButtonsPerRow),
      batch.actions.where((action) => action.isDanger).toList(),
    ].where((row) => row.isNotEmpty);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      // 危险动作单独占一行：与主要动作隔开，窄面板里也不挤压文字按钮。
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          for (final row in rows)
            Row(
              spacing: 8,
              children: [
                for (final action in row)
                  Expanded(
                    child: _buildBatchButton(context, action, count, height),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBatchButton(
    BuildContext context,
    ImageCardAction action,
    int count,
    double height,
  ) {
    final onPressed = action.canInvoke
        ? () => unawaited(dispatchImageCardAction(context, action))
        : null;
    final key = ValueKey('history-batch-action-${action.id.name}');
    final label = Text(
      '${action.label} ($count)',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final icon = Icon(action.icon, size: 20);
    return action.isPrimary
        ? FilledButton.icon(
            key: key,
            onPressed: onPressed,
            icon: icon,
            label: label,
            style: FilledButton.styleFrom(minimumSize: Size(0, height)),
          )
        : OutlinedButton.icon(
            key: key,
            onPressed: onPressed,
            icon: icon,
            label: label,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(0, height),
              foregroundColor: action.isDanger
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          );
  }
}
