import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/mcp/mcp_session_registry.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../themes/design_tokens.dart';
import '../../widgets/settings_card.dart';
import 'mcp_client_config_snippets.dart';

/// 客户端分组：待处理授权提示、已连接会话与各客户端的配置片段。
class McpServerClientsCard extends ConsumerWidget {
  const McpServerClientsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final state = ref.watch(mcpServerNotifierProvider);
    final pending = state.pendingApproval;
    final endpoint = state.endpoint;

    return SettingsCard(
      title: l10n.settings_mcpServerClientsSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pending != null)
            _PendingApprovalRow(
              clientLabel: _clientLabel(context, pending.clientLabel),
              toolName: pending.request.toolName,
            ),
          _GroupLabel(text: l10n.settings_mcpServerConnectedClients),
          if (state.sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacingXs,
              ),
              child: Text(
                l10n.settings_mcpServerSessionsEmpty,
                key: const ValueKey('mcp-server-sessions-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final session in state.sessions)
              _SessionRow(
                session: session,
                label: _clientLabel(context, session.clientName),
              ),
          _GroupLabel(text: l10n.settings_mcpServerClientConfigs),
          if (endpoint == null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.spacingXs,
              ),
              child: Text(
                l10n.settings_mcpServerConfigUnavailable,
                key: const ValueKey('mcp-server-config-unavailable'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            McpClientConfigSnippets(endpoint: endpoint),
        ],
      ),
    );
  }
}

class _PendingApprovalRow extends StatelessWidget {
  const _PendingApprovalRow({
    required this.clientLabel,
    required this.toolName,
  });

  final String clientLabel;
  final String toolName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      key: const ValueKey('mcp-server-pending-approval'),
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.pending_actions_outlined,
              size: DesignTokens.iconSm,
              color: theme.colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: DesignTokens.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settings_mcpServerPendingApproval(clientLabel, toolName),
                ),
                const SizedBox(height: DesignTokens.spacingXxs),
                Text(
                  l10n.settings_mcpServerPendingApprovalHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.label});

  final McpSessionSummary session;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final version = session.clientVersion;
    final title = version == null || version.isEmpty
        ? label
        : '$label $version';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        0,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: DesignTokens.spacingXxs),
          Text(
            l10n.settings_mcpServerSessionConnectedAt(
              _formatClock(session.connectedAt),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            l10n.settings_mcpServerSessionLastActivity(
              _formatClock(session.lastActivity),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
        DesignTokens.spacingXs,
      ),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

String _clientLabel(BuildContext context, String? rawLabel) {
  final label = rawLabel?.trim() ?? '';
  return label.isEmpty ? context.l10n.mcpApproval_unknownClient : label;
}

String _formatClock(DateTime time) {
  String pad(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  return '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}';
}
