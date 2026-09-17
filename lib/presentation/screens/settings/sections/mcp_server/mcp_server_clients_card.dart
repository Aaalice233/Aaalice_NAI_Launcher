import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/mcp/mcp_session_registry.dart';
import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../themes/core/layered_surface_style.dart';
import '../../../../themes/design_tokens.dart';
import '../../widgets/settings_card.dart';
import 'mcp_client_config_snippets.dart';

// 会话数量不受控，列表撑高会把下方配置片段顶出视野。
const double _sessionsViewportHeight = 200;

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
          _SessionsBox(
            child: state.sessions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacingSm),
                    child: Text(
                      l10n.settings_mcpServerSessionsEmpty,
                      key: const ValueKey('mcp-server-sessions-empty'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : _SessionList(sessions: state.sessions),
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

/// 承载会话列表的独立色面，与配置片段预览框保持同一层级语义。
class _SessionsBox extends StatelessWidget {
  const _SessionsBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DesignTokens.spacingXs),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: controlSurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(DesignTokens.spacingXs),
        ),
        child: child,
      ),
    );
  }
}

class _SessionList extends StatefulWidget {
  const _SessionList({required this.sessions});

  final List<McpSessionSummary> sessions;

  @override
  State<_SessionList> createState() => _SessionListState();
}

class _SessionListState extends State<_SessionList> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.textScalerOf(
          context,
        ).scale(_sessionsViewportHeight),
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: ScrollConfiguration(
          // 桌面端默认行为会再加一条滚动条。
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.separated(
            key: const ValueKey('mcp-server-sessions-list'),
            controller: _controller,
            primary: false,
            shrinkWrap: true,
            padding: const EdgeInsets.all(DesignTokens.spacingSm),
            itemCount: sessions.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: DesignTokens.spacingXs),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionRow(
                session: session,
                label: _clientLabel(context, session.clientName),
              );
            },
          ),
        ),
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

    return Column(
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
