import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../widgets/common/app_toast.dart';
import 'agent_chat_shared_widgets.dart';

class AgentToolTaskHeader extends StatelessWidget {
  const AgentToolTaskHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.statusIcon,
    required this.statusLabel,
    required this.statusColor,
    required this.expanded,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final IconData statusIcon;
  final String statusLabel;
  final Color statusColor;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final policyExtent = context.interactionPolicy.minimumControlExtent;
    final minimumHeight = policyExtent < 44 ? 44.0 : policyExtent;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: statusLabel,
                  child: ExcludeSemantics(
                    child: Icon(statusIcon, size: 16, color: statusColor),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AgentToolStepRow extends StatelessWidget {
  const AgentToolStepRow({
    super.key,
    required this.iconKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.summary,
    required this.status,
    required this.expanded,
    required this.expandable,
    required this.onTap,
    this.statusIcon,
    this.statusIconKey,
    this.statusColor,
    this.statusSemanticsLabel,
    this.failure = false,
    this.showIcon = true,
    this.showRailConnector = false,
  });

  final Key iconKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String summary;
  final String status;
  final bool expanded;
  final bool expandable;
  final VoidCallback? onTap;
  final IconData? statusIcon;
  final Key? statusIconKey;
  final Color? statusColor;
  final String? statusSemanticsLabel;
  final bool failure;
  final bool showIcon;
  final bool showRailConnector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: failure
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.18)
              : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (showIcon) ...[
                      SizedBox.square(
                        key: iconKey,
                        dimension: 18,
                        child: Icon(icon, size: 17, color: iconColor),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium,
                          ),
                          if (summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: failure
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        status,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor ?? iconColor,
                        ),
                      ),
                    ],
                    if (statusIcon case final statusIcon?) ...[
                      const SizedBox(width: 8),
                      Semantics(
                        label: statusSemanticsLabel,
                        child: ExcludeSemantics(
                          child: Icon(
                            statusIcon,
                            key: statusIconKey,
                            size: 16,
                            color: statusColor ?? iconColor,
                          ),
                        ),
                      ),
                    ],
                    if (expandable) ...[
                      const SizedBox(width: 2),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showRailConnector)
          Positioned(
            left: -6,
            top: 23,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 2,
                color: iconColor.withValues(alpha: 0.38),
              ),
            ),
          ),
      ],
    );
  }
}

class AgentToolDetailPanel extends StatelessWidget {
  const AgentToolDetailPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AgentToolDetailSurface(
      text: text,
      copyTooltip: context.l10n.common_copy,
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          AppToast.info(context, context.l10n.common_copied);
        }
      },
    );
  }
}
