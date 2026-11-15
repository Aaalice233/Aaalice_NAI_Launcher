import 'package:flutter/material.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../adaptive/interaction_policy.dart';
import '../../../../widgets/common/themed_divider.dart';
import '../../../../widgets/common/workspace_panel_header.dart';

class HistoryPanelHeader extends StatelessWidget {
  const HistoryPanelHeader({
    super.key,
    required this.embedded,
    required this.hasItems,
    required this.totalCount,
    required this.allSelected,
    required this.onToggleSelectAll,
    required this.onClear,
    required this.onCollapse,
    required this.isCloseButton,
  });

  final bool embedded;
  final bool hasItems;
  final int totalCount;
  final bool allSelected;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onClear;
  final VoidCallback onCollapse;
  final bool isCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
            child: Row(
              children: [
                const Spacer(),
                if (hasItems) ...[
                  _CountBadge(totalCount: totalCount),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onToggleSelectAll,
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 18,
                    ),
                    tooltip: allSelected
                        ? context.l10n.common_deselectAll
                        : context.l10n.common_selectAll,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    visualDensity: context.interactionPolicy.touchAvailable
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: context.l10n.common_clear,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    visualDensity: context.interactionPolicy.touchAvailable
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    constraints: BoxConstraints.tightFor(
                      width: context.interactionPolicy.minimumControlExtent,
                      height: context.interactionPolicy.minimumControlExtent,
                    ),
                    padding: const EdgeInsets.all(8),
                  ),
                ],
              ],
            ),
          ),
          const ThemedDivider(height: 1),
        ],
      );
    }

    return WorkspacePanelHeader(
      leading: IconButton(
        key: const ValueKey('generation-history-collapse'),
        onPressed: onCollapse,
        icon: const Icon(Icons.chevron_right),
        tooltip: isCloseButton
            ? MaterialLocalizations.of(context).closeButtonTooltip
            : context.l10n.common_collapse,
        constraints: BoxConstraints.tightFor(
          width: context.interactionPolicy.minimumControlExtent,
          height: context.interactionPolicy.minimumControlExtent,
        ),
      ),
      icon: Icons.history_rounded,
      title: Row(
        children: [
          Flexible(
            child: Text(
              context.l10n.generation_historyRecord,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasItems) ...[
            const SizedBox(width: 4),
            _CountBadge(totalCount: totalCount),
          ],
        ],
      ),
      actions: [
        if (hasItems) ...[
          IconButton(
            onPressed: onToggleSelectAll,
            icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              size: 20,
            ),
            tooltip: allSelected
                ? context.l10n.common_deselectAll
                : context.l10n.common_selectAll,
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
            constraints: BoxConstraints.tightFor(
              width: context.interactionPolicy.minimumControlExtent,
              height: context.interactionPolicy.minimumControlExtent,
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: context.l10n.common_clear,
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            constraints: BoxConstraints.tightFor(
              width: context.interactionPolicy.minimumControlExtent,
              height: context.interactionPolicy.minimumControlExtent,
            ),
          ),
        ],
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$totalCount',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
