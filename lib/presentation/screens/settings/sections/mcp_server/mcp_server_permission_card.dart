import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../mcp/providers/mcp_server_notifier.dart';
import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../themes/design_tokens.dart';
import '../../widgets/settings_card.dart';

/// 外部 MCP 客户端的工具权限分组，与聊天端共用同一套权限模式语义。
class McpServerPermissionCard extends ConsumerWidget {
  const McpServerPermissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final mode = ref.watch(
      mcpServerNotifierProvider.select((state) => state.permissionMode),
    );
    final modes = [
      (
        AgentPermissionMode.safe,
        l10n.agentSettings_permissionSafe,
        l10n.agentSettings_permissionSafeDescription,
      ),
      (
        AgentPermissionMode.askBeforeSensitiveActions,
        l10n.agentSettings_permissionAsk,
        l10n.agentSettings_permissionAskDescription,
      ),
      (
        AgentPermissionMode.fullAccess,
        l10n.agentSettings_permissionFull,
        l10n.agentSettings_permissionFullDescription,
      ),
    ];

    return SettingsCard(
      title: l10n.settings_mcpServerPermissionSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<AgentPermissionMode>(
            groupValue: mode,
            onChanged: (value) {
              if (value == null) return;
              ref
                  .read(mcpServerNotifierProvider.notifier)
                  .setPermissionMode(value);
            },
            child: Column(
              children: [
                for (final entry in modes)
                  RadioListTile<AgentPermissionMode>(
                    key: ValueKey('mcp-server-permission-${entry.$1.name}'),
                    value: entry.$1,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacingXs,
                    ),
                    title: Text(entry.$2),
                    subtitle: Text(entry.$3),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DesignTokens.spacingXs,
              DesignTokens.spacingXs,
              DesignTokens.spacingXs,
              0,
            ),
            child: Text(
              l10n.settings_mcpServerAnlasNotice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
