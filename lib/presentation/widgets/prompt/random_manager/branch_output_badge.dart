import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/conditional_branch_targets.dart';
import '../../../adaptive/compact_control_metrics.dart';
import '../../../adaptive/interaction_policy.dart';
import 'random_config_l10n.dart';

/// 词组只经由其他词组的条件分支输出时的说明徽标，点按打开引用它的分支
class BranchOutputBadge extends StatelessWidget {
  const BranchOutputBadge({
    super.key,
    required this.references,
    required this.onOpen,
  });

  final List<BranchReference> references;
  final ValueChanged<BranchReference> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final first = references.first;
    final ownerName = l10n.randomTagGroupName(first.owner);
    final label = references.length == 1
        ? l10n.randomManager_branchOutputBadge(ownerName)
        : l10n.randomManager_branchOutputBadgeMultiple(
            ownerName,
            references.length,
          );

    return Tooltip(
      message: l10n.randomManager_branchOutputTooltip,
      child: TextButton.icon(
        onPressed: () => onOpen(first),
        icon: const Icon(Icons.call_split_rounded, size: 14),
        label: Text(label, softWrap: true),
        style: TextButton.styleFrom(
          // 触屏保留 48 高的命中区，精确指针下维持紧凑
          visualDensity: CompactControlMetrics.forPolicy(
            context.interactionPolicy,
          ).density,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: AlignmentDirectional.centerStart,
          foregroundColor: theme.colorScheme.secondary,
          textStyle: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
