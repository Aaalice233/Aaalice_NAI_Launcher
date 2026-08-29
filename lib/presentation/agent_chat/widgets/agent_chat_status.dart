import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/utils/localization_extension.dart';
import '../providers/agent_chat_state.dart';
import 'agent_chat_tool_widgets.dart';
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.status != AgentChatRunStatus.running &&
                    state.messages.any((message) => message is UserMessage))
                  TextButton(
                    onPressed: commands.retryLastMessage,
                    child: Text(l10n.common_retry),
                  ),
                SizedBox(
                  key: const ValueKey('agent-chat-error-dismiss'),
                  width: viewData.mobile ? 48 : 24,
                  height: viewData.mobile ? 48 : 24,
                  child: InkWell(
                    onTap: commands.dismissError,
                    borderRadius: BorderRadius.circular(8),
                    child: Icon(
                      Icons.close,
                      size: viewData.mobile ? 18 : 14,
                      color: theme.colorScheme.onErrorContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (state.compacting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
          _ApprovalBar(
            toolName: request.toolName,
            args: request.args,
            estimatedAnlas: request.estimatedAnlas,
            onResolve: commands.resolveApproval,
          ),
        if (state.routeReady)
          Padding(
            padding: EdgeInsets.fromLTRB(
              viewData.mobile ? 14 : 10,
              3,
              viewData.mobile ? 14 : 10,
              1,
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    state.routeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.72,
                      ),
                    ),
                  ),
                ),
                if (state.workPhase != AgentChatWorkPhase.idle) ...[
                  const SizedBox(width: 6),
                  Text(
                    '· ${_phaseLabel(context, state.workPhase)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _contextLabel(context, state),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.65,
                    ),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
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

  String _contextLabel(BuildContext context, AgentChatState state) {
    final usage = state.contextUsage;
    if (usage == null) return context.l10n.agentChat_contextUnavailable;
    final tokens = usage.totalTokens > 0
        ? usage.totalTokens
        : usage.input + usage.output + usage.cacheRead + usage.cacheWrite;
    if (tokens <= 0) return context.l10n.agentChat_contextUnavailable;
    final window = state.contextWindow;
    if (window == null || window <= 0) {
      return context.l10n.agentChat_contextTokens(tokens);
    }
    final percent = (tokens / window * 100).clamp(0, 999).round();
    return '${context.l10n.agentChat_contextTokens(tokens)} / $window · $percent%';
  }
}

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.toolName,
    required this.args,
    required this.estimatedAnlas,
    required this.onResolve,
  });

  final String toolName;
  final Map<String, dynamic> args;
  final int? estimatedAnlas;
  final void Function(bool approved) onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    var formattedArgs = const JsonEncoder.withIndent('  ').convert(args);
    if (formattedArgs.length > 1200) {
      formattedArgs = '${formattedArgs.substring(0, 1200)}…';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gpp_maybe_outlined,
                size: 17,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.agentChat_approvalTitle(
                    agentToolLabel(context, toolName),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.agentChat_approvalDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          if (estimatedAnlas case final cost?) ...[
            const SizedBox(height: 4),
            Text(
              l10n.agentChat_approvalEstimatedAnlas(cost),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 96),
            padding: const EdgeInsets.all(6),
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            child: SingleChildScrollView(
              child: SelectableText(
                formattedArgs,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => onResolve(false),
                icon: const Icon(Icons.close, size: 16),
                label: Text(l10n.agentChat_approvalDeny),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: () => onResolve(true),
                icon: const Icon(Icons.check, size: 16),
                label: Text(l10n.agentChat_approvalAllow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
