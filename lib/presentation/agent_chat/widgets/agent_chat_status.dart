import 'package:flutter/material.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_approval.dart';
import 'agent_chat_panel_view_data.dart';

class AgentChatStatus extends StatelessWidget {
  const AgentChatStatus({
    super.key,
    required this.viewData,
    required this.commands,
  });

  final AgentChatPanelViewData viewData;
  final AgentChatPanelCommands commands;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final state = viewData.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.error.isNotEmpty)
          _AgentChatErrorCard(
            error: state.error,
            canRetry:
                state.status != AgentChatRunStatus.running &&
                state.messages.any((message) => message is UserMessage),
            onDismiss: commands.dismissError,
            onRetry: commands.retryLastMessage,
          ),
        if (state.compacting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                Icon(
                  Icons.compress_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.agentChat_compacting,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        if (state.approvalRequest case final request?)
          AgentChatApprovalCard(
            key: ValueKey(request.toolCallId),
            toolName: request.toolName,
            args: request.args,
            estimatedAnlas: request.estimatedAnlas,
            onResolve: (approved) =>
                commands.resolveApproval(request.toolCallId, approved),
          ),
      ],
    );
  }
}

class _AgentChatErrorCard extends StatefulWidget {
  const _AgentChatErrorCard({
    required this.error,
    required this.canRetry,
    required this.onDismiss,
    required this.onRetry,
  });

  final String error;
  final bool canRetry;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  @override
  State<_AgentChatErrorCard> createState() => _AgentChatErrorCardState();
}

class _AgentChatErrorCardState extends State<_AgentChatErrorCard> {
  bool _detailsExpanded = false;

  String _summary(BuildContext context) {
    final status = RegExp(
      r'(?:HTTP(?: status)?[: ]+|status code of )(\d{3})',
      caseSensitive: false,
    ).firstMatch(widget.error);
    if (status case final match?) {
      return context.l10n.networkError_requestFailed(
        int.parse(match.group(1)!),
      );
    }
    return context.l10n.agentChat_requestFailed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final foreground = theme.colorScheme.onErrorContainer;
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLayout = constraints.maxWidth < 600;
        return Container(
          key: const ValueKey('agent-chat-error-card'),
          margin: EdgeInsets.fromLTRB(
            compactLayout ? 12 : 10,
            4,
            compactLayout ? 12 : 10,
            4,
          ),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 7, 6, 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _summary(context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    key: const ValueKey('agent-chat-error-dismiss'),
                    width: controlExtent,
                    height: controlExtent,
                    child: InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(8),
                      child: Icon(
                        Icons.close,
                        size: context.interactionPolicy.touchAvailable
                            ? 18
                            : 14,
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              if (_detailsExpanded)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(26, 4, 8, 4),
                    child: SelectableText(
                      widget.error,
                      key: const ValueKey('agent-chat-error-details'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.78),
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const ValueKey('agent-chat-error-details-toggle'),
                    onPressed: () =>
                        setState(() => _detailsExpanded = !_detailsExpanded),
                    icon: Icon(
                      _detailsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 17,
                    ),
                    label: Text(l10n.agentChat_errorDetails),
                  ),
                  if (widget.canRetry)
                    TextButton.icon(
                      key: const ValueKey('agent-chat-error-retry'),
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 17),
                      label: Text(l10n.common_retry),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class AgentChatWorkStatus extends StatelessWidget {
  const AgentChatWorkStatus({
    super.key,
    required this.phase,
    required this.routeLabel,
  });

  final AgentChatWorkPhase phase;
  final String routeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalMargin = constraints.maxWidth < 600 ? 12.0 : 10.0;
        return Container(
          key: const ValueKey('agent-chat-work-status'),
          margin: EdgeInsets.fromLTRB(horizontalMargin, 4, horizontalMargin, 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: phase == AgentChatWorkPhase.failed
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.24)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _phaseIcon(phase),
                size: 16,
                color: phase == AgentChatWorkPhase.failed
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phaseLabel(context, phase),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (routeLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        routeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.62,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _phaseLabel(BuildContext context, AgentChatWorkPhase phase) =>
      switch (phase) {
        AgentChatWorkPhase.preparing => context.l10n.agentChat_phasePreparing,
        AgentChatWorkPhase.thinking => context.l10n.agentChat_thinking,
        AgentChatWorkPhase.responding => context.l10n.agentChat_phaseResponding,
        AgentChatWorkPhase.usingTools => context.l10n.agentChat_toolRunning,
        AgentChatWorkPhase.awaitingApproval =>
          context.l10n.agentChat_phaseAwaitingApproval,
        AgentChatWorkPhase.compacting => context.l10n.agentChat_compacting,
        AgentChatWorkPhase.stopping => context.l10n.agentChat_phaseStopping,
        AgentChatWorkPhase.failed => context.l10n.common_error,
        AgentChatWorkPhase.idle => '',
      };

  IconData _phaseIcon(AgentChatWorkPhase phase) => switch (phase) {
    AgentChatWorkPhase.preparing => Icons.hourglass_top_rounded,
    AgentChatWorkPhase.thinking => Icons.psychology_alt_outlined,
    AgentChatWorkPhase.responding => Icons.edit_note_rounded,
    AgentChatWorkPhase.usingTools => Icons.build_circle_outlined,
    AgentChatWorkPhase.awaitingApproval => Icons.gpp_maybe_outlined,
    AgentChatWorkPhase.compacting => Icons.compress_rounded,
    AgentChatWorkPhase.stopping => Icons.stop_circle_outlined,
    AgentChatWorkPhase.failed => Icons.error_outline_rounded,
    AgentChatWorkPhase.idle => Icons.circle_outlined,
  };
}
