import 'package:flutter/material.dart';

import '../../../core/agent/agent_media_display_policy.dart';
import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../providers/agent_chat_notifier.dart';
import 'agent_chat_resource_widgets.dart';
import 'agent_chat_tool_presentation_helpers.dart';
import 'agent_chat_tool_result_media.dart';
import 'agent_chat_tool_step_widgets.dart';

export 'agent_chat_reasoning_tile.dart' show AgentChatReasoningTile;
export 'agent_chat_tool_presentation_helpers.dart'
    show
        agentToolIcon,
        agentToolLabel,
        agentToolResultSummary,
        agentToolSuccessColor;
export 'agent_chat_tool_result_media.dart' show AgentChatToolResultMedia;

class AgentChatToolActivityTile extends StatefulWidget {
  const AgentChatToolActivityTile({super.key, required this.activity});

  final AgentToolActivity activity;

  @override
  State<AgentChatToolActivityTile> createState() =>
      _AgentChatToolActivityTileState();
}

class _AgentChatToolActivityTileState extends State<AgentChatToolActivityTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = widget.activity;
    final toolLabel = agentToolLabel(context, activity.toolName);
    final visual = agentToolVisual(theme, activity.toolName);
    final statusColor = switch (activity.status) {
      AgentToolActivityStatus.running => visual.color,
      AgentToolActivityStatus.succeeded => agentToolSuccessColor(theme),
      AgentToolActivityStatus.failed => theme.colorScheme.error,
    };
    final statusLabel = activity.status == AgentToolActivityStatus.running
        ? context.l10n.agentChat_toolRunning
        : '';
    final statusIcon = switch (activity.status) {
      AgentToolActivityStatus.running => null,
      AgentToolActivityStatus.succeeded => Icons.check_rounded,
      AgentToolActivityStatus.failed => Icons.close_rounded,
    };
    final details = _activityDetails(activity);
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AgentToolStepRow(
            key: ValueKey('agent-tool-activity-${activity.toolCallId}'),
            iconKey: ValueKey(
              'agent-tool-activity-icon-${activity.toolCallId}',
            ),
            icon: visual.icon,
            iconColor: visual.color,
            title: toolLabel,
            summary: _summarize(activity),
            status: statusLabel,
            statusIcon: statusIcon,
            statusIconKey: ValueKey(
              'agent-tool-activity-status-${activity.toolCallId}',
            ),
            statusColor: statusColor,
            statusSemanticsLabel:
                activity.status == AgentToolActivityStatus.failed
                ? context.l10n.common_error
                : context.l10n.common_success,
            expanded: _expanded,
            expandable: details.isNotEmpty,
            failure: activity.status == AgentToolActivityStatus.failed,
            onTap: details.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            AgentToolDetailPanel(
              key: ValueKey(
                'agent-tool-activity-details-${activity.toolCallId}',
              ),
              text: details,
            ),
        ],
      ),
    );
  }

  String _summarize(AgentToolActivity activity) {
    if (activity.content.trim().isEmpty) return '';
    return safeAgentToolTextSummary(
      activity.content,
      fallback: '',
      failed: activity.status == AgentToolActivityStatus.failed,
    );
  }

  String _activityDetails(AgentToolActivity activity) {
    final sections = <String>[];
    if (activity.args.isNotEmpty) {
      sections.add(formatAgentToolDetailValue(activity.args));
    }
    if (activity.content.trim().isNotEmpty) {
      sections.add(formatAgentToolDetailText(activity.content));
    }
    return sections.join('\n\n');
  }
}

class AgentChatToolResultTile extends StatefulWidget {
  const AgentChatToolResultTile({
    super.key,
    required this.result,
    this.initiallyExpanded = false,
    this.showMedia = true,
    this.showRailConnector = false,
    this.nested = false,
  });

  final ToolResultMessage result;
  final bool initiallyExpanded;
  final bool showMedia;
  final bool showRailConnector;
  final bool nested;

