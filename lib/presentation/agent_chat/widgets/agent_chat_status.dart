import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
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
            onResolve: commands.resolveApproval,
          ),
      ],
    );
  }
}

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.toolName,
    required this.args,
    required this.onResolve,
  });

  final String toolName;
  final Map<String, dynamic> args;
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