  @override
  State<AgentChatToolResultTile> createState() =>
      _AgentChatToolResultTileState();
}

class _AgentChatToolResultTileState extends State<AgentChatToolResultTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final toolLabel = widget.nested
        ? context.l10n.agentChat_toolResult
        : agentToolLabel(context, result.toolName);
    final visual = agentToolVisual(theme, result.toolName);
    final statusColor = result.isError
        ? theme.colorScheme.error
        : agentToolSuccessColor(theme);
    final showMedia =
        widget.showMedia && agentToolDisplaysMedia(result.toolName);
    final media = showMedia ? extractToolResultMediaPayload(result) : null;
    final detailText = agentToolResultDetailText(result);
    final statusLabel = result.isError
        ? context.l10n.common_error
        : context.l10n.common_success;
    final rawSummary = agentToolResultDefaultSummary(context, result);
    final summary = rawSummary == statusLabel ? '' : rawSummary;
    final hasMedia = media != null && media.isNotEmpty;
    final hasExpandedContent = detailText.isNotEmpty || (showMedia && hasMedia);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgentToolStepRow(
          key: ValueKey('agent-tool-result-${result.toolCallId}'),
          iconKey: ValueKey('agent-tool-result-icon-${result.toolCallId}'),
          icon: visual.icon,
          iconColor: visual.color,
          title: toolLabel,
          summary: summary,
          status: '',
          statusIcon: widget.nested
              ? null
              : result.isError
              ? Icons.close_rounded
              : Icons.check_rounded,
          statusIconKey: ValueKey(
            'agent-tool-result-status-${result.toolCallId}',
          ),
          statusColor: statusColor,
          statusSemanticsLabel: statusLabel,
          expanded: _expanded,
          expandable: hasExpandedContent,
          failure: result.isError,
          showIcon: !widget.nested,
          showRailConnector: widget.showRailConnector,
          onTap: !hasExpandedContent
              ? null
              : () => setState(() => _expanded = !_expanded),
        ),
        if (_expanded && detailText.isNotEmpty)
          AgentToolDetailPanel(
            key: ValueKey('agent-tool-result-details-${result.toolCallId}'),
            text: detailText,
          ),
        if (_expanded && showMedia && hasMedia)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 8, 8),
            child: AgentChatResourceGallery(
              children: media.buildGalleryChildren(
                refKeyPrefix: '${result.toolCallId}-ref',
                inlineKeyPrefix: '${result.toolCallId}-inline',
              ),
            ),
          ),
      ],
    );
  }
}

/// Keeps consecutive tool results in one quiet, auditable turn activity unit.
/// The group keeps consecutive steps visible while each verbose payload stays
/// collapsed until requested.
class AgentChatToolResultGroup extends StatefulWidget {
  const AgentChatToolResultGroup({super.key, required this.results});

  final List<ToolResultMessage> results;

  @override
  State<AgentChatToolResultGroup> createState() =>
      _AgentChatToolResultGroupState();
}

class _AgentChatToolResultGroupState extends State<AgentChatToolResultGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final failed = results.where((result) => result.isError).length;
    final status = failed > 0
        ? context.l10n.common_error
        : context.l10n.common_success;
    final statusColor = failed > 0
        ? theme.colorScheme.error
        : agentToolSuccessColor(theme);
    return Container(
      key: PageStorageKey(
        'agent-tool-group-${results.first.toolCallId}-${results.length}',
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: failed > 0
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AgentToolTaskHeader(
            icon: failed > 0
                ? Icons.error_outline_rounded
                : Icons.task_alt_outlined,
            title: context.l10n.agentChat_toolGroupCount(results.length),
            statusIcon: failed > 0 ? Icons.close_rounded : Icons.check_rounded,
            statusLabel: status,
            statusColor: statusColor,
            expanded: _expanded,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final result in results)
                          AgentChatToolResultTile(
                            result: result,
                            showRailConnector: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
